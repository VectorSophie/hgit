// Ignore.HC — `.hgitignore`: a small, deterministic ignore grammar.
// Design decisions written up in `docs/adr/0014-ignore-rules.md` -
// read that first, this file only implements what it already decided.
//
// Three real pattern kinds, no more:
//   NAME          "*.tmp"     - basename glob (single '*' wildcard),
//                                any depth.
//   DIR           "build/"    - a directory named exactly this,
//                                any depth, recursively (caller skips
//                                descending into it at all).
//   DIR_CONTENTS  "generated/*" - anchored to the repo root; matches
//                                only a DIRECT child of that exact
//                                directory, not deeper.
// A leading "!" negates. Patterns are evaluated in file order; the
// LAST matching pattern (negated or not) wins - same real precedence
// rule `.gitignore` itself uses.
//
// No caching: `IgnoreLoad` reads `.hgitignore` fresh from disk every
// time a caller wants it, matching hgit's own "no working-directory
// checkout, read real filesystem state at the moment of the
// operation" design throughout. Returns real, MAlloc'd arrays (freed
// by the caller via `IgnoreFree`) sized from the real ignore file's
// own byte length - no guessed cap (ADR 0007's own discipline): every
// real pattern line needs at least 1 content byte plus a newline, so
// `fsize/2 + 2` is a real, computed upper bound on pattern count, not
// a guess.
//
// Depends on nothing beyond real TempleOS builtins (FileRead, StrLen,
// StrCmp, MAlloc/Free).

#define IGNORE_KIND_NAME 0
#define IGNORE_KIND_DIR 1
#define IGNORE_KIND_DIR_CONTENTS 2
#define IGNORE_KIND_SKIP 255 // an unsupported line - parsed, printed, not stored

// Reads and parses a real `.hgitignore` file at `ignore_path`. If it
// doesn't exist, all four `out_*` are set to NULL/0 - not an error,
// just "no rules" (everything passes `IsIgnored`). Unsupported lines
// (any other slash-containing pattern) are diagnosed
// (`IGNORE_UNSUPPORTED_LINE <raw line>`) and skipped, not guessed at.
U0 IgnoreLoad(U8 *ignore_path, U8 **out_patterns, U8 **out_negate,
              U8 **out_kind, I64 *out_count)
{
  I64 fsize;
  U8 *buf = FileRead(ignore_path, &fsize);
  if (buf == NULL) {
    *out_patterns = NULL;
    *out_negate = NULL;
    *out_kind = NULL;
    *out_count = 0;
    return;
  }

  I64 max_patterns = fsize/2 + 2;
  U8 *patterns = MAlloc(max_patterns*256);
  U8 *negate = MAlloc(max_patterns);
  U8 *kind = MAlloc(max_patterns);
  I64 count = 0;
  I64 pos = 0;

  while (pos < fsize) {
    I64 line_start = pos;
    while (pos < fsize && buf[pos] != '\n') pos++;
    I64 line_len = pos - line_start;
    if (pos < fsize) pos++; // skip the newline itself
    if (line_len > 0 && buf[line_start+line_len-1] == '\r') line_len--;

    if (line_len > 0 && buf[line_start] != '#') {
      Bool neg = FALSE;
      I64 p_start = line_start;
      I64 p_len = line_len;
      if (buf[p_start] == '!') { neg = TRUE; p_start++; p_len--; }

      if (p_len > 0) {
        U8 kkind;
        I64 real_len;
        if (p_len >= 2 && buf[p_start+p_len-2]=='/' && buf[p_start+p_len-1]=='*') {
          kkind = IGNORE_KIND_DIR_CONTENTS;
          real_len = p_len - 2;
        } else if (buf[p_start+p_len-1] == '/') {
          kkind = IGNORE_KIND_DIR;
          real_len = p_len - 1;
        } else {
          Bool has_slash = FALSE;
          I64 si;
          for (si=0; si<p_len; si++) if (buf[p_start+si] == '/') has_slash = TRUE;
          if (has_slash) {
            kkind = IGNORE_KIND_SKIP;
            real_len = 0;
            CommPrint(1, "IGNORE_UNSUPPORTED_LINE ");
            I64 li;
            for (li=0; li<line_len; li++) CommPrint(1, "%c", buf[line_start+li]);
            CommPrint(1, "\n");
          } else {
            kkind = IGNORE_KIND_NAME;
            real_len = p_len;
          }
        }

        if (kkind != IGNORE_KIND_SKIP && real_len > 0 && real_len < 256) {
          I64 ci;
          for (ci=0; ci<real_len; ci++) patterns[count*256+ci] = buf[p_start+ci];
          patterns[count*256+real_len] = 0;
          negate[count] = neg;
          kind[count] = kkind;
          count++;
        }
      }
    }
  }

  *out_patterns = patterns;
  *out_negate = negate;
  *out_kind = kind;
  *out_count = count;
}

U0 IgnoreFree(U8 *patterns, U8 *negate, U8 *kind)
{
  if (patterns != NULL) Free(patterns);
  if (negate != NULL) Free(negate);
  if (kind != NULL) Free(kind);
}

// A real, minimal glob matcher: only `*` is special (matches any run
// of characters, including none), everything else is literal. No
// `**`/`?`/character classes - not needed by this grammar's own
// scope (ADR 0014), not built speculatively. Classic iterative
// backtracking match, not recursive (patterns/names here are always
// short, but this avoids call-depth concerns anyway).
Bool IgnoreGlobMatch(U8 *pattern, U8 *s)
{
  I64 plen = StrLen(pattern);
  I64 slen = StrLen(s);
  I64 ppi = 0, si = 0;
  I64 star_p = -1, star_s = -1;
  while (si < slen) {
    if (ppi < plen && pattern[ppi] == s[si]) { ppi++; si++; }
    else if (ppi < plen && pattern[ppi] == '*') { star_p = ppi; star_s = si; ppi++; }
    else if (star_p >= 0) { ppi = star_p+1; star_s++; si = star_s; }
    else return FALSE;
  }
  while (ppi < plen && pattern[ppi] == '*') ppi++;
  return ppi == plen;
}

// Checks whether one discovered candidate is ignored. `name` is its
// own basename; `rel_dir` is the real, root-relative directory path
// it lives directly inside (no leading/trailing slash, "" for the
// discovery root itself - flat, non-recursive callers always pass
// ""). Evaluates every real loaded pattern in file order; the LAST
// match (negated or not) wins.
Bool IsIgnored(U8 *patterns, U8 *negate, U8 *kind, I64 count,
               U8 *name, U8 *rel_dir)
{
  Bool ignored = FALSE;
  I64 i;
  for (i=0; i<count; i++) {
    U8 *pat = patterns + i*256;
    Bool matched = FALSE;
    if (kind[i] == IGNORE_KIND_NAME) {
      matched = IgnoreGlobMatch(pat, name);
    } else if (kind[i] == IGNORE_KIND_DIR) {
      matched = (StrCmp(pat, name) == 0);
    } else if (kind[i] == IGNORE_KIND_DIR_CONTENTS) {
      matched = (StrCmp(pat, rel_dir) == 0);
    }
    if (matched) ignored = !negate[i];
  }
  return ignored;
}

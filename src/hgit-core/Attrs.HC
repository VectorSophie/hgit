// Attrs.HC — minimal tracked file attributes and modes.
// Design decisions written up in `docs/adr/0015-file-attributes-and-modes.md`
// - read that first, this file only implements what it already
// decided.
//
// Three real pieces:
//   1. `IsContentBinary` - the NUL-byte heuristic, same real,
//      documented rule Git's own `is_binary` uses (a NUL byte
//      anywhere in the first 8000 bytes means binary).
//   2. `AttrsRulesLoad`/`GetEffectiveMode` - `.hgitattributes`
//      parsing and per-candidate mode resolution, reusing
//      `Ignore.HC`'s own pattern-kind/glob-matching machinery
//      (NAME/DIR/DIR_CONTENTS, ADR 0014) rather than a second bespoke
//      engine.
//   3. `AttrsListEncode`/`AttrsListFindMode` - the real, persisted
//      `OBJ_ATTRS` object content: a flat `[U64 entity_id][U8 mode]`
//      list, keyed by entity ID (not name/path - ADR 0015's own
//      requirement that mode stay independent of path/content hash).
//
// Depends on Ignore.HC (IgnoreGlobMatch, IGNORE_KIND_* reused
// directly - same pattern-kind values, same meaning), Canon.HC
// (GetU64LE/PutU64LE/GetU32LE/PutU32LE).

#define MODE_BINARY     0x01
#define MODE_EXECUTABLE 0x02

#define ATTR_UNSET 0 // this rule doesn't touch this line's own value at all

// Scans up to the first 8000 real bytes of `content` for any NUL
// byte - the same real, documented heuristic Git's own `is_binary`
// uses (confirmed via Git's own real docs/mailing-list history before
// adopting, not invented for this project). Returns TRUE (binary) the
// moment one is found.
Bool IsContentBinary(U8 *content, I64 content_len)
{
  I64 scan_len = content_len;
  if (scan_len > 8000) scan_len = 8000;
  I64 i;
  for (i=0; i<scan_len; i++) if (content[i] == 0) return TRUE;
  return FALSE;
}

// Reads and parses a real `.hgitattributes` file. Same real grammar
// kinds as `.hgitignore` (ADR 0014) - NAME/DIR/DIR_CONTENTS patterns,
// last-matching-line-wins - but each rule also carries which of the
// two independent dimensions it sets (`sets_mask`: bit 0 = text/binary,
// bit 1 = executable) and what value it sets them to (`value_mask`:
// bit 0 set means "binary" - clear means "text"; bit 1 set means
// "executable" - there is no "-executable" unset syntax, per ADR
// 0015's own "don't copy .gitattributes wholesale" scope).
// `out_*` are NULL/0 if the file doesn't exist - not an error, no
// rules just means every candidate is purely auto-detected.
U0 AttrsRulesLoad(U8 *attrs_path, U8 **out_patterns, U8 **out_kind,
                   U8 **out_sets, U8 **out_values, I64 *out_count)
{
  I64 fsize;
  U8 *buf = FileRead(attrs_path, &fsize);
  if (buf == NULL) {
    *out_patterns = NULL; *out_kind = NULL;
    *out_sets = NULL; *out_values = NULL; *out_count = 0;
    return;
  }

  I64 max_rules = fsize/2 + 2;
  U8 *patterns = MAlloc(max_rules*256);
  U8 *kind = MAlloc(max_rules);
  U8 *sets = MAlloc(max_rules);
  U8 *values = MAlloc(max_rules);
  I64 count = 0;
  I64 pos = 0;

  while (pos < fsize) {
    I64 line_start = pos;
    while (pos < fsize && buf[pos] != '\n') pos++;
    I64 line_len = pos - line_start;
    if (pos < fsize) pos++;
    if (line_len > 0 && buf[line_start+line_len-1] == '\r') line_len--;

    if (line_len > 0 && buf[line_start] != '#') {
      // Split on the first space: pattern, then a comma-separated
      // attribute list.
      I64 sp = -1, si;
      for (si=0; si<line_len; si++) if (buf[line_start+si] == ' ') { sp = si; si = line_len; }
      if (sp > 0 && sp < line_len - 1) {
        I64 p_len = sp;
        U8 kkind;
        I64 real_len;
        if (p_len >= 2 && buf[line_start+p_len-2]=='/' && buf[line_start+p_len-1]=='*') {
          kkind = IGNORE_KIND_DIR_CONTENTS;
          real_len = p_len - 2;
        } else if (buf[line_start+p_len-1] == '/') {
          kkind = IGNORE_KIND_DIR;
          real_len = p_len - 1;
        } else {
          Bool has_slash = FALSE;
          I64 psi;
          for (psi=0; psi<p_len; psi++) if (buf[line_start+psi] == '/') has_slash = TRUE;
          if (has_slash) {
            kkind = IGNORE_KIND_SKIP;
            real_len = 0;
          } else {
            kkind = IGNORE_KIND_NAME;
            real_len = p_len;
          }
        }

        // Parse the attribute list (comma-separated tokens after the
        // single space), building sets_mask/value_mask.
        U8 rule_sets = 0, rule_values = 0;
        Bool unsupported = FALSE;
        I64 tok_start = sp + 1;
        I64 ti;
        for (ti = sp + 1; ti <= line_len; ti++) {
          if (ti == line_len || buf[line_start+ti] == ',') {
            I64 tok_len = ti - tok_start;
            if (tok_len > 0) {
              U8 tok[32];
              I64 tci; I64 cap = tok_len; if (cap > 31) cap = 31;
              for (tci=0; tci<cap; tci++) tok[tci] = buf[line_start+tok_start+tci];
              tok[cap] = 0;
              if (StrCmp(tok, "text") == 0) { rule_sets |= 0x01; /* value bit 0 stays clear = text */ }
              else if (StrCmp(tok, "binary") == 0) { rule_sets |= 0x01; rule_values |= 0x01; }
              else if (StrCmp(tok, "executable") == 0) { rule_sets |= 0x02; rule_values |= 0x02; }
              else {
                unsupported = TRUE;
                CommPrint(1, "ATTR_UNSUPPORTED %s\n", tok);
              }
            }
            tok_start = ti + 1;
          }
        }

        if (kkind != IGNORE_KIND_SKIP && real_len > 0 && real_len < 256 && rule_sets != 0) {
          I64 ci;
          for (ci=0; ci<real_len; ci++) patterns[count*256+ci] = buf[line_start+ci];
          patterns[count*256+real_len] = 0;
          kind[count] = kkind;
          sets[count] = rule_sets;
          values[count] = rule_values;
          count++;
        } else if (kkind == IGNORE_KIND_SKIP) {
          CommPrint(1, "ATTR_UNSUPPORTED_LINE ");
          I64 li;
          for (li=0; li<line_len; li++) CommPrint(1, "%c", buf[line_start+li]);
          CommPrint(1, "\n");
        }
      }
    }
  }

  *out_patterns = patterns; *out_kind = kind;
  *out_sets = sets; *out_values = values; *out_count = count;
}

U0 AttrsRulesFree(U8 *patterns, U8 *kind, U8 *sets, U8 *values)
{
  if (patterns != NULL) Free(patterns);
  if (kind != NULL) Free(kind);
  if (sets != NULL) Free(sets);
  if (values != NULL) Free(values);
}

// Resolves one candidate's real effective mode: `.hgitattributes`
// rules (last matching line wins, per dimension independently) take
// precedence over `auto_binary` (the real, already-computed
// NUL-byte-heuristic result for this file's own content). Executable
// is NEVER auto-detected (ADR 0015 - TempleOS's own real filesystem
// exposes no such bit at all), only ever set by an explicit rule.
U8 GetEffectiveMode(U8 *patterns, U8 *kind, U8 *sets, U8 *values, I64 count,
                     U8 *name, U8 *rel_dir, Bool auto_binary)
{
  Bool tb_set = FALSE, tb_binary = FALSE;
  Bool exec_set = FALSE;
  I64 i;
  for (i=0; i<count; i++) {
    U8 *pat = patterns + i*256;
    Bool matched = FALSE;
    if (kind[i] == IGNORE_KIND_NAME) matched = IgnoreGlobMatch(pat, name);
    else if (kind[i] == IGNORE_KIND_DIR) matched = (StrCmp(pat, name) == 0);
    else if (kind[i] == IGNORE_KIND_DIR_CONTENTS) matched = (StrCmp(pat, rel_dir) == 0);
    if (matched) {
      if (sets[i] & 0x01) { tb_set = TRUE; tb_binary = (values[i] & 0x01) != 0; }
      if (sets[i] & 0x02) { exec_set = (values[i] & 0x02) != 0; }
    }
  }
  U8 mode = 0;
  if (tb_set) { if (tb_binary) mode |= MODE_BINARY; }
  else { if (auto_binary) mode |= MODE_BINARY; }
  if (exec_set) mode |= MODE_EXECUTABLE;
  return mode;
}

// `OBJ_ATTRS` content: a flat list, same shape convention as
// `Tree.HC`'s own entry list - `U32 count` (filled in by the caller
// once all entries are appended, same convention `TreeEncodeEntry`
// already uses) followed by `count` times `[U64 entity_id][U8 mode]`.
// Only non-default (nonzero) modes are ever appended by callers - a
// plain text, non-executable file costs nothing.
U0 AttrsListEncode(U8 *buf, I64 *len, U64 entity_id, U8 mode)
{
  PutU64LE(buf, *len, entity_id); *len += 8;
  buf[*len] = mode; *len += 1;
}

// Looks up one entity's mode in a decoded OBJ_ATTRS content buffer
// (the object's content with the type tag byte already stripped, same
// convention as `TreeFindEntry`). Returns FALSE (mode implicitly 0,
// plain text) if not listed - the common case for most files.
Bool AttrsListFindMode(U8 *attrs_buf, I64 attrs_len, U64 entity_id, U8 *mode_out)
{
  U32 count = GetU32LE(attrs_buf, 0);
  I64 pos = 4;
  U32 e;
  for (e=0; e<count; e++) {
    U64 this_entity = GetU64LE(attrs_buf, pos);
    U8 this_mode = attrs_buf[pos+8];
    if (this_entity == entity_id) { *mode_out = this_mode; return TRUE; }
    pos += 9;
  }
  return FALSE;
}

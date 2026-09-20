// ConflictDoc.HC — `hgit conflictdoc <repo> <dest.DD>`: a DolDoc view of
// the current path's in-progress merge conflicts (ADR 0016), v1.8.6.
//
// One collapsible $TR$ node per conflict showing entity identity, the
// conflict kind, and each of base/ours/theirs STRUCTURALLY: a text blob
// as its first lines (a simple line-oriented side-by-side-in-sequence
// presentation, not a merge), a binary blob as "(binary, N bytes)", a
// directory or an absent side (deletion) as exactly that - never
// pretending non-text is text. The view SUGGESTS the `hgit resolve`
// commands but never picks a side: choosing is the user's call.
//
// Depends on Canon.HC, Object.HC, Conflict.HC, Attrs.HC (IsContentBinary),
// Index.HC, Hex.HC, Meta.HC, Paths.HC.

#define CDOC_CAP 60000
#define CDOC_MAX_LINES 12
#define CDOC_MAX_LINE_CHARS 70

U0 CdAppend(U8 *doc, I64 *dlen, U8 *s)
{
  I64 i;
  for (i=0; s[i] && *dlen < CDOC_CAP; i++) doc[(*dlen)++] = s[i];
}

// Appends the first CDOC_MAX_LINES lines of blob text, escaped for
// DolDoc ('$' -> '$$', non-printables -> '.').
U0 CdAppendText(U8 *doc, I64 *dlen, U8 *text, I64 len)
{
  I64 lines = 0, col = 0, i;
  CdAppend(doc, dlen, "$FG,3$");
  for (i=0; i<len && lines<CDOC_MAX_LINES && *dlen < CDOC_CAP-8; i++) {
    U8 c = text[i];
    if (c == '\n') {
      CdAppend(doc, dlen, "\n");
      lines++; col = 0;
    } else if (col < CDOC_MAX_LINE_CHARS) {
      if (c == '$') { CdAppend(doc, dlen, "$$"); }
      else if (c < 32 || c > 126) { CdAppend(doc, dlen, "."); }
      else { doc[(*dlen)++] = c; }
      col++;
    }
  }
  if (i < len) CdAppend(doc, dlen, "\n... (more)");
  CdAppend(doc, dlen, "$FG$");
}

U0 CdAppendSide(U8 *doc, I64 *dlen, U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                U8 *label, Bool present, U8 type, U8 mode, U8 *hash)
{
  CdAppend(doc, dlen, "$FG,2$");
  CdAppend(doc, dlen, label);
  CdAppend(doc, dlen, "$FG$: ");
  if (!present) {
    CdAppend(doc, dlen, "(absent - deleted or not yet added on this side)\n");
  } else if (type == OBJ_TREE) {
    CdAppend(doc, dlen, "(directory)\n");
  } else {
    U8 hex[129];
    HashToHex(hash, hex);
    hex[12] = 0;
    CdAppend(doc, dlen, hex);
    CdAppend(doc, dlen, "  mode=");
    if (mode & MODE_BINARY) CdAppend(doc, dlen, "binary ");
    if (mode & MODE_EXECUTABLE) CdAppend(doc, dlen, "executable ");
    if (mode == 0) CdAppend(doc, dlen, "text ");
    CdAppend(doc, dlen, "\n");
    I64 off_rel;
    if (IndexLookup(idx_hashes, idx_offsets, idx_count, hash, &off_rel)) {
      I64 off = 16 + off_rel;
      U64 rec_len = GetU64LE(rbuf, off);
      I64 clen = rec_len - 1;
      U8 *content = rbuf + off + 9;
      if ((mode & MODE_BINARY) || IsContentBinary(content, clen)) {
        U8 nb[32];
        StrPrint(nb, "(binary, %d bytes)\n", clen);
        CdAppend(doc, dlen, nb);
      } else {
        CdAppendText(doc, dlen, content, clen);
        CdAppend(doc, dlen, "\n");
      }
    } else {
      CdAppend(doc, dlen, "(stored object missing - see hgit check)\n");
    }
  }
}

U0 HgitConflictDoc(U8 *repo_path, U8 *doc_path)
{
  U8 *doc = MAlloc(CDOC_CAP + 64);
  I64 dlen = 0;
  CdAppend(doc, &dlen, "$FG,5$hgit conflicts$FG$$CR$$CR$");

  U8 cur_name[HGIT_MAX_PATH_NAME];
  CurrentPathGet(repo_path, cur_name);
  if (!MetaMergeStateExists(repo_path, cur_name)) {
    CdAppend(doc, &dlen, "(no merge in progress on this path)$CR$");
    FileWrite(doc_path, doc, dlen);
    Free(doc);
    CommPrint(1, "CONFLICTDOC_OK none\n");
    return;
  }
  U8 ours_head[64], theirs_head[64], other_name[HGIT_MAX_PATH_NAME];
  MetaMergeStateRead(repo_path, cur_name, ours_head, theirs_head, other_name);

  CdAppend(doc, &dlen, "Merging path $FG,2$");
  CdAppend(doc, &dlen, other_name);
  CdAppend(doc, &dlen, "$FG$ into $FG,2$");
  CdAppend(doc, &dlen, cur_name);
  CdAppend(doc, &dlen, "$FG$ (repo: $LK,\"");
  CdAppend(doc, &dlen, repo_path);
  CdAppend(doc, &dlen, "\",A=\"FI:");
  CdAppend(doc, &dlen, repo_path);
  CdAppend(doc, &dlen, "\"$)$CR$");
  U8 hh[129];
  HashToHex(ours_head, hh); hh[12] = 0;
  CdAppend(doc, &dlen, "ours head:   "); CdAppend(doc, &dlen, hh); CdAppend(doc, &dlen, "$CR$");
  HashToHex(theirs_head, hh); hh[12] = 0;
  CdAppend(doc, &dlen, "theirs head: "); CdAppend(doc, &dlen, hh); CdAppend(doc, &dlen, "$CR$$CR$");

  I64 rsize;
  U8 *rbuf = HgitFileRead(repo_path, &rsize);
  U16 rver; U64 rcount;
  HgsReadHeader(rbuf, &rver, &rcount);
  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  I64 total = MetaConflictCount(repo_path, cur_name);
  I64 idx;
  for (idx=0; idx<total; idx++) {
    U8 chash[64], resolved, rhash[64];
    MetaConflictGetAt(repo_path, cur_name, idx, chash, &resolved, rhash);
    I64 coff;
    Bool cd_valid = FALSE;
    if (IndexLookup(idx_hashes, idx_offsets, idx_count, chash, &coff)) {
      U64 cd_rec = GetU64LE(rbuf, 16 + coff);
      cd_valid = ConflictContentValid(rbuf + 16 + coff + 9, cd_rec - 1);
    }
    if (cd_valid) {
      I64 off2 = 16 + coff;
      U8 kind; U64 ent; U8 path[256]; I64 plen;
      Bool pres[3]; U8 ty[3], mo[3], hs[192];
      ConflictDecode(rbuf + off2 + 9, &kind, &ent, path, &plen, pres, ty, mo, hs);

      U8 line[300];
      StrPrint(line, "$TR,\"%d  %s  [%s]\"$$CR$", idx, path, "conflict");
      if (resolved) StrPrint(line, "$TR,\"%d  %s  [resolved]\"$$CR$", idx, path);
      CdAppend(doc, &dlen, line);
      CdAppend(doc, &dlen, "$ID,+2$");

      U8 eh[32];
      U64ToHex(ent, eh);
      CdAppend(doc, &dlen, "entity ");
      CdAppend(doc, &dlen, eh);
      CdAppend(doc, &dlen, "   kind: ");
      if (kind & CONFLICT_KIND_CONTENT) CdAppend(doc, &dlen, "content ");
      if (kind & CONFLICT_KIND_MODE) CdAppend(doc, &dlen, "mode ");
      if (kind & CONFLICT_KIND_TYPE) CdAppend(doc, &dlen, "file-vs-directory ");
      CdAppend(doc, &dlen, "$CR$");

      CdAppendSide(doc, &dlen, rbuf, idx_hashes, idx_offsets, idx_count, "base  ", pres[0], ty[0], mo[0], hs);
      CdAppendSide(doc, &dlen, rbuf, idx_hashes, idx_offsets, idx_count, "ours  ", pres[1], ty[1], mo[1], hs+64);
      CdAppendSide(doc, &dlen, rbuf, idx_hashes, idx_offsets, idx_count, "theirs", pres[2], ty[2], mo[2], hs+128);

      if (resolved) {
        Bool rz = TRUE;
        I64 zi; for (zi=0; zi<64; zi++) if (rhash[zi] != 0) rz = FALSE;
        U8 *rw = "theirs";
        if (rz) rw = "deletion";
        else {
          Bool ro = pres[1];
          if (ro) for (zi=0; zi<64; zi++) if (hs[64+zi] != rhash[zi]) ro = FALSE;
          if (ro) rw = "ours";
        }
        CdAppend(doc, &dlen, "$FG,4$resolved to: ");
        CdAppend(doc, &dlen, rw);
        CdAppend(doc, &dlen, "$FG$$CR$");
      } else {
        U8 sug[200];
        StrPrint(sug, "options: hgit resolve <repo> %d take-ours | take-theirs (nothing chosen yet)$CR$", idx);
        CdAppend(doc, &dlen, sug);
      }
      CdAppend(doc, &dlen, "$ID,-2$");
    }
  }
  CdAppend(doc, &dlen, "$CR$Finish with: hgit merge continue <repo>   Discard with: hgit merge abort <repo>$CR$");

  FileWrite(doc_path, doc, dlen);
  CommPrint(1, "CONFLICTDOC_OK conflicts=%d\n", total);
  Free(idx_hashes);
  Free(idx_offsets);
  Free(doc);
}

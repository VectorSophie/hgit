// HistoryDoc.HC — `hgit historydoc`: the real DolDoc history view.
//
// Probe 46 (`experiments/46-doldoc-format/`) resolved the research
// question this depends on: `$..$` DolDoc commands are literal plain
// text, and a HolyC-written `.DD` file (via plain `FileWrite`) renders
// correctly when opened. This is that research put to use: walks the
// same parent chain `History.HC`'s `HgitHistory` already walks
// (reimplemented here rather than shared, since the two build very
// different output - plain `CommPrint` text vs. a `$..$`-formatted
// buffer), building a colored, real DolDoc document instead of plain
// text, then writes it with a normal `FileWrite` - no special API.
//
// Verified colors so far: `$FG,2$...$FG$` (green - used for the commit
// hash) and `$FG,4$...$FG$` (used for the timestamp) - the exact two
// color commands probe 46 confirmed render correctly from
// HolyC-generated output; `$CR$` for hard line breaks between commits.
//
// Depends on Canon.HC, Blake2b.HC, Hgs.HC, Object.HC, Commit.HC,
// Index.HC, Paths.HC (CurrentHeadRead), Hex.HC (HashToHex, for the
// hash shown per commit - not needed by plain HgitHistory, which never
// showed a hash at all).

U0 HgitHistoryDoc(U8 *repo_path, U8 *doc_path)
{
  U8 doc[8192];
  I64 dlen = 0;
  U8 *title = "$FG,5$hgit history$FG$$CR$$CR$";
  I64 ti;
  for (ti=0; title[ti]; ti++) doc[dlen++] = title[ti];

  U8 head_hash[64];
  if (!CurrentHeadRead(repo_path, head_hash)) {
    U8 *empty_msg = "(no offerings yet)$CR$";
    I64 ei;
    for (ei=0; empty_msg[ei]; ei++) doc[dlen++] = empty_msg[ei];
    FileWrite(doc_path, doc, dlen);
    return;
  }

  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  U16 rver;
  U64 rcount;
  HgsReadHeader(rbuf, &rver, &rcount);

  U8 idx_hashes[64*64];
  I64 idx_offsets[64];
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  U8 cur_hash[64];
  I64 k;
  for (k=0; k<64; k++) cur_hash[k] = head_hash[k];
  Bool has_cur = TRUE;

  while (has_cur) {
    I64 off_rel;
    Bool found = IndexLookup(idx_hashes, idx_offsets, idx_count, cur_hash, &off_rel);
    if (!found) break; // broken chain - stop, don't crash the doc write
    I64 off = 16 + off_rel; // same offset-relative-to-object-section
                             // gotcha as History.HC/See.HC - see those
                             // files' own comments, not repeated here.
    U8 obj_type = rbuf[off+8];
    U8 *content = rbuf + off + 9;
    if (obj_type != OBJ_COMMIT) break;

    U8 pcount = CommitParentCount(content);
    U64 ts = CommitTimestamp(content);
    U32 mlen = CommitMessageLen(content);
    U8 *msg = CommitMessage(content);

    U8 hex[129];
    HashToHex(cur_hash, hex);

    U8 *fg_hash = "$FG,2$";
    I64 fi;
    for (fi=0; fg_hash[fi]; fi++) doc[dlen++] = fg_hash[fi];
    // show a short prefix of the hash, not the full 128 hex chars -
    // matches how a real history view would want to display this
    // (full hash is still recoverable via `hgit see`).
    I64 hi;
    for (hi=0; hi<12; hi++) doc[dlen++] = hex[hi];
    U8 *fg_end = "$FG$ ";
    for (fi=0; fg_end[fi]; fi++) doc[dlen++] = fg_end[fi];

    U8 *fg_ts = "$FG,4$";
    for (fi=0; fg_ts[fi]; fi++) doc[dlen++] = fg_ts[fi];
    U8 ts_digits[24];
    I64 tlen = 0;
    if (ts == 0) { ts_digits[tlen++] = '0'; }
    U64 tsv = ts;
    U8 rev[24];
    I64 rlen = 0;
    while (tsv > 0) { rev[rlen++] = '0' + (tsv % 10); tsv /= 10; }
    for (fi=rlen-1; fi>=0; fi--) ts_digits[tlen++] = rev[fi];
    for (fi=0; fi<tlen; fi++) doc[dlen++] = ts_digits[fi];
    for (fi=0; fg_end[fi]; fi++) doc[dlen++] = fg_end[fi];

    for (k=0; k<mlen; k++) doc[dlen++] = msg[k];
    U8 *cr = "$CR$";
    for (fi=0; cr[fi]; fi++) doc[dlen++] = cr[fi];

    if (pcount > 0) {
      U8 *parent = CommitParentHash(content, 0);
      for (k=0; k<64; k++) cur_hash[k] = parent[k];
      has_cur = TRUE;
    } else {
      has_cur = FALSE;
    }
  }

  FileWrite(doc_path, doc, dlen);
}

// ReconcileDoc.HC — `hgit reconciledoc`: the first real DolDoc
// reconciliation view (M4).
//
// Probe 54 (`experiments/54-doldoc-widgets/`) confirmed `$LK$` renders
// as a real clickable/underlined link from HolyC-generated output.
// Probe 57 (`experiments/57-tree-widget/`) then resolved `$TR$`'s real
// syntax from actual TempleOS demo source
// (`C:/Demo/DolDoc/TreeDemo.HC`): a single self-contained
// `$TR,"<label>"$` command (no closing tag), with nesting done via a
// separate `$ID,+2$ ... $ID,-2$` bracket around the children. This
// file puts both to use: given a commit that carries an ADR 0005/0006
// relation (CONTINUES/CORRECTS/REVERTS/RECONCILES, optionally
// entity-scoped), it builds a real collapsible tree node for the
// relation (starts collapsed, per `$TR$`'s own documented behavior),
// with the target's `$LK$` link, the target commit's own message, and
// any entity scope as that node's nested children.
//
// Scoped honestly, matching probe 54's own findings: this does NOT
// test or implement following the link (that needs a human click or a
// callback dispatcher neither built nor verified yet - `Ed()` itself
// was found to block the daemon's command loop, so driving a click
// through the same automated push channel isn't possible without a
// human at the console). What's verified is that the link and the
// tree node are really there in both the raw bytes and the rendered
// view - see probe 55's and probe 58's own READMEs for exactly what
// was and wasn't checked.
//
// No function-like macros used here (untested territory in this
// codebase - every other .HC file only ever uses #define for plain
// constants, never a macro body) - each literal is appended with its
// own explicit loop, same style as HistoryDoc.HC.
//
// Depends on Canon.HC, Blake2b.HC, Hgs.HC, Object.HC, Commit.HC,
// Index.HC, Hex.HC.

U0 HgitReconcileDoc(U8 *repo_path, U8 *target_hash, U8 *doc_path)
{
  U8 doc[8192];
  I64 dlen = 0;
  I64 fi;
  U8 *title = "$FG,5$hgit reconciliation$FG$$CR$$CR$";
  for (fi=0; title[fi]; fi++) doc[dlen++] = title[fi];

  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  if (rbuf == NULL) {
    U8 *m1 = "(not a repository)$CR$";
    for (fi=0; m1[fi]; fi++) doc[dlen++] = m1[fi];
    FileWrite(doc_path, doc, dlen);
    return;
  }
  U16 rver; U64 rcount;
  if (!HgsReadHeader(rbuf, &rver, &rcount)) {
    U8 *m2 = "(bad header)$CR$";
    for (fi=0; m2[fi]; fi++) doc[dlen++] = m2[fi];
    FileWrite(doc_path, doc, dlen);
    return;
  }

  U8 idx_hashes[64*64];
  I64 idx_offsets[64];
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  I64 off_rel;
  if (!IndexLookup(idx_hashes, idx_offsets, idx_count, target_hash, &off_rel)) {
    U8 *m3 = "(commit not found)$CR$";
    for (fi=0; m3[fi]; fi++) doc[dlen++] = m3[fi];
    FileWrite(doc_path, doc, dlen);
    return;
  }
  I64 off = 16 + off_rel;
  U8 obj_type = rbuf[off+8];
  if (obj_type != OBJ_COMMIT) {
    U8 *m4 = "(not a commit)$CR$";
    for (fi=0; m4[fi]; fi++) doc[dlen++] = m4[fi];
    FileWrite(doc_path, doc, dlen);
    return;
  }
  U8 *content = rbuf + off + 9;

  U8 hex[129];
  HashToHex(target_hash, hex);
  U8 *fg_hash = "$FG,2$";
  for (fi=0; fg_hash[fi]; fi++) doc[dlen++] = fg_hash[fi];
  I64 hi;
  for (hi=0; hi<12; hi++) doc[dlen++] = hex[hi];
  U8 *fg_end = "$FG$ ";
  for (fi=0; fg_end[fi]; fi++) doc[dlen++] = fg_end[fi];

  U32 mlen = CommitMessageLen(content);
  U8 *msg = CommitMessage(content);
  I64 k;
  for (k=0; k<mlen; k++) doc[dlen++] = msg[k];
  U8 *cr2 = "$CR$$CR$";
  for (fi=0; cr2[fi]; fi++) doc[dlen++] = cr2[fi];

  U8 rel_tag = CommitRelationTag(content);
  if (rel_tag == REL_NONE) {
    U8 *m5 = "(no relation on this commit)$CR$";
    for (fi=0; m5[fi]; fi++) doc[dlen++] = m5[fi];
    FileWrite(doc_path, doc, dlen);
    return;
  }

  U8 *rel_name;
  if (rel_tag == REL_CONTINUES) rel_name = "CONTINUES";
  else if (rel_tag == REL_CORRECTS) rel_name = "CORRECTS";
  else if (rel_tag == REL_REVERTS) rel_name = "REVERTS";
  else if (rel_tag == REL_RECONCILES) rel_name = "RECONCILES";
  else rel_name = "UNKNOWN";

  U8 *rel_target = CommitRelationTarget(content);
  U8 rel_hex[129];
  HashToHex(rel_target, rel_hex);

  // One real collapsible tree node (probe 57) for the relation itself
  // - $TR$'s label is a plain quoted string, so the link and any other
  // $..$ commands stay OUTSIDE the label, as this node's indented
  // ($ID,+2$/$ID,-2$) children instead of embedded inside the quotes.
  U8 *tr_open = "$TR,\"relation: ";
  for (fi=0; tr_open[fi]; fi++) doc[dlen++] = tr_open[fi];
  for (fi=0; rel_name[fi]; fi++) doc[dlen++] = rel_name[fi];
  U8 *tr_close = "\"$$CR$$ID,+2$";
  for (fi=0; tr_close[fi]; fi++) doc[dlen++] = tr_close[fi];

  U8 *tgt_lbl = "target: $LK,\"";
  for (fi=0; tgt_lbl[fi]; fi++) doc[dlen++] = tgt_lbl[fi];
  for (hi=0; hi<128; hi++) doc[dlen++] = rel_hex[hi];
  U8 *lkmid = "\"$";
  for (fi=0; lkmid[fi]; fi++) doc[dlen++] = lkmid[fi];
  for (hi=0; hi<12; hi++) doc[dlen++] = rel_hex[hi];
  U8 *lkend = "$LK$$CR$";
  for (fi=0; lkend[fi]; fi++) doc[dlen++] = lkend[fi];

  // Show the target commit's own message too, if it's in this same
  // archive (it always will be for a same-repo relation, per ADR
  // 0005's own design).
  I64 toff_rel;
  if (IndexLookup(idx_hashes, idx_offsets, idx_count, rel_target, &toff_rel)) {
    I64 toff = 16 + toff_rel;
    if (rbuf[toff+8] == OBJ_COMMIT) {
      U8 *tcontent = rbuf + toff + 9;
      U32 tmlen = CommitMessageLen(tcontent);
      U8 *tmsg = CommitMessage(tcontent);
      U8 *tlbl = "target message: ";
      for (fi=0; tlbl[fi]; fi++) doc[dlen++] = tlbl[fi];
      for (k=0; k<tmlen; k++) doc[dlen++] = tmsg[k];
      U8 *cr3 = "$CR$";
      for (fi=0; cr3[fi]; fi++) doc[dlen++] = cr3[fi];
    }
  }

  U64 rel_entity_id = CommitRelationEntityId(content);
  if (rel_entity_id != 0) {
    U8 ehex[17];
    U64ToHex(rel_entity_id, ehex);
    U8 *elbl = "scoped to entity: ";
    for (fi=0; elbl[fi]; fi++) doc[dlen++] = elbl[fi];
    for (hi=0; hi<16; hi++) doc[dlen++] = ehex[hi];
    U8 *cr4 = "$CR$";
    for (fi=0; cr4[fi]; fi++) doc[dlen++] = cr4[fi];
  }

  U8 *id_close = "$ID,-2$";
  for (fi=0; id_close[fi]; fi++) doc[dlen++] = id_close[fi];

  FileWrite(doc_path, doc, dlen);
}

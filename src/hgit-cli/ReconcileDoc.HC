// ReconcileDoc.HC — `hgit reconciledoc`/`hgit reconcileoverview`: the
// real DolDoc reconciliation views (M4).
//
// Probe 54 (`experiments/54-doldoc-widgets/`) confirmed `$LK$` renders
// as a real clickable/underlined link from HolyC-generated output.
// Probe 57 (`experiments/57-tree-widget/`) then resolved `$TR$`'s real
// syntax from actual TempleOS demo source
// (`C:/Demo/DolDoc/TreeDemo.HC`): a single self-contained
// `$TR,"<label>"$` command (no closing tag), with nesting done via a
// separate `$ID,+2$ ... $ID,-2$` bracket around the children. Probe 58
// put both to use for one commit at a time (`HgitReconcileDoc`).
//
// Probe 59 (`experiments/59-reconcile-overview/`) factors the
// per-commit rendering out into `ReconcileEmitCommit` (defined first -
// HolyC has no forward declarations, a real recurring gotcha in this
// project, see docs/research/01-templeos-holyc.md) so a second real
// command, `HgitReconcileOverview`, can walk a repo's *entire* history
// (same parent-chain walk `HistoryDoc.HC` already does) and emit one
// real tree node per commit that actually carries a relation, skipping
// ordinary commits - a real multi-commit reconciliation view, not just
// a single-commit lookup the caller has to already know the hash for.
//
// Scoped honestly, matching probe 54's own findings: this does NOT
// test or implement following the link (that needs a human click or a
// callback dispatcher neither built nor verified yet - `Ed()` itself
// was found to block the daemon's command loop, so driving a click
// through the same automated push channel isn't possible without a
// human at the console). What's verified is that the link and the
// tree nodes are really there in both the raw bytes and the rendered
// view - see probe 55's, probe 58's, and probe 59's own READMEs for
// exactly what was and wasn't checked.
//
// No function-like macros used here (untested territory in this
// codebase - every other .HC file only ever uses #define for plain
// constants, never a macro body) - each literal is appended with its
// own explicit loop, same style as HistoryDoc.HC.
//
// Depends on Canon.HC, Blake2b.HC, Hgs.HC, Object.HC, Commit.HC,
// Index.HC, Hex.HC, Paths.HC (CurrentHeadRead, for HgitReconcileOverview).

// Appends one commit's short hash/message, and (if it carries an ADR
// 0005/0006 relation) a real collapsible $TR$ tree node for that
// relation, to `doc`/`*dlen`. `content` is the commit's own decoded
// object content (caller already resolved `cur_hash` via the index -
// shared here rather than re-looked-up, since HgitReconcileOverview's
// caller already has it mid-walk).
//
// Returns TRUE if this commit had a relation (so HgitReconcileOverview
// can count how many nodes it actually emitted).
Bool ReconcileEmitCommit(U8 *doc, I64 *dlen, U8 *rbuf,
                          U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                          U8 *cur_hash, U8 *content)
{
  I64 fi, hi, k;
  U8 hex[129];
  HashToHex(cur_hash, hex);
  U8 *fg_hash = "$FG,2$";
  for (fi=0; fg_hash[fi]; fi++) doc[*dlen+fi] = fg_hash[fi]; *dlen += fi;
  for (hi=0; hi<12; hi++) doc[(*dlen)++] = hex[hi];
  U8 *fg_end = "$FG$ ";
  for (fi=0; fg_end[fi]; fi++) doc[*dlen+fi] = fg_end[fi]; *dlen += fi;

  U32 mlen = CommitMessageLen(content);
  U8 *msg = CommitMessage(content);
  for (k=0; k<mlen; k++) doc[(*dlen)++] = msg[k];
  U8 *cr2 = "$CR$$CR$";
  for (fi=0; cr2[fi]; fi++) doc[*dlen+fi] = cr2[fi]; *dlen += fi;

  U8 rel_tag = CommitRelationTag(content);
  if (rel_tag == REL_NONE) {
    return FALSE;
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
  for (fi=0; tr_open[fi]; fi++) doc[*dlen+fi] = tr_open[fi]; *dlen += fi;
  for (fi=0; rel_name[fi]; fi++) doc[(*dlen)++] = rel_name[fi];
  U8 *tr_close = "\"$$CR$$ID,+2$";
  for (fi=0; tr_close[fi]; fi++) doc[*dlen+fi] = tr_close[fi]; *dlen += fi;

  U8 *tgt_lbl = "target: $LK,\"";
  for (fi=0; tgt_lbl[fi]; fi++) doc[*dlen+fi] = tgt_lbl[fi]; *dlen += fi;
  for (hi=0; hi<128; hi++) doc[(*dlen)++] = rel_hex[hi];
  U8 *lkmid = "\"$";
  for (fi=0; lkmid[fi]; fi++) doc[*dlen+fi] = lkmid[fi]; *dlen += fi;
  for (hi=0; hi<12; hi++) doc[(*dlen)++] = rel_hex[hi];
  U8 *lkend = "$LK$$CR$";
  for (fi=0; lkend[fi]; fi++) doc[*dlen+fi] = lkend[fi]; *dlen += fi;

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
      for (fi=0; tlbl[fi]; fi++) doc[*dlen+fi] = tlbl[fi]; *dlen += fi;
      for (k=0; k<tmlen; k++) doc[(*dlen)++] = tmsg[k];
      U8 *cr3 = "$CR$";
      for (fi=0; cr3[fi]; fi++) doc[*dlen+fi] = cr3[fi]; *dlen += fi;
    }
  }

  U64 rel_entity_id = CommitRelationEntityId(content);
  if (rel_entity_id != 0) {
    U8 ehex[17];
    U64ToHex(rel_entity_id, ehex);
    U8 *elbl = "scoped to entity: ";
    for (fi=0; elbl[fi]; fi++) doc[*dlen+fi] = elbl[fi]; *dlen += fi;
    for (hi=0; hi<16; hi++) doc[(*dlen)++] = ehex[hi];
    U8 *cr4 = "$CR$";
    for (fi=0; cr4[fi]; fi++) doc[*dlen+fi] = cr4[fi]; *dlen += fi;
  }

  U8 *id_close = "$ID,-2$";
  for (fi=0; id_close[fi]; fi++) doc[*dlen+fi] = id_close[fi]; *dlen += fi;

  return TRUE;
}

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

  // ADR 0007's same fix, applied here (experiments/62-index-buffer-sweep/):
  // idx_hashes/idx_offsets used to be fixed [64*64]/[64] stack arrays, a
  // hardcoded 64-object-in-the-whole-repo cap - MAlloc'd from `rcount`
  // (exact, from the .HGS header) instead, freed on every return path.
  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  I64 off_rel;
  if (!IndexLookup(idx_hashes, idx_offsets, idx_count, target_hash, &off_rel)) {
    U8 *m3 = "(commit not found)$CR$";
    for (fi=0; m3[fi]; fi++) doc[dlen++] = m3[fi];
    FileWrite(doc_path, doc, dlen);
    Free(idx_hashes);
    Free(idx_offsets);
    return;
  }
  I64 off = 16 + off_rel;
  U8 obj_type = rbuf[off+8];
  if (obj_type != OBJ_COMMIT) {
    U8 *m4 = "(not a commit)$CR$";
    for (fi=0; m4[fi]; fi++) doc[dlen++] = m4[fi];
    FileWrite(doc_path, doc, dlen);
    Free(idx_hashes);
    Free(idx_offsets);
    return;
  }
  U8 *content = rbuf + off + 9;

  Bool had_rel = ReconcileEmitCommit(doc, &dlen, rbuf, idx_hashes, idx_offsets,
                                      idx_count, target_hash, content);
  if (!had_rel) {
    U8 *m5 = "(no relation on this commit)$CR$";
    for (fi=0; m5[fi]; fi++) doc[dlen++] = m5[fi];
  }

  FileWrite(doc_path, doc, dlen);
  Free(idx_hashes);
  Free(idx_offsets);
}

// `hgit reconcileoverview <repo> <dest.DD>` - walks the whole real
// parent chain from HEAD (same walk `HistoryDoc.HC` does), emitting a
// real $TR$ tree node for every commit that carries a relation and
// skipping every commit that doesn't (a plain offer isn't
// reconciliation-relevant, so it's left out of this view entirely
// rather than cluttering it - `hgit historydoc` already covers the
// full plain history).
U0 HgitReconcileOverview(U8 *repo_path, U8 *doc_path)
{
  U8 doc[8192];
  I64 dlen = 0;
  I64 fi;
  U8 *title = "$FG,5$hgit reconciliation overview$FG$$CR$$CR$";
  for (fi=0; title[fi]; fi++) doc[dlen++] = title[fi];

  U8 head_hash[64];
  if (!CurrentHeadRead(repo_path, head_hash)) {
    U8 *m1 = "(no offerings yet)$CR$";
    for (fi=0; m1[fi]; fi++) doc[dlen++] = m1[fi];
    FileWrite(doc_path, doc, dlen);
    return;
  }

  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  U16 rver; U64 rcount;
  HgsReadHeader(rbuf, &rver, &rcount);

  // ADR 0007's same fix, applied here (experiments/62-index-buffer-sweep/):
  // idx_hashes/idx_offsets used to be fixed [64*64]/[64] stack arrays, a
  // hardcoded 64-object-in-the-whole-repo cap - MAlloc'd from `rcount`
  // (exact, from the .HGS header) instead, freed before this function's
  // one exit path (after the loop's own `break`s).
  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  U8 cur_hash[64];
  I64 zi;
  for (zi=0; zi<64; zi++) cur_hash[zi] = head_hash[zi];
  Bool has_cur = TRUE;
  I64 rel_count = 0;
  Bool truncated = FALSE;

  while (has_cur) {
    I64 off_rel;
    Bool found = IndexLookup(idx_hashes, idx_offsets, idx_count, cur_hash, &off_rel);
    if (!found) break;
    I64 off = 16 + off_rel;
    U8 obj_type = rbuf[off+8];
    if (obj_type != OBJ_COMMIT) break;
    U8 *content = rbuf + off + 9;

    // Same class of fixed-buffer risk probe 56 found and guarded in
    // Offer.HC: `doc[8192]` is unbounded against a repo's real commit
    // count/message sizes. A repo with many relation-carrying commits
    // (or long messages) could overflow it. Guarded the same way -
    // stop cleanly and say so, rather than silently overflowing.
    // 1024 bytes of headroom is a heuristic margin (one relation node
    // plus a commit's own header rarely exceeds it), not a proven
    // bound - same honest caveat as every other fixed-size buffer in
    // this codebase.
    if (dlen > 8192 - 1024) {
      truncated = TRUE;
      break;
    }

    I64 mark = dlen; // this view only shows relation-carrying commits;
                      // ReconcileEmitCommit always writes the commit's
                      // own hash/message header first, so a
                      // no-relation commit's header is rolled back by
                      // resetting dlen to this mark rather than
                      // teaching ReconcileEmitCommit to peek ahead
                      // before writing anything.
    Bool had_rel = ReconcileEmitCommit(doc, &dlen, rbuf, idx_hashes, idx_offsets,
                                        idx_count, cur_hash, content);
    if (had_rel) rel_count++;
    else dlen = mark;

    U8 pcount = CommitParentCount(content);
    if (pcount > 0) {
      U8 *parent = CommitParentHash(content, 0);
      I64 pj;
      for (pj=0; pj<64; pj++) cur_hash[pj] = parent[pj];
      has_cur = TRUE;
    } else {
      has_cur = FALSE;
    }
  }

  if (rel_count == 0) {
    U8 *m2 = "(no relations found in this repo's history)$CR$";
    for (fi=0; m2[fi]; fi++) doc[dlen++] = m2[fi];
  }
  if (truncated) {
    U8 *m3 = "(truncated - too many relations/commits for one document)$CR$";
    for (fi=0; m3[fi]; fi++) doc[dlen++] = m3[fi];
  }

  FileWrite(doc_path, doc, dlen);
  Free(idx_hashes);
  Free(idx_offsets);
}

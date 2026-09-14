// History.HC — `hgit history`: walk the parent chain from HEAD,
// printing each commit's timestamp and message.
//
// First real consumer of Index.HC's lookup for something other than a
// single dereference (probe 12's tree-entry case) - here it's walked
// repeatedly, once per commit, back through the parent chain. Only
// the first parent is ever followed (CommitParentHash(content, 0)) -
// this predates real merge commits (ADR 0011, probes 97-100), which
// now genuinely exist; a "first-parent-only" walk past a merge commit
// is a real, deliberate simplification for a plain sequential log
// (the same convention `git log --first-parent` names, not a bug),
// not the original "none have been created or tested" gap this
// comment used to describe. Confirmed against a real repo containing
// a real merge commit (probe 110, `experiments/110-history-graph-with-merge-commits/`):
// a merged-in path's own unique commits (only reachable via the
// merge's second parent) are honestly absent from this view - `hgit
// graph` is the command that surfaces them, nested under their own
// branch.
//
// Verified (experiments/19-hgit-history/) against the real two-commit
// repository `hgit offer` built in the previous session/probe - not a
// fresh fixture, an actual persisted repo from prior work, which this
// probe read back correctly across the QEMU reboot boundary.
//
// Depends on Canon.HC, Blake2b.HC, Hgs.HC, Object.HC, Commit.HC,
// Index.HC.

U0 HgitHistory(U8 *repo_path)
{
  U8 head_hash[64];
  if (!CurrentHeadRead(repo_path, head_hash)) {
    CommPrint(1, "HISTORY_EMPTY\n");
    return;
  }

  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  U16 rver;
  U64 rcount;
  HgsReadHeader(rbuf, &rver, &rcount);

  // ADR 0007's same fix, applied here (experiments/62-index-buffer-sweep/):
  // idx_hashes/idx_offsets used to be fixed [64*64]/[64] stack arrays, a
  // hardcoded 64-object-in-the-whole-repo cap - MAlloc'd from `rcount`
  // (exact, from the .HGS header) instead, freed on every return path.
  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  U8 cur_hash[64];
  I64 k;
  for (k=0; k<64; k++) cur_hash[k] = head_hash[k];
  Bool has_cur = TRUE;
  I64 shown = 0;

  while (has_cur) {
    I64 off_rel;
    Bool found = IndexLookup(idx_hashes, idx_offsets, idx_count, cur_hash, &off_rel);
    if (!found) { CommPrint(1, "HISTORY_ERR broken_chain\n"); Free(idx_hashes); Free(idx_offsets); return; }
    // IndexBuild's offsets are relative to the object section
    // (rbuf+16 was passed as its archive_buf), NOT the whole file -
    // must add the 16-byte header back to index into rbuf directly.
    // Same lesson as probe 12 (see failed-approaches.md) - got this
    // wrong again in a throwaway debug script while building this
    // very function, caught it, and this comment exists so it doesn't
    // happen a third time.
    I64 off = 16 + off_rel;
    U8 obj_type = rbuf[off+8];
    U8 *content = rbuf + off + 9;
    if (obj_type != OBJ_COMMIT) { CommPrint(1, "HISTORY_ERR not_a_commit type=%d\n", obj_type); Free(idx_hashes); Free(idx_offsets); return; }

    U8 pcount = CommitParentCount(content);
    U64 ts = CommitTimestamp(content);
    U32 mlen = CommitMessageLen(content);
    U8 *msg = CommitMessage(content);

    CommPrint(1, "commit ts=%d msg=", ts);
    for (k=0; k<mlen; k++) CommPrint(1, "%c", msg[k]);
    CommPrint(1, "\n");
    shown++;

    if (pcount > 0) {
      U8 *parent = CommitParentHash(content, 0);
      for (k=0; k<64; k++) cur_hash[k] = parent[k];
      has_cur = TRUE;
    } else {
      has_cur = FALSE;
    }
  }
  CommPrint(1, "HISTORY_END shown=%d\n", shown);
  Free(idx_hashes);
  Free(idx_offsets);
}

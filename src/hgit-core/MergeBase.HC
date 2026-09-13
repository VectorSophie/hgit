// MergeBase.HC — finds the lowest common ancestor of two commits.
//
// Real prerequisite chain, same "primitive first, then a real CLI
// decision" pattern ADR 0010's own probes 90/91 established: probe 97
// confirmed hgit's object model already supports a real multi-parent
// (merge) commit with zero code changes; this is the next real,
// separate, standalone piece ADR 0011's own `hgit merge` command needs
// - finding where two diverged paths' own histories actually split,
// before any real three-way tree merge can happen. Verified standalone
// (experiments/98-merge-base/) before any real command wires it in.
//
// Walks each commit's own parent[0] chain backward - the same
// single-parent-chain-following convention `History.HC`/
// `HistoryDoc.HC`/`Graph.HC`'s own fork-point search already use (all
// three explicitly, honestly document this as their own real,
// existing limitation, not new here). Correct for the real, common
// case this project's own history shape actually produces: a path
// forks once, directly, from another path's own chain (`Paths.HC`'s
// own `PathNew` copies the current path's HEAD at creation time, so a
// real, findable single fork point always exists on a direct ancestor
// path). A real, deliberate limitation for genuine criss-cross
// histories (multiple independent forks/merges producing ambiguous
// multiple lowest common ancestors, needing something like Git's own
// "recursive" strategy) - not attempted here, no evidence yet hgit's
// own real usage needs it.
//
// Depends on Canon.HC, Object.HC, Commit.HC, Index.HC.

Bool FindMergeBase(U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                   U8 *hash_a, U8 *hash_b, U8 *out_base_hash)
{
  // Walk chain A backward from its own tip, collecting every real
  // ancestor (including hash_a itself). MAlloc'd from idx_count - the
  // real upper bound on how many distinct commits could possibly
  // exist in this repo (no guessed cap, same discipline ADR 0007
  // established for every other dynamic buffer in this project).
  U8 *chain_a = MAlloc(idx_count*64 + 64);
  I64 chain_a_count = 0;
  U8 cur_a[64];
  I64 i;
  for (i=0; i<64; i++) cur_a[i] = hash_a[i];
  Bool has_cur_a = TRUE;
  while (has_cur_a) {
    for (i=0; i<64; i++) chain_a[chain_a_count*64+i] = cur_a[i];
    chain_a_count++;
    I64 off_rel;
    if (!IndexLookup(idx_hashes, idx_offsets, idx_count, cur_a, &off_rel)) {
      has_cur_a = FALSE;
    } else {
      I64 off = 16 + off_rel;
      if (rbuf[off+8] != OBJ_COMMIT) {
        has_cur_a = FALSE;
      } else {
        U8 *content = rbuf + off + 9;
        U8 pcount = CommitParentCount(content);
        if (pcount > 0) {
          U8 *parent = CommitParentHash(content, 0);
          for (i=0; i<64; i++) cur_a[i] = parent[i];
          has_cur_a = TRUE;
        } else {
          has_cur_a = FALSE;
        }
      }
    }
  }

  // Walk chain B backward from its own tip; the first commit that's
  // also in chain_a is the lowest common ancestor along this path.
  U8 cur_b[64];
  for (i=0; i<64; i++) cur_b[i] = hash_b[i];
  Bool has_cur_b = TRUE;
  Bool found = FALSE;
  while (has_cur_b && !found) {
    I64 ai;
    for (ai=0; ai<chain_a_count && !found; ai++) {
      Bool same = TRUE;
      I64 hi;
      for (hi=0; hi<64; hi++) if (chain_a[ai*64+hi] != cur_b[hi]) same = FALSE;
      if (same) {
        for (hi=0; hi<64; hi++) out_base_hash[hi] = cur_b[hi];
        found = TRUE;
      }
    }
    if (!found) {
      I64 off_rel_b;
      if (!IndexLookup(idx_hashes, idx_offsets, idx_count, cur_b, &off_rel_b)) {
        has_cur_b = FALSE;
      } else {
        I64 off_b = 16 + off_rel_b;
        if (rbuf[off_b+8] != OBJ_COMMIT) {
          has_cur_b = FALSE;
        } else {
          U8 *content_b = rbuf + off_b + 9;
          U8 pcount_b = CommitParentCount(content_b);
          if (pcount_b > 0) {
            U8 *parent_b = CommitParentHash(content_b, 0);
            for (i=0; i<64; i++) cur_b[i] = parent_b[i];
            has_cur_b = TRUE;
          } else {
            has_cur_b = FALSE;
          }
        }
      }
    }
  }

  Free(chain_a);
  return found;
}

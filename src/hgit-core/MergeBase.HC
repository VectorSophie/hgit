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
// Probe 109 (experiments/109-merge-base-stale-ancestor/): this
// function originally walked each commit's own parent[0] chain only -
// documented at the time as a deliberate limitation for "genuine
// criss-cross histories," with "no evidence yet hgit's own real usage
// needs" anything stronger. That was wrong once real merge commits
// existed: parent[0]-only isn't just ambiguous in a criss-cross case,
// it's flatly WRONG the moment either side's history passes through a
// real merge commit at all - a merge's own SECOND (and later) parent
// is invisible to a parent[0]-only walk, so a real, more-recent common
// ancestor reachable only through that side is silently skipped in
// favor of an older, stale one. Probe 109 built a real, minimal
// reproduction (two merges, the second one merging a path forked from
// the FIRST merge's non-"ours" side) and confirmed a real, wrong
// `MERGE_CONFLICT` where a clean, correct three-way merge should have
// happened - not a hypothetical, an actual observed failure.
//
// Fixed here: a real ancestor-SET walk considering EVERY parent (not
// just parent[0]) from each side. `CollectAllAncestors` does a real
// BFS from `hash_a` over the full parent DAG, producing hash_a's
// complete ancestor set. `FindMergeBase` itself then does a real BFS
// from `hash_b`, level by level over ALL its own parents too,
// returning the first node found in hash_a's ancestor set - the first
// match during a breadth-first walk from b is the closest (to b)
// common ancestor, a real, practical proxy for "most recent" that
// correctly reaches a merge's non-"ours" parent, not the exact
// Git-style "recursive merge-base" algorithm (which itself falls back
// to a virtual merge of multiple candidate bases in a genuine
// criss-cross case). Genuine criss-cross ambiguity (multiple real
// lowest common ancestors, no single correct answer) remains a real,
// separate, deliberately out-of-scope limitation - unrelated to and
// not fixed by this probe, which only fixes "ignoring real ancestry
// that was reachable all along."
//
// Depends on Canon.HC, Object.HC, Commit.HC, Index.HC.

// Real, minimal linear-scan "hash set" helpers - the same style this
// project already uses for name/hash arrays throughout (Status.HC's
// own new_matched/del_matched, etc.), not a new data structure. Both
// take a MAlloc'd `set` (idx_count*64+64 bytes, sized by the same real
// upper bound - total distinct objects in the repo - every other
// dynamic buffer in this file already uses).
Bool HashSetContains(U8 *set, I64 count, U8 *hash)
{
  I64 i, j;
  for (i=0; i<count; i++) {
    Bool same = TRUE;
    for (j=0; j<64; j++) if (set[i*64+j] != hash[j]) same = FALSE;
    if (same) return TRUE;
  }
  return FALSE;
}

// Adds `hash` to `set` if not already present. Returns TRUE if it was
// actually added (a real new node this BFS hasn't visited yet).
Bool HashSetAdd(U8 *set, I64 *count, U8 *hash)
{
  if (HashSetContains(set, *count, hash)) return FALSE;
  I64 i;
  for (i=0; i<64; i++) set[(*count)*64+i] = hash[i];
  (*count)++;
  return TRUE;
}

// A real BFS from `start_hash` over EVERY parent edge (not just
// parent[0]) - the complete ancestor set (including `start_hash`
// itself). `out_hashes` doubles as both the growing result set and
// the BFS frontier (append-only, scanned by index `qi` below) - no
// separate queue needed since nothing is ever removed, only appended.
U0 CollectAllAncestors(U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                       U8 *start_hash, U8 *out_hashes, I64 *out_count)
{
  *out_count = 0;
  HashSetAdd(out_hashes, out_count, start_hash);
  I64 qi = 0;
  while (qi < *out_count) {
    U8 *cur = out_hashes + qi*64;
    I64 off_rel;
    if (IndexLookup(idx_hashes, idx_offsets, idx_count, cur, &off_rel)) {
      I64 off = 16 + off_rel;
      if (rbuf[off+8] == OBJ_COMMIT) {
        U8 *content = rbuf + off + 9;
        U8 pcount = CommitParentCount(content);
        U8 pidx;
        for (pidx=0; pidx<pcount; pidx++) {
          U8 *parent = CommitParentHash(content, pidx);
          HashSetAdd(out_hashes, out_count, parent);
        }
      }
    }
    qi++;
  }
}

Bool FindMergeBase(U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                   U8 *hash_a, U8 *hash_b, U8 *out_base_hash)
{
  // hash_a's complete ancestor set (every real parent edge, not just
  // parent[0]) - MAlloc'd from idx_count, the same real upper bound
  // (total distinct objects in this repo) every other dynamic buffer
  // in this codebase already uses (no guessed cap, ADR 0007's own
  // discipline).
  U8 *ancestors_a = MAlloc(idx_count*64 + 64);
  I64 ancestors_a_count = 0;
  CollectAllAncestors(rbuf, idx_hashes, idx_offsets, idx_count,
                      hash_a, ancestors_a, &ancestors_a_count);

  // A real BFS from hash_b, level by level, over EVERY parent edge -
  // `queue_b` doubles as both the visited set (so a diamond-shaped
  // history never re-expands the same node twice) and the frontier,
  // same append-and-scan technique as CollectAllAncestors above. The
  // first node found in hash_a's ancestor set during this breadth-
  // first walk is the closest (to b) common ancestor - not
  // necessarily THE unique lowest common ancestor in a genuine
  // criss-cross case (still a real, separate, undecided question),
  // but always at least as correct as the old parent[0]-only walk,
  // and correctly reaches a merge's non-"ours" parent, which the old
  // walk never did.
  U8 *queue_b = MAlloc(idx_count*64 + 64);
  I64 queue_b_count = 0;
  HashSetAdd(queue_b, &queue_b_count, hash_b);

  Bool found = FALSE;
  I64 qi = 0;
  while (qi < queue_b_count && !found) {
    U8 *cur = queue_b + qi*64;
    if (HashSetContains(ancestors_a, ancestors_a_count, cur)) {
      I64 hi;
      for (hi=0; hi<64; hi++) out_base_hash[hi] = cur[hi];
      found = TRUE;
    } else {
      I64 off_rel;
      if (IndexLookup(idx_hashes, idx_offsets, idx_count, cur, &off_rel)) {
        I64 off = 16 + off_rel;
        if (rbuf[off+8] == OBJ_COMMIT) {
          U8 *content = rbuf + off + 9;
          U8 pcount = CommitParentCount(content);
          U8 pidx;
          for (pidx=0; pidx<pcount; pidx++) {
            U8 *parent = CommitParentHash(content, pidx);
            HashSetAdd(queue_b, &queue_b_count, parent);
          }
        }
      }
      qi++;
    }
  }

  Free(ancestors_a);
  Free(queue_b);
  return found;
}

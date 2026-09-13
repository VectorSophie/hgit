// Check.HC — `hgit check`: verify every object in a repo's own
// archive really hashes to what it claims to, AND that every hash one
// object refers to (a commit's tree/parents/relation-target, a tree's
// own child entries) actually resolves to a real object in the same
// store.
//
// The original brief's command list included a "shrine check" - a
// repo-integrity verification command - that was never wired in as
// M1's command surface grew (`init`/`status`/`offer`/`history`/`see`,
// then M2/M3/M4's own additions). Probe 64 built the first slice
// (hash integrity only, a thin wrapper over M0's `ArchiveVerify`) and
// explicitly flagged referential integrity as "a real, separate check,
// out of scope for this first slice." This file now does that too,
// modeled on real `git fsck`'s own "missing object" check
// (git-scm.com/docs/git-fsck) - confirmed via its actual docs, not
// assumed: fsck's most common real failure mode is a commit/tree
// referencing a hash with no corresponding object in the store, found
// by walking the object graph and checking every reference resolves.
// This is a real, direct analogue of that check, scoped to hgit's own
// simpler model (no refs/reachability graph - just "does every object
// currently in this repo's own store reference other objects that are
// also in the store," a strict subset of what `git fsck` calls
// "missing objects" and skips the "dangling"/"unreachable" categories,
// which need a real reachability-from-HEAD walk this project hasn't
// built).
//
// Depends on Canon.HC, Blake2b.HC, Archive.HC, Hgs.HC, Object.HC,
// Commit.HC, Tree.HC, Index.HC.

U0 HgitCheck(U8 *repo_path)
{
  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  if (rbuf == NULL) { CommPrint(1, "CHECK_ERR not_a_repository\n"); return; }
  U16 rver;
  U64 rcount;
  Bool hok = HgsReadHeader(rbuf, &rver, &rcount);
  if (!hok) { CommPrint(1, "CHECK_ERR bad_header\n"); return; }

  I64 total, ok;
  ArchiveVerify(rbuf+16, rsize-16, &total, &ok);

  if (total != rcount) {
    CommPrint(1, "CHECK_WARN object_count_mismatch header=%d scanned=%d\n",
              rcount, total);
  }
  if (ok == total) {
    CommPrint(1, "CHECK_OK objects=%d\n", total);
  } else {
    CommPrint(1, "CHECK_FAIL objects=%d ok=%d corrupt=%d\n", total, ok, total-ok);
  }

  // Referential integrity pass: build the same hash->offset index
  // every real command uses (ADR 0007's own MAlloc'd sizing, not a
  // fixed cap), then walk every commit/tree object's own outgoing
  // references and confirm each one resolves.
  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  I64 broken_refs = 0;
  I64 pos = 16;
  while (pos < rsize) {
    U64 rec_len = GetU64LE(rbuf, pos);
    U8 obj_type = rbuf[pos+8];
    U8 *content = rbuf + pos + 9;

    if (obj_type == OBJ_COMMIT) {
      U8 *tree_hash = CommitTreeHash(content);
      I64 dummy_off;
      if (!IndexLookup(idx_hashes, idx_offsets, idx_count, tree_hash, &dummy_off)) {
        U8 hex[129];
        HashToHex(tree_hash, hex);
        CommPrint(1, "CHECK_BROKEN_REF commit_tree_missing %s\n", hex);
        broken_refs++;
      }
      U8 pcount = CommitParentCount(content);
      U8 pidx;
      for (pidx=0; pidx<pcount; pidx++) {
        U8 *parent_hash = CommitParentHash(content, pidx);
        I64 poff;
        if (!IndexLookup(idx_hashes, idx_offsets, idx_count, parent_hash, &poff)) {
          U8 phex[129];
          HashToHex(parent_hash, phex);
          CommPrint(1, "CHECK_BROKEN_REF commit_parent_missing %s\n", phex);
          broken_refs++;
        }
      }
      U8 rel_tag = CommitRelationTag(content);
      if (rel_tag != REL_NONE) {
        U8 *rel_target = CommitRelationTarget(content);
        I64 roff;
        if (!IndexLookup(idx_hashes, idx_offsets, idx_count, rel_target, &roff)) {
          U8 rhex[129];
          HashToHex(rel_target, rhex);
          CommPrint(1, "CHECK_BROKEN_REF relation_target_missing %s\n", rhex);
          broken_refs++;
        }
      }
    } else if (obj_type == OBJ_TREE) {
      U32 tcount = GetU32LE(content, 0);
      I64 tpos = 4;
      U32 te;
      for (te=0; te<tcount; te++) {
        U8 tname_len = content[tpos]; tpos += 1;
        tpos += tname_len; // skip name
        tpos += 1; // skip child_type - not needed to look it up
        U8 *child_hash = content + tpos; tpos += 64;
        tpos += 8; // skip entity_id (ADR 0004)
        I64 coff;
        if (!IndexLookup(idx_hashes, idx_offsets, idx_count, child_hash, &coff)) {
          U8 chex[129];
          HashToHex(child_hash, chex);
          CommPrint(1, "CHECK_BROKEN_REF tree_child_missing %s\n", chex);
          broken_refs++;
        }
      }
    }

    // Matches Archive.HC's own ArchiveVerify pattern exactly - plain
    // I64/U64 arithmetic, no explicit cast needed (already proven safe
    // there); avoids probe 68's newly-found postfix-cast pitfalls by
    // just not casting at all here.
    pos += 8 + rec_len + 64; // len field + data (incl. type tag) + hash
  }

  if (broken_refs == 0) {
    CommPrint(1, "CHECK_REFS_OK\n");
  } else {
    CommPrint(1, "CHECK_REFS_FAIL broken=%d\n", broken_refs);
  }

  Free(idx_hashes);
  Free(idx_offsets);
}

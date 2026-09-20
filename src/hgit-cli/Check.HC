// Check.HC — `hgit check`: verify every object in a repo's own
// archive really hashes to what it claims to, AND that every hash one
// object refers to (a commit's tree/parents/relation-target, a tree's
// own child entries) actually resolves to a real object in the same
// store. Design decisions written up retroactively in
// `docs/adr/0013-repository-integrity-check.md`.
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
// This is a real, direct analogue of that check ("missing objects").
// The "dangling"/"unreachable" categories `git fsck` also reports were
// left out of that first slice, since they need a real reachability
// walk from every ref this project hadn't built yet - see below for
// that (and `docs/adr/0013-repository-integrity-check.md` for the
// full, three-slice design history).
//
// Depends on Canon.HC, Blake2b.HC, Archive.HC, Hgs.HC, Object.HC,
// Commit.HC, Tree.HC, Index.HC, Meta.HC, Conflict.HC (ADR 0016).
//
// (experiments/72-check-dangling-objects/): the "does no
// dangling/unreachable analysis" gap this file's own header comment
// used to flag is now closed too. `CheckMarkReachable` walks the real
// object graph - every declared path's HEAD (main plus every
// MetaPathDeclare'd name, via Meta.HC's `MetaPathListInto`), each
// commit's parents/tree/relation-target, each tree's own blob
// children - marking a parallel `reachable[]` array (indexed the same
// way `IndexBuild` filled `idx_hashes`/`idx_offsets`, via the new
// `IndexLookupPos`). Anything left unmarked after every path's history
// is walked is dangling: present in the store, unreachable from any
// real ref this repo has. Recursion stops the instant it re-enters an
// already-marked object, so shared history between multiple paths is
// only ever walked once.
//
// ADR 0015 addendum: a commit's own `attrs_hash` (if `has_attrs`) is
// now a real outgoing reference too, same as tree_hash/parent_hashes/
// relation_target above - a commit with attrs whose OBJ_ATTRS object
// went missing is exactly the "missing object" failure mode this
// file's own header comment already describes for every other
// reference, not a new category. OBJ_ATTRS itself has no further
// outgoing references (a flat entity_id/mode list, no hashes inside).

// Marks `hash`'s object (and everything real it references) reachable
// in `reachable[]`. A no-op if `hash` isn't in the index at all (a
// broken reference - already reported by the referential-integrity
// pass above) or if it's already marked (stops re-walking shared
// history between paths, and rules out infinite recursion - a real
// content-addressed object graph can't contain a cycle without a hash
// collision).
U0 CheckMarkReachable(U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                      Bool *reachable, U8 *hash)
{
  I64 ipos;
  if (!IndexLookupPos(idx_hashes, idx_count, hash, &ipos)) return;
  if (reachable[ipos]) return;
  reachable[ipos] = TRUE;

  I64 off = 16 + idx_offsets[ipos]; // idx_offsets are relative to
                                     // rbuf+16 - same convention every
                                     // other real command follows
                                     // (See.HC/Status.HC's own "Index
                                     // offsets are relative to..." note).
  U8 obj_type = rbuf[off+8];
  U8 *content = rbuf + off + 9;

  if (obj_type == OBJ_COMMIT) {
    U8 *tree_hash = CommitTreeHash(content);
    CheckMarkReachable(rbuf, idx_hashes, idx_offsets, idx_count, reachable, tree_hash);
    U8 pcount = CommitParentCount(content);
    U8 pidx;
    for (pidx=0; pidx<pcount; pidx++) {
      U8 *parent_hash = CommitParentHash(content, pidx);
      CheckMarkReachable(rbuf, idx_hashes, idx_offsets, idx_count, reachable, parent_hash);
    }
    U8 rel_tag = CommitRelationTag(content);
    if (rel_tag != REL_NONE) {
      U8 *rel_target = CommitRelationTarget(content);
      CheckMarkReachable(rbuf, idx_hashes, idx_offsets, idx_count, reachable, rel_target);
    }
    // ADR 0015: figures out `content_len` the same way every other
    // real reader of a commit record does - `rec_len` (the archive's
    // own length prefix, includes the type tag byte) minus 1.
    U64 commit_rec_len = GetU64LE(rbuf, off);
    I64 commit_content_len = commit_rec_len - 1;
    if (CommitHasAttrs(content, commit_content_len)) {
      U8 *attrs_hash = CommitAttrsHash(content);
      CheckMarkReachable(rbuf, idx_hashes, idx_offsets, idx_count, reachable, attrs_hash);
    }
  } else if (obj_type == OBJ_TREE) {
    U32 tcount = GetU32LE(content, 0);
    I64 tpos = 4;
    U32 te;
    for (te=0; te<tcount; te++) {
      U8 tname_len = content[tpos]; tpos += 1;
      tpos += tname_len; // skip name
      tpos += 1; // skip child_type
      U8 *child_hash = content + tpos; tpos += 64;
      tpos += 8; // skip entity_id (ADR 0004)
      CheckMarkReachable(rbuf, idx_hashes, idx_offsets, idx_count, reachable, child_hash);
    }
  } else if (obj_type == OBJ_CONFLICT) {
    // ADR 0016: same pattern as every other real object type here,
    // extended for this one - a conflict object's own base/ours/
    // theirs hashes (whichever sides are `present`) are real outgoing
    // references too, not just inert bytes. Reached via
    // `HgitCheck`'s own new commit-independent root (every declared
    // path's in-progress merge conflicts), not from any commit.
    U8 ck_conflict_kind;
    U64 ck_entity_id;
    U8 ck_path[256];
    I64 ck_path_len;
    Bool ck_present[3]; U8 ck_type[3], ck_mode[3], ck_hash[192];
    U64 ck_rec_len = GetU64LE(rbuf, off);
    if (ConflictContentValid(content, ck_rec_len - 1)) {
      ConflictDecode(content, &ck_conflict_kind, &ck_entity_id, ck_path, &ck_path_len,
                     ck_present, ck_type, ck_mode, ck_hash);
      I64 ck_side;
      for (ck_side=0; ck_side<3; ck_side++) {
        if (ck_present[ck_side]) {
          CheckMarkReachable(rbuf, idx_hashes, idx_offsets, idx_count, reachable, ck_hash+ck_side*64);
        }
      }
    }
  }
  // OBJ_BLOB/OBJ_ATTRS: no outgoing references, nothing further to mark.
}

U0 HgitCheck(U8 *repo_path)
{
  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  if (rbuf == NULL) { CommPrint(1, "CHECK_ERR not_a_repository\n"); return; }
  U16 rver;
  U64 rcount;
  Bool hok = HgsReadHeader(rbuf, &rver, &rcount);
  if (!hok) {
    if (hgs_unsupported_version) CommPrint(1, "CHECK_ERR unsupported_format_version=%d (this build reads up to %d) - written by a newer hgit\n", hgs_unsupported_version, HGS_MAX_SUPPORTED_VERSION);
    else CommPrint(1, "CHECK_ERR bad_header\n");
    return;
  }

  I64 total, ok;
  ArchiveVerify(rbuf+16, rsize-16, &total, &ok);

  if (total != rcount) {
    CommPrint(1, "CHECK_WARN object_count_mismatch header=%d scanned=%d\n",
              rcount, total);
  }
  // Probe 113 (experiments/113-check-format-version/): `format_version`
  // was read here (and everywhere else that opens a repo) but never
  // actually shown to a user by ANY real command - a real, previously-
  // unnoticed gap (found while investigating FORMAT.md's own
  // versioning-policy inconsistency) now that the version means
  // something worth checking.
  if (ok == total) {
    CommPrint(1, "CHECK_OK objects=%d format_version=%d\n", total, rver);
  } else {
    CommPrint(1, "CHECK_FAIL objects=%d ok=%d corrupt=%d format_version=%d\n", total, ok, total-ok, rver);
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
      // ADR 0015: `content_len` here is `rec_len` (this loop's own
      // length prefix, already read above, includes the type tag)
      // minus 1 - same convention as every other content_len in this
      // project.
      I64 commit_content_len2 = rec_len - 1;
      if (CommitHasAttrs(content, commit_content_len2)) {
        U8 *attrs_hash = CommitAttrsHash(content);
        I64 aoff;
        if (!IndexLookup(idx_hashes, idx_offsets, idx_count, attrs_hash, &aoff)) {
          U8 ahex[129];
          HashToHex(attrs_hash, ahex);
          CommPrint(1, "CHECK_BROKEN_REF commit_attrs_missing %s\n", ahex);
          broken_refs++;
        }
      }
    } else if (obj_type == OBJ_CONFLICT) {
      // v1.8.7: every conflict object in the archive must be well-formed,
      // whether or not any merge state currently references it.
      if (!ConflictContentValid(content, rec_len - 1)) {
        U8 mal_hex[129];
        HashToHex(rbuf + pos + 9 + rec_len - 1, mal_hex);
        CommPrint(1, "CHECK_BROKEN_REF conflict_object_malformed %s\n", mal_hex);
        broken_refs++;
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

  I64 path_count = MetaPathCount(repo_path);
  U8 *path_names = MAlloc((path_count+1)*META_MAX_PATH_NAME);
  I64 real_path_count;
  MetaPathListInto(repo_path, path_names, &real_path_count);

  // ADR 0016: every declared path's own in-progress merge conflicts
  // are a real, separate referential-integrity root - a missing
  // conflict dependency is exactly the same "missing object" failure
  // mode as every other real reference checked above, so it folds
  // into the same `broken_refs` count and report, not a separate
  // pass/summary.
  // No `continue` in HolyC (probe 5's own documented quirk) - the
  // whole per-path body is guarded by `if (MetaMergeStateExists(...))`
  // instead of an early skip.
  I64 pmc;
  for (pmc=0; pmc<real_path_count; pmc++) {
    U8 *pmc_name = path_names + pmc*META_MAX_PATH_NAME;
    if (MetaMergeStateExists(repo_path, pmc_name)) {
      I64 pmc_conflict_total = MetaConflictCount(repo_path, pmc_name);
      I64 pmc_ci;
      for (pmc_ci=0; pmc_ci<pmc_conflict_total; pmc_ci++) {
        U8 pmc_ch[64], pmc_resolved, pmc_rh[64];
        MetaConflictGetAt(repo_path, pmc_name, pmc_ci, pmc_ch, &pmc_resolved, pmc_rh);
        I64 pmc_off;
        if (!IndexLookup(idx_hashes, idx_offsets, idx_count, pmc_ch, &pmc_off)) {
          U8 pmc_hex[129];
          HashToHex(pmc_ch, pmc_hex);
          CommPrint(1, "CHECK_BROKEN_REF conflict_object_missing %s\n", pmc_hex);
          broken_refs++;
        } else {
          I64 pmc_off2 = 16 + pmc_off;
          U8 *pmc_content = rbuf + pmc_off2 + 9;
          U8 pmc_kind; U64 pmc_entity_id; U8 pmc_path[256]; I64 pmc_path_len;
          Bool pmc_present[3]; U8 pmc_type[3], pmc_mode[3], pmc_hash[192];
          U64 pmc_rec_len = GetU64LE(rbuf, pmc_off2);
          pmc_present[0] = FALSE; pmc_present[1] = FALSE; pmc_present[2] = FALSE;
          if (ConflictContentValid(pmc_content, pmc_rec_len - 1)) {
            ConflictDecode(pmc_content, &pmc_kind, &pmc_entity_id, pmc_path, &pmc_path_len,
                           pmc_present, pmc_type, pmc_mode, pmc_hash);
          } else {
            U8 pmc_bad_hex[129];
            HashToHex(pmc_ch, pmc_bad_hex);
            CommPrint(1, "CHECK_BROKEN_REF conflict_malformed %s\n", pmc_bad_hex);
            broken_refs++;
          }
          I64 pmc_side;
          for (pmc_side=0; pmc_side<3; pmc_side++) {
            if (pmc_present[pmc_side]) {
              I64 pmc_side_off;
              if (!IndexLookup(idx_hashes, idx_offsets, idx_count, pmc_hash+pmc_side*64, &pmc_side_off)) {
                U8 pmc_side_hex[129];
                HashToHex(pmc_hash+pmc_side*64, pmc_side_hex);
                CommPrint(1, "CHECK_BROKEN_REF conflict_side_missing %s\n", pmc_side_hex);
                broken_refs++;
              }
            }
          }
        }
      }
    }
  }

  if (broken_refs == 0) {
    CommPrint(1, "CHECK_REFS_OK\n");
  } else {
    CommPrint(1, "CHECK_REFS_FAIL broken=%d\n", broken_refs);
  }

  // Dangling/unreachable pass: mark every object reachable from every
  // real path's HEAD, then report whatever's left unmarked.
  Bool *reachable = MAlloc(idx_count + 1);
  I64 zi;
  for (zi=0; zi<idx_count; zi++) reachable[zi] = FALSE;

  I64 pi2; // NOT "pi" - reserved F64 constant, probe 41's own gotcha
  for (pi2=0; pi2<real_path_count; pi2++) {
    U8 *pname = path_names + pi2*META_MAX_PATH_NAME;
    U8 phead_hash[64];
    if (MetaReadHead(repo_path, pname, phead_hash)) {
      CheckMarkReachable(rbuf, idx_hashes, idx_offsets, idx_count, reachable, phead_hash);
    }
  }

  // ADR 0016: a new commit-independent reachability root - an
  // in-progress merge's own conflict evidence is real, live, actively-
  // referenced data (from Meta.HC, not the commit graph), not garbage,
  // so it must not show up as CHECK_DANGLING while unresolved.
  // No `continue` in HolyC - same guard-the-whole-body pattern as above.
  I64 pmr;
  for (pmr=0; pmr<real_path_count; pmr++) {
    U8 *pmr_name = path_names + pmr*META_MAX_PATH_NAME;
    if (MetaMergeStateExists(repo_path, pmr_name)) {
      I64 pmr_conflict_total = MetaConflictCount(repo_path, pmr_name);
      I64 pmr_ci;
      for (pmr_ci=0; pmr_ci<pmr_conflict_total; pmr_ci++) {
        U8 pmr_ch[64], pmr_resolved, pmr_rh[64];
        MetaConflictGetAt(repo_path, pmr_name, pmr_ci, pmr_ch, &pmr_resolved, pmr_rh);
        CheckMarkReachable(rbuf, idx_hashes, idx_offsets, idx_count, reachable, pmr_ch);
      }
    }
  }

  // Coalesce duplicates: `Object.HC`'s own `ObjectPut` is a plain
  // append with no content-hash dedup, so if the same content is
  // offered more than once over a repo's life (found in practice on
  // `P65Repo.hgs`, a long-lived repo this project has reoffered the
  // same "v1"/"v2" content into across many probes), the exact same
  // hash can occupy several different archive positions.
  // `CheckMarkReachable`'s `IndexLookupPos` scan only ever marks
  // whichever position it finds *first* as reachable - every OTHER
  // position holding that identical hash is content-identical (same
  // hash = same content) and therefore equally reachable, just never
  // marked. One linear coalescing pass fixes this: no fixed point
  // needed, since a duplicate's own outgoing references are
  // byte-identical to the original's and already resolved by the
  // original's own walk.
  I64 ca, cb;
  for (ca=0; ca<idx_count; ca++) {
    if (!reachable[ca]) {
      for (cb=0; cb<idx_count; cb++) {
        Bool dup_of_reachable = reachable[cb];
        I64 hb;
        if (dup_of_reachable) {
          for (hb=0; hb<64; hb++) {
            if (idx_hashes[ca*64+hb] != idx_hashes[cb*64+hb]) dup_of_reachable = FALSE;
          }
        }
        if (dup_of_reachable) { reachable[ca] = TRUE; break; }
      }
    }
  }

  I64 dangling = 0;
  for (zi=0; zi<idx_count; zi++) {
    if (!reachable[zi]) {
      dangling++;
      I64 doff = 16 + idx_offsets[zi];
      U8 dtype = rbuf[doff+8];
      U8 *kind = "blob";
      if (dtype == OBJ_COMMIT) kind = "commit";
      else if (dtype == OBJ_TREE) kind = "tree";
      else if (dtype == OBJ_ATTRS) kind = "attrs";
      else if (dtype == OBJ_CONFLICT) kind = "conflict";
      U8 dhex[129];
      HashToHex(idx_hashes + zi*64, dhex);
      CommPrint(1, "CHECK_DANGLING %s %s\n", kind, dhex);
    }
  }
  if (dangling == 0) CommPrint(1, "CHECK_DANGLING_NONE\n");
  else CommPrint(1, "CHECK_DANGLING_COUNT %d\n", dangling);

  Free(idx_hashes);
  Free(idx_offsets);
  Free(reachable);
  Free(path_names);
}

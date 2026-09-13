// Merge.HC — `hgit merge <repo> <other_path_name>`: bring another
// declared path's own history into the current path.
//
// Real, deliberately narrow first slice, matching ADR 0010's own
// established scoping discipline - probe 97 confirmed the object
// model already supports multi-parent commits (zero code changes),
// probe 98 built and verified `FindMergeBase`; this is the real
// three-way tree merge and CLI wiring those two probes were building
// toward.
//
// Scope of THIS slice (real, testable, honestly limited - see
// experiments/99-hgit-merge/README.md for the full account):
//
//   - Flat trees only. A name where either side's own entry is a real
//     `OBJ_TREE` (a subdirectory) is reported as a real, honest
//     `MERGE_CONFLICT_UNSUPPORTED_NESTED <name>` and aborts the whole
//     merge - not silently skipped, not guessed at. Recursing a
//     three-way merge into nested trees (reusing `Diff.HC`'s own
//     recursive pattern) is real, separate follow-up work.
//   - No conflict RESOLUTION exists yet - a real conflict of any kind
//     (both sides changed the same name differently; one side deleted
//     it while the other edited it; both sides added the same name
//     with different content) aborts the ENTIRE merge with zero
//     side effects (no commit created, no HEAD moved) - the same
//     non-destructive stance every other real hgit command already
//     takes. A user resolves manually outside hgit (edit the working
//     directory to what it should be) and re-offers - there is no
//     conflict-marker blob format or resolution command yet.
//   - Trivial cases (`theirs` already an ancestor of `ours` - nothing
//     to do; `ours` unchanged since the merge base - a real
//     fast-forward, just moving the current path's HEAD) are detected
//     and handled without a merge commit, matching every real VCS's
//     own standard fast-forward behavior.
//
// Depends on Canon.HC, Blake2b.HC, Hgs.HC, Object.HC, Tree.HC,
// Commit.HC, Index.HC, MergeBase.HC, Meta.HC, Paths.HC, OpLog.HC.

#define MERGE_ARCHIVE_HEADROOM 20000
#define MERGE_ARCHIVE_SANITY_MAX 1000000000

// Resolves a commit hash to its own tree's content/length, via the
// same IndexLookup->IndexLookup chain every real command already
// uses (commit -> tree_hash -> tree object). Returns FALSE (not a
// crash) if either lookup fails - a broken reference is Check.HC's
// own job to report, not this file's.
Bool MergeResolveCommitTree(U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                            U8 *commit_hash, U8 **out_tree_content, I64 *out_tree_len)
{
  I64 c_off_rel;
  if (!IndexLookup(idx_hashes, idx_offsets, idx_count, commit_hash, &c_off_rel)) return FALSE;
  I64 c_off = 16 + c_off_rel;
  if (rbuf[c_off+8] != OBJ_COMMIT) return FALSE;
  U8 *c_content = rbuf + c_off + 9;
  U8 *tree_hash = CommitTreeHash(c_content);

  I64 t_off_rel;
  if (!IndexLookup(idx_hashes, idx_offsets, idx_count, tree_hash, &t_off_rel)) return FALSE;
  I64 t_off = 16 + t_off_rel;
  U64 t_rec_len = GetU64LE(rbuf, t_off);
  *out_tree_content = rbuf + t_off + 9;
  *out_tree_len = t_rec_len - 1;
  return TRUE;
}

// Collects every distinct entry NAME across two flat trees into
// `names_out` (one 256-byte slot each), returning the real count.
// `extra_tree` may be NULL (the merge base can genuinely not exist as
// a real ancestor tree in a degenerate case, though FindMergeBase
// having already succeeded makes this unlikely in practice - handled
// anyway, not assumed away).
I64 MergeCollectNames(U8 *tree_a, I64 tree_a_len, U8 *tree_b, I64 tree_b_len,
                      U8 *tree_c, I64 tree_c_len, U8 *names_out)
{
  I64 name_count = 0;
  I64 which;
  for (which=0; which<3; which++) {
    U8 *t = tree_a; I64 tlen = tree_a_len;
    if (which==1) { t = tree_b; tlen = tree_b_len; }
    if (which==2) { t = tree_c; tlen = tree_c_len; }
    // No `continue` in HolyC (probe 5's own documented quirk) - guard
    // this whole loop body with `if (t != NULL)` instead of an early
    // skip.
    if (t != NULL) {
      U32 tcount = GetU32LE(t, 0);
      I64 tpos = 4;
      U32 te;
      for (te=0; te<tcount; te++) {
        U8 tname_len = t[tpos]; tpos += 1;
        U8 *tname = t + tpos; tpos += tname_len;
        tpos += 1;  // child_type
        tpos += 64; // child_hash
        tpos += 8;  // entity_id

        Bool already = FALSE;
        I64 ni;
        for (ni=0; ni<name_count && !already; ni++) {
          Bool same_name = (StrLen(names_out+ni*256) == tname_len);
          I64 ci;
          if (same_name) for (ci=0; ci<tname_len; ci++) if (names_out[ni*256+ci] != tname[ci]) same_name = FALSE;
          if (same_name) already = TRUE;
        }
        if (!already) {
          I64 cap = tname_len; if (cap > 254) cap = 254;
          I64 ci2;
          for (ci2=0; ci2<cap; ci2++) names_out[name_count*256+ci2] = tname[ci2];
          names_out[name_count*256+cap] = 0;
          name_count++;
        }
      }
    }
  }
  return name_count;
}

U0 HgitMerge(U8 *repo_path, U8 *other_path_name, U64 timestamp)
{
  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  if (rbuf == NULL) { CommPrint(1, "MERGE_ERR not_a_repository\n"); return; }
  U16 rver;
  U64 rcount;
  Bool hok = HgsReadHeader(rbuf, &rver, &rcount);
  if (!hok) { CommPrint(1, "MERGE_ERR bad_header\n"); return; }

  U8 ours_head[64];
  if (!CurrentHeadRead(repo_path, ours_head)) {
    CommPrint(1, "MERGE_ERR no_head_on_current_path\n");
    return;
  }
  U8 theirs_head[64];
  if (!MetaReadHead(repo_path, other_path_name, theirs_head)) {
    CommPrint(1, "MERGE_ERR other_path_not_found %s\n", other_path_name);
    return;
  }

  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  U8 base_head[64];
  Bool base_found = FindMergeBase(rbuf, idx_hashes, idx_offsets, idx_count,
                                  ours_head, theirs_head, base_head);
  if (!base_found) {
    CommPrint(1, "MERGE_ERR no_common_ancestor\n");
    Free(idx_hashes); Free(idx_offsets);
    return;
  }

  I64 hi;
  Bool ours_is_base = TRUE;
  for (hi=0; hi<64; hi++) if (ours_head[hi] != base_head[hi]) ours_is_base = FALSE;
  Bool theirs_is_base = TRUE;
  for (hi=0; hi<64; hi++) if (theirs_head[hi] != base_head[hi]) theirs_is_base = FALSE;

  if (theirs_is_base) {
    CommPrint(1, "MERGE_ALREADY_UP_TO_DATE\n");
    Free(idx_hashes); Free(idx_offsets);
    return;
  }
  if (ours_is_base) {
    CurrentHeadWrite(repo_path, theirs_head);
    OpLogAppend(repo_path, ours_head, theirs_head, timestamp);
    CommPrint(1, "MERGE_FASTFORWARD\n");
    Free(idx_hashes); Free(idx_offsets);
    return;
  }

  U8 *ours_tree = NULL; I64 ours_tree_len = 0;
  U8 *theirs_tree = NULL; I64 theirs_tree_len = 0;
  U8 *base_tree = NULL; I64 base_tree_len = 0;
  Bool ours_tree_ok = MergeResolveCommitTree(rbuf, idx_hashes, idx_offsets, idx_count,
                                            ours_head, &ours_tree, &ours_tree_len);
  Bool theirs_tree_ok = MergeResolveCommitTree(rbuf, idx_hashes, idx_offsets, idx_count,
                                              theirs_head, &theirs_tree, &theirs_tree_len);
  Bool base_tree_ok = MergeResolveCommitTree(rbuf, idx_hashes, idx_offsets, idx_count,
                                            base_head, &base_tree, &base_tree_len);
  if (!ours_tree_ok || !theirs_tree_ok) {
    CommPrint(1, "MERGE_ERR tree_not_found\n");
    Free(idx_hashes); Free(idx_offsets);
    return;
  }
  if (!base_tree_ok) base_tree = NULL; // degenerate case, real not-found - handled below like a root

  U32 ours_tcount = GetU32LE(ours_tree, 0);
  U32 theirs_tcount = GetU32LE(theirs_tree, 0);
  U32 base_tcount = 0;
  if (base_tree != NULL) base_tcount = GetU32LE(base_tree, 0);
  I64 max_names = ours_tcount + theirs_tcount + base_tcount + 1;
  U8 *names = MAlloc(max_names*256 + 256);
  I64 name_count = MergeCollectNames(ours_tree, ours_tree_len, theirs_tree, theirs_tree_len,
                                    base_tree, base_tree_len, names);

  U8 *conflict_names = MAlloc(name_count*256 + 256);
  I64 conflict_count = 0;
  U8 merged_tree_content[4096];
  I64 merged_tree_len = 4; // room for entry_count
  I64 merged_entry_count = 0;

  I64 ni;
  I64 ci; // shared scratch index - reused across every sibling block
          // below rather than re-declared in each, avoiding the real,
          // recurring "duplicate member" sibling-block collision
          // (documented since probe 5, hit again in probes 94/98)
  I64 cap;
  for (ni=0; ni<name_count; ni++) {
    U8 *name = names + ni*256;
    I64 name_len = StrLen(name);

    U8 ours_type, ours_hash[64]; U64 ours_entity_id;
    Bool ours_found = TreeFindEntry(ours_tree, ours_tree_len, name, name_len,
                                    &ours_type, ours_hash, &ours_entity_id);
    U8 theirs_type, theirs_hash[64]; U64 theirs_entity_id;
    Bool theirs_found = TreeFindEntry(theirs_tree, theirs_tree_len, name, name_len,
                                      &theirs_type, theirs_hash, &theirs_entity_id);
    U8 base_type, base_hash[64]; U64 base_entity_id;
    Bool base_found2 = FALSE;
    if (base_tree != NULL) {
      base_found2 = TreeFindEntry(base_tree, base_tree_len, name, name_len,
                                  &base_type, base_hash, &base_entity_id);
    }

    // Real, honest scope limit: nested trees aren't merged in this
    // slice (see file header) - reported, not silently skipped.
    Bool any_tree_type = (ours_found && ours_type==OBJ_TREE) ||
                         (theirs_found && theirs_type==OBJ_TREE) ||
                         (base_found2 && base_type==OBJ_TREE);
    // No `continue` in HolyC (probe 5's own documented quirk) - the
    // rest of this per-name decision is nested inside `if
    // (!any_tree_type)` instead of an early skip.
    if (any_tree_type) {
      cap = name_len; if (cap > 254) cap = 254;
      for (ci=0; ci<cap; ci++) conflict_names[conflict_count*256+ci] = name[ci];
      conflict_names[conflict_count*256+cap] = 0;
      conflict_count++;
    } else {
      Bool ours_eq_theirs = (ours_found == theirs_found);
      if (ours_eq_theirs && ours_found) {
        for (ci=0; ci<64; ci++) if (ours_hash[ci] != theirs_hash[ci]) ours_eq_theirs = FALSE;
      }

      Bool ours_eq_base = (ours_found == base_found2);
      if (ours_eq_base && ours_found) {
        for (ci=0; ci<64; ci++) if (ours_hash[ci] != base_hash[ci]) ours_eq_base = FALSE;
      }
      Bool theirs_eq_base = (theirs_found == base_found2);
      if (theirs_eq_base && theirs_found) {
        for (ci=0; ci<64; ci++) if (theirs_hash[ci] != base_hash[ci]) theirs_eq_base = FALSE;
      }

      Bool take_ours = FALSE, take_theirs = FALSE, is_conflict = FALSE;
      if (ours_eq_theirs) {
        take_ours = TRUE; // identical (or both absent) - either works
      } else if (theirs_eq_base) {
        take_ours = TRUE; // only ours changed from base
      } else if (ours_eq_base) {
        take_theirs = TRUE; // only theirs changed from base
      } else {
        is_conflict = TRUE; // both changed, differently
      }

      if (is_conflict) {
        cap = name_len; if (cap > 254) cap = 254;
        for (ci=0; ci<cap; ci++) conflict_names[conflict_count*256+ci] = name[ci];
        conflict_names[conflict_count*256+cap] = 0;
        conflict_count++;
      } else if (take_ours && ours_found) {
        TreeEncodeEntry(merged_tree_content, &merged_tree_len, name, name_len,
                        ours_type, ours_hash, ours_entity_id);
        merged_entry_count++;
      } else if (take_theirs && theirs_found) {
        TreeEncodeEntry(merged_tree_content, &merged_tree_len, name, name_len,
                        theirs_type, theirs_hash, theirs_entity_id);
        merged_entry_count++;
      }
      // else: a real deletion survived cleanly (removed on the
      // winning side, unchanged on the other) - correctly omitted
      // from the merged tree, no entry written.
    }
  }

  if (conflict_count > 0) {
    I64 ci2;
    for (ci2=0; ci2<conflict_count; ci2++) {
      CommPrint(1, "MERGE_CONFLICT %s\n", conflict_names+ci2*256);
    }
    CommPrint(1, "MERGE_ABORTED conflicts=%d\n", conflict_count);
    Free(idx_hashes); Free(idx_offsets); Free(names); Free(conflict_names);
    return;
  }

  PutU32LE(merged_tree_content, 0, merged_entry_count);

  if (rsize > MERGE_ARCHIVE_SANITY_MAX) {
    CommPrint(1, "MERGE_REFUSED archive_absurdly_large size=%d\n", rsize);
    Free(idx_hashes); Free(idx_offsets); Free(names); Free(conflict_names);
    return;
  }
  I64 archive_cap = rsize + MERGE_ARCHIVE_HEADROOM;
  U8 *archive = MAlloc(archive_cap);
  I64 alen;
  I64 i;
  for (i=0; i<rsize-16; i++) archive[16+i] = rbuf[16+i];
  alen = rsize;

  U8 merged_tree_tagged[4096];
  merged_tree_tagged[0] = OBJ_TREE;
  for (i=0; i<merged_tree_len; i++) merged_tree_tagged[1+i] = merged_tree_content[i];
  U8 merged_tree_hash[64];
  B2Hash512Any(merged_tree_tagged, merged_tree_len+1, merged_tree_hash);
  ObjectPut(archive, &alen, OBJ_TREE, merged_tree_content, merged_tree_len);

  U8 merge_parents[128];
  for (i=0; i<64; i++) merge_parents[i] = ours_head[i];
  for (i=0; i<64; i++) merge_parents[64+i] = theirs_head[i];

  U8 msg[256];
  I64 mi = 0;
  U8 *prefix = "merge ";
  I64 pj;
  for (pj=0; prefix[pj]; pj++) msg[mi++] = prefix[pj];
  I64 onl = StrLen(other_path_name);
  for (pj=0; pj<onl; pj++) msg[mi++] = other_path_name[pj];

  U8 commit_content[512];
  I64 clen = 0;
  CommitEncode(commit_content, &clen, merged_tree_hash, merge_parents, 2,
              timestamp, msg, mi, REL_NONE, NULL, 0);
  U8 commit_tagged[512];
  commit_tagged[0] = OBJ_COMMIT;
  for (i=0; i<clen; i++) commit_tagged[1+i] = commit_content[i];
  U8 merge_commit_hash[64];
  B2Hash512Any(commit_tagged, clen+1, merge_commit_hash);
  ObjectPut(archive, &alen, OBJ_COMMIT, commit_content, clen);

  I64 max_possible_objects = alen/73 + 1;
  U8 *final_idx_hashes = MAlloc(max_possible_objects*64 + 64);
  I64 *final_idx_offsets = MAlloc((max_possible_objects+1)*8);
  I64 final_idx_count;
  IndexBuild(archive+16, alen-16, final_idx_hashes, final_idx_offsets, &final_idx_count);
  Free(final_idx_hashes);
  Free(final_idx_offsets);

  HgsWriteHeader(archive, rver, final_idx_count);
  FileWrite(repo_path, archive, alen);

  OpLogAppend(repo_path, ours_head, merge_commit_hash, timestamp);
  CurrentHeadWrite(repo_path, merge_commit_hash);

  CommPrint(1, "MERGE_OK\n");

  Free(archive);
  Free(idx_hashes);
  Free(idx_offsets);
  Free(names);
  Free(conflict_names);
}

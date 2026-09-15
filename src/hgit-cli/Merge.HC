// Merge.HC — `hgit merge <repo> <other_path_name>`: bring another
// declared path's own history into the current path.
//
// ADR 0011's own first real slice, matching ADR 0010's established
// scoping discipline - probe 97 confirmed the object model already
// supports multi-parent commits (zero code changes), probe 98 built
// and verified `FindMergeBase`; this is the real three-way tree merge
// and CLI wiring those two probes were building toward.
//
// Now recurses into nested trees too (ADR 0011's own first documented
// follow-up, experiments/100-merge-nested-trees/): a name where both
// sides' own entries (whichever of ours/theirs/base are present) all
// agree on being a real `OBJ_TREE` is recursed into via
// `MergeTreesRecursive`, reusing the exact same base/ours/theirs
// decision at each level - not a special case, the identical logic
// this file already had for blobs, just applied one directory deeper.
// A same-name entry that's an `OBJ_TREE` on one side and a plain file
// on another (a real kind mismatch) is still a genuine, honestly
// reported conflict - not attempted to auto-resolve.
//
// File mode is now really 3-way merged too (ADR 0015 follow-up,
// `docs/ROADMAP-v1.8.md`'s own "mode-only changes" gap): mode is a
// wholly separate decision from content (a file's bytes and its mode
// can each change independently), computed the same base/ours/theirs
// way for every surviving entity, and a genuine mode-only conflict
// (both sides changed mode, differently) is reported the same as any
// other real conflict - not silently guessed either way. One real,
// honest, narrower limitation: a mode-only change on the side a file
// gets DELETED from is not itself detected as a conflict, since the
// existing edit-vs-delete decision only ever consults content, not
// mode - the file is gone in the merge result either way, so nothing
// is silently lost, but a real chmod-vs-delete race isn't flagged.
//
// Scope of THIS slice (real, testable, honestly limited - see
// docs/adr/0011-merge.md, experiments/99-hgit-merge/README.md, and
// experiments/100-merge-nested-trees/README.md for the full account):
//
//   - No conflict RESOLUTION exists yet - a real conflict of any kind,
//     at any depth, aborts the ENTIRE merge with zero side effects (no
//     commit created, no HEAD moved) - the same non-destructive stance
//     every other real hgit command already takes. A user resolves
//     manually outside hgit (edit the working directory to what it
//     should be) and re-offers - there is no conflict-marker blob
//     format or resolution command yet.
//   - Trivial cases (`theirs` already an ancestor of `ours` - nothing
//     to do; `ours` unchanged since the merge base - a real
//     fast-forward, just moving the current path's HEAD) are detected
//     and handled without a merge commit, matching every real VCS's
//     own standard fast-forward behavior.
//   - A real, honest trade-off from recursing: this project's own
//     established "no side effects on abort" stance still holds for
//     anything that matters (no commit is ever created, HEAD never
//     moves, the real repo file is never touched unless the WHOLE
//     merge succeeds) - but a successful nested subtree discovered
//     before a conflict elsewhere in the tree may already have been
//     written into the in-memory `archive` scratch buffer by the time
//     the conflict is found. That buffer is simply `Free()`'d, never
//     written to the real file, on any abort - so this is invisible to
//     any real caller, not a correctness gap, just documented honestly
//     rather than silently relied upon.
//
// Depends on Canon.HC, Blake2b.HC, Hgs.HC, Object.HC, Tree.HC,
// Commit.HC, Index.HC, MergeBase.HC, Meta.HC, Paths.HC, OpLog.HC,
// Attrs.HC (ADR 0015 follow-up: real mode 3-way merge).

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

// ADR 0015 follow-up: resolves a commit hash to its own OBJ_ATTRS
// content/length, the same commit->attrs_hash->object chain
// `MergeResolveCommitTree` already uses for commit->tree_hash->object.
// Returns FALSE (not a crash) if the commit has no attrs at all
// (`CommitHasAttrs` false - the common case, every mode implicitly 0
// for merge purposes) or if a real reference is broken (Check.HC's
// own job to report, not this file's).
Bool MergeResolveCommitAttrs(U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                             U8 *commit_hash, U8 **out_attrs_content, I64 *out_attrs_len)
{
  I64 c_off_rel;
  if (!IndexLookup(idx_hashes, idx_offsets, idx_count, commit_hash, &c_off_rel)) return FALSE;
  I64 c_off = 16 + c_off_rel;
  if (rbuf[c_off+8] != OBJ_COMMIT) return FALSE;
  U8 *c_content = rbuf + c_off + 9;
  U64 c_rec_len = GetU64LE(rbuf, c_off);
  I64 c_content_len = c_rec_len - 1;
  if (!CommitHasAttrs(c_content, c_content_len)) return FALSE;
  U8 *attrs_hash = CommitAttrsHash(c_content);

  I64 a_off_rel;
  if (!IndexLookup(idx_hashes, idx_offsets, idx_count, attrs_hash, &a_off_rel)) return FALSE;
  I64 a_off = 16 + a_off_rel;
  U64 a_rec_len = GetU64LE(rbuf, a_off);
  *out_attrs_content = rbuf + a_off + 9;
  *out_attrs_len = a_rec_len - 1;
  return TRUE;
}

// Resolves a TREE object's own content/length by its hash - the same
// IndexLookup every other real command uses. Returns FALSE (not a
// crash) if the hash isn't in the index.
Bool MergeResolveTreeByHash(U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                            U8 *hash, U8 **out_content, I64 *out_len)
{
  I64 off_rel;
  if (!IndexLookup(idx_hashes, idx_offsets, idx_count, hash, &off_rel)) return FALSE;
  I64 off = 16 + off_rel;
  U64 rec_len = GetU64LE(rbuf, off);
  *out_content = rbuf + off + 9;
  *out_len = rec_len - 1;
  return TRUE;
}

// Collects every distinct entry NAME across three flat trees (each
// may be NULL - a real, valid case: a subtree that doesn't exist on
// one or more sides) into `names_out` (one 256-byte slot each),
// returning the real count.
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

// The real heart of this file: three-way merges ONE tree level (base
// may be NULL - a real, valid case when a subtree is genuinely new on
// both sides), writing the merged content into
// `merged_tree_content_out`/`*merged_tree_len_out` and returning TRUE
// on success. On any conflict - here, or anywhere in a nested subtree
// - appends every real, honestly path-prefixed conflict name into
// `conflict_names_out`/`*conflict_count_out` and returns FALSE. The
// caller (another call of this same function, or `HgitMerge` at the
// top) aborts the WHOLE merge on FALSE - conflicts are never partial,
// matching ADR 0011's own "any conflict aborts everything" decision,
// now extended to work through nested levels too.
Bool MergeTreesRecursive(U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                         U8 *archive, I64 *alen,
                         U8 *base_tree, I64 base_tree_len,
                         U8 *ours_tree, I64 ours_tree_len,
                         U8 *theirs_tree, I64 theirs_tree_len,
                         U8 *prefix,
                         U8 *merged_tree_content_out, I64 *merged_tree_len_out,
                         U8 *conflict_names_out, I64 *conflict_count_out,
                         // ADR 0015 follow-up: each side's own commit-level
                         // OBJ_ATTRS content (NULL/0 if that commit has none -
                         // every entity's mode then implicitly 0), and ONE
                         // shared, top-level output buffer/count every
                         // recursion depth appends into directly (not
                         // per-directory like merged_tree_content_out - mode
                         // is keyed by entity ID globally, ADR 0015, same
                         // value at every depth, matching Diff.HC's own
                         // precedent for the identical two-sided case).
                         U8 *base_attrs, I64 base_attrs_len,
                         U8 *ours_attrs, I64 ours_attrs_len,
                         U8 *theirs_attrs, I64 theirs_attrs_len,
                         U8 *merged_attrs_content_out, I64 *merged_attrs_len_out)
{
  U32 ours_tcount = 0; if (ours_tree != NULL) ours_tcount = GetU32LE(ours_tree, 0);
  U32 theirs_tcount = 0; if (theirs_tree != NULL) theirs_tcount = GetU32LE(theirs_tree, 0);
  U32 base_tcount = 0; if (base_tree != NULL) base_tcount = GetU32LE(base_tree, 0);
  I64 max_names = ours_tcount + theirs_tcount + base_tcount + 1;
  U8 *names = MAlloc(max_names*256 + 256);
  I64 name_count = MergeCollectNames(ours_tree, ours_tree_len, theirs_tree, theirs_tree_len,
                                    base_tree, base_tree_len, names);

  *merged_tree_len_out = 4; // room for entry_count
  I64 merged_entry_count = 0;
  *conflict_count_out = 0;
  Bool all_ok = TRUE;

  I64 ni;
  I64 ci; // shared scratch index - reused across every sibling block
          // below rather than re-declared in each, avoiding the real,
          // recurring "duplicate member" sibling-block collision
          // (documented since probe 5, hit again in probes 94/98)
  I64 cap;
  for (ni=0; ni<name_count; ni++) {
    U8 *name = names + ni*256;
    I64 name_len = StrLen(name);

    U8 full_name[256];
    I64 fi = 0, fj;
    for (fj=0; prefix[fj]; fj++) full_name[fi++] = prefix[fj];
    I64 fcap = name_len; if (fi+fcap > 254) fcap = 254-fi;
    for (fj=0; fj<fcap; fj++) full_name[fi++] = name[fj];
    full_name[fi] = 0;

    U8 ours_type, ours_hash[64]; U64 ours_entity_id;
    Bool ours_found = FALSE;
    if (ours_tree != NULL) {
      ours_found = TreeFindEntry(ours_tree, ours_tree_len, name, name_len,
                                 &ours_type, ours_hash, &ours_entity_id);
    }
    U8 theirs_type, theirs_hash[64]; U64 theirs_entity_id;
    Bool theirs_found = FALSE;
    if (theirs_tree != NULL) {
      theirs_found = TreeFindEntry(theirs_tree, theirs_tree_len, name, name_len,
                                   &theirs_type, theirs_hash, &theirs_entity_id);
    }
    U8 base_type, base_hash[64]; U64 base_entity_id;
    Bool base_found2 = FALSE;
    if (base_tree != NULL) {
      base_found2 = TreeFindEntry(base_tree, base_tree_len, name, name_len,
                                  &base_type, base_hash, &base_entity_id);
    }

    Bool any_is_tree = (ours_found && ours_type==OBJ_TREE) ||
                       (theirs_found && theirs_type==OBJ_TREE) ||
                       (base_found2 && base_type==OBJ_TREE);
    Bool all_present_are_tree = TRUE;
    if (ours_found && ours_type != OBJ_TREE) all_present_are_tree = FALSE;
    if (theirs_found && theirs_type != OBJ_TREE) all_present_are_tree = FALSE;
    if (base_found2 && base_type != OBJ_TREE) all_present_are_tree = FALSE;

    // No `continue` in HolyC (probe 5's own documented quirk) - each
    // real case below is its own `else if` branch instead of an early
    // skip.
    if (any_is_tree && all_present_are_tree) {
      // A real subtree on at least one side, and every side that has
      // this name at all agrees it's a tree - recurse, reusing this
      // exact same function one directory level deeper.
      U8 *ours_sub = NULL; I64 ours_sub_len = 0;
      U8 *theirs_sub = NULL; I64 theirs_sub_len = 0;
      U8 *base_sub = NULL; I64 base_sub_len = 0;
      if (ours_found) MergeResolveTreeByHash(rbuf, idx_hashes, idx_offsets, idx_count,
                                             ours_hash, &ours_sub, &ours_sub_len);
      if (theirs_found) MergeResolveTreeByHash(rbuf, idx_hashes, idx_offsets, idx_count,
                                               theirs_hash, &theirs_sub, &theirs_sub_len);
      if (base_found2) MergeResolveTreeByHash(rbuf, idx_hashes, idx_offsets, idx_count,
                                              base_hash, &base_sub, &base_sub_len);

      U8 sub_prefix[256];
      I64 spi = 0, spj;
      for (spj=0; full_name[spj]; spj++) sub_prefix[spi++] = full_name[spj];
      sub_prefix[spi++] = '/'; sub_prefix[spi] = 0;

      U8 sub_merged_content[4096];
      I64 sub_merged_len;
      U8 *sub_conflict_names = MAlloc(name_count*256 + 256); // real upper
                                                              // bound: no
                                                              // subtree can
                                                              // have more
                                                              // distinct
                                                              // names than
                                                              // this whole
                                                              // level does
      I64 sub_conflict_count;
      Bool sub_ok = MergeTreesRecursive(rbuf, idx_hashes, idx_offsets, idx_count,
                                        archive, alen,
                                        base_sub, base_sub_len, ours_sub, ours_sub_len,
                                        theirs_sub, theirs_sub_len, sub_prefix,
                                        sub_merged_content, &sub_merged_len,
                                        sub_conflict_names, &sub_conflict_count,
                                        // same shared top-level attrs
                                        // buffers/output at every depth -
                                        // see this function's own signature
                                        // comment.
                                        base_attrs, base_attrs_len,
                                        ours_attrs, ours_attrs_len,
                                        theirs_attrs, theirs_attrs_len,
                                        merged_attrs_content_out, merged_attrs_len_out);
      if (!sub_ok) {
        all_ok = FALSE;
        I64 sci;
        for (sci=0; sci<sub_conflict_count; sci++) {
          I64 scap = StrLen(sub_conflict_names+sci*256); if (scap > 254) scap = 254;
          for (ci=0; ci<scap; ci++) conflict_names_out[(*conflict_count_out)*256+ci] = sub_conflict_names[sci*256+ci];
          conflict_names_out[(*conflict_count_out)*256+scap] = 0;
          (*conflict_count_out)++;
        }
      } else {
        U8 sub_tagged[4096];
        sub_tagged[0] = OBJ_TREE;
        I64 sti;
        for (sti=0; sti<sub_merged_len; sti++) sub_tagged[1+sti] = sub_merged_content[sti];
        U8 sub_hash[64];
        B2Hash512Any(sub_tagged, sub_merged_len+1, sub_hash);
        ObjectPut(archive, alen, OBJ_TREE, sub_merged_content, sub_merged_len);

        U64 sub_entity_id;
        if (ours_found) sub_entity_id = ours_entity_id; else sub_entity_id = theirs_entity_id;
        TreeEncodeEntry(merged_tree_content_out, merged_tree_len_out, name, name_len,
                        OBJ_TREE, sub_hash, sub_entity_id);
        merged_entry_count++;
      }
      Free(sub_conflict_names);
    } else if (any_is_tree) {
      // A real kind mismatch (file on one side, directory on
      // another, at the same name) - a genuine, honest conflict, not
      // guessed at or auto-resolved either way.
      cap = fi; if (cap > 254) cap = 254; // fi = StrLen(full_name) -
                                          // NOT name_len, which is
                                          // just the LOCAL name's own
                                          // length; full_name already
                                          // includes the real path
                                          // prefix (a genuine bug,
                                          // caught by probe 100's own
                                          // real nested-conflict test:
                                          // reported "SubB/" instead
                                          // of "SubB/z.txt" before
                                          // this fix)
      for (ci=0; ci<cap; ci++) conflict_names_out[(*conflict_count_out)*256+ci] = full_name[ci];
      conflict_names_out[(*conflict_count_out)*256+cap] = 0;
      (*conflict_count_out)++;
      all_ok = FALSE;
    } else {
      // The original flat-blob decision (unchanged from probe 99):
      // unchanged-from-base on one side takes the other side's value;
      // changed differently on both sides is a real conflict.
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

      // ADR 0015 follow-up: mode is a wholly separate 3-way decision
      // from content (a file's bytes and its mode can each change
      // independently), computed the same way regardless of which
      // content branch above fires - `AttrsListFindMode` defaults to
      // 0 (plain text, non-executable) when a side has no attrs
      // object at all or doesn't list this entity, matching every
      // other reader of OBJ_ATTRS in this project. One real, honest,
      // documented limitation: a mode-only change on the side a file
      // gets DELETED from is not itself detected as a conflict (only
      // content is consulted for the delete-vs-edit decision above) -
      // not attempted here, a real but narrower gap than the general
      // mode-merge case this closes.
      U8 base_mode = 0, ours_mode = 0, theirs_mode = 0;
      if (base_found2 && base_attrs != NULL) AttrsListFindMode(base_attrs, base_attrs_len, base_entity_id, &base_mode);
      if (ours_found && ours_attrs != NULL) AttrsListFindMode(ours_attrs, ours_attrs_len, ours_entity_id, &ours_mode);
      if (theirs_found && theirs_attrs != NULL) AttrsListFindMode(theirs_attrs, theirs_attrs_len, theirs_entity_id, &theirs_mode);

      Bool mode_ours_eq_theirs = (ours_mode == theirs_mode);
      Bool mode_theirs_eq_base = (theirs_mode == base_mode);
      Bool mode_ours_eq_base = (ours_mode == base_mode);
      U8 winning_mode = 0;
      Bool mode_conflict = FALSE;
      if (mode_ours_eq_theirs) winning_mode = ours_mode;
      else if (mode_theirs_eq_base) winning_mode = ours_mode; // only ours changed mode
      else if (mode_ours_eq_base) winning_mode = theirs_mode; // only theirs changed mode
      else mode_conflict = TRUE; // both changed mode, differently

      if (is_conflict || mode_conflict) {
        cap = fi; if (cap > 254) cap = 254; // fi = StrLen(full_name),
                                            // not name_len - see the
                                            // sibling branch above for
                                            // why this matters
        for (ci=0; ci<cap; ci++) conflict_names_out[(*conflict_count_out)*256+ci] = full_name[ci];
        conflict_names_out[(*conflict_count_out)*256+cap] = 0;
        (*conflict_count_out)++;
        all_ok = FALSE;
      } else if (take_ours && ours_found) {
        TreeEncodeEntry(merged_tree_content_out, merged_tree_len_out, name, name_len,
                        ours_type, ours_hash, ours_entity_id);
        merged_entry_count++;
        if (winning_mode != 0) AttrsListEncode(merged_attrs_content_out, merged_attrs_len_out, ours_entity_id, winning_mode);
      } else if (take_theirs && theirs_found) {
        TreeEncodeEntry(merged_tree_content_out, merged_tree_len_out, name, name_len,
                        theirs_type, theirs_hash, theirs_entity_id);
        merged_entry_count++;
        if (winning_mode != 0) AttrsListEncode(merged_attrs_content_out, merged_attrs_len_out, theirs_entity_id, winning_mode);
      }
      // else: a real deletion survived cleanly (removed on the
      // winning side, unchanged on the other) - correctly omitted
      // from the merged tree, no entry written.
    }
  }

  PutU32LE(merged_tree_content_out, 0, merged_entry_count);
  Free(names);
  return all_ok;
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

  // ADR 0015 follow-up: each side's own commit-level attrs (NULL/0 if
  // that commit predates ADR 0015 or simply has none - every entity's
  // mode then implicitly 0, the same bounds-check-driven backward
  // compatibility `CommitHasAttrs` already provides everywhere else).
  U8 *ours_attrs = NULL; I64 ours_attrs_len = 0;
  U8 *theirs_attrs = NULL; I64 theirs_attrs_len = 0;
  U8 *base_attrs = NULL; I64 base_attrs_len = 0;
  MergeResolveCommitAttrs(rbuf, idx_hashes, idx_offsets, idx_count, ours_head, &ours_attrs, &ours_attrs_len);
  MergeResolveCommitAttrs(rbuf, idx_hashes, idx_offsets, idx_count, theirs_head, &theirs_attrs, &theirs_attrs_len);
  MergeResolveCommitAttrs(rbuf, idx_hashes, idx_offsets, idx_count, base_head, &base_attrs, &base_attrs_len);

  if (rsize > MERGE_ARCHIVE_SANITY_MAX) {
    CommPrint(1, "MERGE_REFUSED archive_absurdly_large size=%d\n", rsize);
    Free(idx_hashes); Free(idx_offsets);
    return;
  }
  // Allocated up front (not gated on the merge outcome) so
  // MergeTreesRecursive can ObjectPut successful nested subtrees as it
  // goes - see this file's own header comment for why this is still
  // consistent with "no side effects on a real conflict": nothing
  // here is ever written to the real repo file unless the WHOLE merge
  // succeeds.
  I64 archive_cap = rsize + MERGE_ARCHIVE_HEADROOM;
  U8 *archive = MAlloc(archive_cap);
  I64 alen;
  I64 i;
  for (i=0; i<rsize-16; i++) archive[16+i] = rbuf[16+i];
  alen = rsize;

  U32 ours_tcount = GetU32LE(ours_tree, 0);
  U32 theirs_tcount = GetU32LE(theirs_tree, 0);
  U32 base_tcount = 0;
  if (base_tree != NULL) base_tcount = GetU32LE(base_tree, 0);
  I64 max_names = ours_tcount + theirs_tcount + base_tcount + 1;
  U8 *conflict_names = MAlloc(max_names*256 + 256);
  I64 conflict_count;
  U8 merged_tree_content[4096];
  I64 merged_tree_len;
  U8 root_prefix[1]; root_prefix[0] = 0;
  // Same real upper-bound reasoning as `conflict_names`/`max_names`
  // above: no merge can produce more distinct entities than the union
  // of all three sides' own trees.
  U8 *merged_attrs_content = MAlloc(max_names*9 + 9);
  I64 merged_attrs_len = 4; // room for the U32 count, filled in below

  Bool ok = MergeTreesRecursive(rbuf, idx_hashes, idx_offsets, idx_count,
                                archive, &alen,
                                base_tree, base_tree_len, ours_tree, ours_tree_len,
                                theirs_tree, theirs_tree_len, root_prefix,
                                merged_tree_content, &merged_tree_len,
                                conflict_names, &conflict_count,
                                base_attrs, base_attrs_len,
                                ours_attrs, ours_attrs_len,
                                theirs_attrs, theirs_attrs_len,
                                merged_attrs_content, &merged_attrs_len);

  if (!ok) {
    I64 ci2;
    for (ci2=0; ci2<conflict_count; ci2++) {
      CommPrint(1, "MERGE_CONFLICT %s\n", conflict_names+ci2*256);
    }
    CommPrint(1, "MERGE_ABORTED conflicts=%d\n", conflict_count);
    Free(idx_hashes); Free(idx_offsets); Free(conflict_names); Free(archive); Free(merged_attrs_content);
    return;
  }

  U8 merged_tree_tagged[4096];
  merged_tree_tagged[0] = OBJ_TREE;
  for (i=0; i<merged_tree_len; i++) merged_tree_tagged[1+i] = merged_tree_content[i];
  U8 merged_tree_hash[64];
  B2Hash512Any(merged_tree_tagged, merged_tree_len+1, merged_tree_hash);
  ObjectPut(archive, &alen, OBJ_TREE, merged_tree_content, merged_tree_len);

  // ADR 0015 follow-up: build the merged OBJ_ATTRS object (if any
  // entity ended up with a non-default mode) the same way Offer.HC
  // does - `merged_attrs_len` is already the real content length
  // (U32 count header + entries), only the count field itself still
  // needs filling in now that every entry is known.
  Bool merge_has_attrs = (merged_attrs_len > 4);
  U8 merged_attrs_hash[64];
  if (merge_has_attrs) {
    PutU32LE(merged_attrs_content, 0, (merged_attrs_len-4)/9);
    U8 *merged_attrs_tagged = MAlloc(merged_attrs_len+1);
    merged_attrs_tagged[0] = OBJ_ATTRS;
    for (i=0; i<merged_attrs_len; i++) merged_attrs_tagged[1+i] = merged_attrs_content[i];
    B2Hash512Any(merged_attrs_tagged, merged_attrs_len+1, merged_attrs_hash);
    Free(merged_attrs_tagged);
    ObjectPut(archive, &alen, OBJ_ATTRS, merged_attrs_content, merged_attrs_len);
  }

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
  // ADR 0015 follow-up: mode is now really 3-way merged (see
  // `MergeTreesRecursive`'s own attrs handling above), so the merge
  // commit carries real attrs whenever any entity ended up with a
  // non-default mode - the "deliberately not carried forward yet" gap
  // this comment used to describe is closed.
  CommitEncode(commit_content, &clen, merged_tree_hash, merge_parents, 2,
              timestamp, msg, mi, REL_NONE, NULL, 0, merge_has_attrs, merged_attrs_hash);
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
  Free(conflict_names);
  Free(merged_attrs_content);
}

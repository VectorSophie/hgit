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
// Conflict now PERSISTS as real repository data instead of vanishing
// on abort (ADR 0016, v1.8.3 - docs/adr/0016-conflict-as-repository-data.md):
// on a real conflict, at any depth, this file still never creates the
// merge commit and never moves HEAD - that part of the original "zero
// side effects" stance is unchanged - but it now WRITES every real
// `OBJ_CONFLICT` evidence object (Conflict.HC) plus Meta.HC's own
// in-progress-merge-state/conflict records, so the conflict survives a
// restart and can be inspected/resolved with `hgit conflicts`/`hgit
// resolve`/`hgit merge continue`/`hgit merge abort` instead of forcing
// a full manual redo. See ADR 0016 for the complete lifecycle; this
// file only implements the detection + evidence-object + persistence
// side of it.
//
// Scope of THIS slice (real, testable, honestly limited - see
// docs/adr/0011-merge.md, experiments/99-hgit-merge/README.md, and
// experiments/100-merge-nested-trees/README.md for the full account):
//
//   - Trivial cases (`theirs` already an ancestor of `ours` - nothing
//     to do; `ours` unchanged since the merge base - a real
//     fast-forward, just moving the current path's HEAD) are detected
//     and handled without a merge commit, matching every real VCS's
//     own standard fast-forward behavior.
//   - A real, honest trade-off from recursing: a successful nested
//     subtree discovered before a conflict elsewhere in the tree may
//     already have been written into the in-memory `archive` scratch
//     buffer by the time the conflict is found - previously this
//     buffer was simply `Free()`'d and never written to the real file
//     on any abort; now (ADR 0016) the whole `archive`, subtrees and
//     conflict evidence together, IS written for real once a conflict
//     is found and persisted, so a stray unreferenced subtree object
//     can genuinely end up in the archive after a conflicted merge -
//     the same already-accepted `CHECK_DANGLING` tradeoff `undo`
//     already leaves behind (ADR 0013), not a new kind of problem.
//
// Depends on Canon.HC, Blake2b.HC, Hgs.HC, Object.HC, Tree.HC,
// Commit.HC, Index.HC, MergeBase.HC, Meta.HC, Paths.HC, OpLog.HC,
// Attrs.HC (ADR 0015 follow-up: real mode 3-way merge), Conflict.HC
// (ADR 0016: OBJ_CONFLICT evidence objects).

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

// --- v1.8.5: rename-aware merge via entity IDs (ADR 0004/0009) ---
//
// offer carries a file's entity ID forward across a detected rename, so
// "same entity ID under a different name than in the merge base" IS the
// evidence of a rename. Rather than teach every branch of
// MergeTreesRecursive about renames, each side's tree is first
// NORMALIZED: an unambiguous renamed blob entry is renamed back to its
// base name in a scratch copy, the existing name-keyed 3-way logic then
// runs unchanged (so rename+edit, mode, conflicts all just work), and
// the merged entry is written out under the new name (map_from/map_to).
// Ambiguity is never guessed at: two sides renaming one entity to
// DIFFERENT names is refused (merge_rename_refused), not silently
// merged into two entries sharing one identity.
// Deliberately out of scope: cross-directory moves (offer's own rename
// detection is within-directory, so no identity evidence survives them),
// and rename-vs-delete (the renamed file simply survives, as before).
I64 merge_rename_refused = 0;

// Number of blob entries in `tree` carrying `entity_id`; name of the
// first match copied to name_out.
I64 MergeFindEntityInTree(U8 *tree, U64 entity_id, U8 *name_out)
{
  I64 matches = 0;
  if (tree == NULL) return 0;
  U32 tc = GetU32LE(tree, 0);
  I64 pos = 4;
  U32 te;
  for (te=0; te<tc; te++) {
    U8 nl = tree[pos]; pos += 1;
    U8 *nm = tree + pos; pos += nl;
    U8 ty = tree[pos]; pos += 1;
    pos += 64;
    U64 eid = GetU64LE(tree, pos); pos += 8;
    if (ty == OBJ_BLOB && eid == entity_id) {
      if (matches == 0) {
        I64 ci;
        for (ci=0; ci<nl; ci++) name_out[ci] = nm[ci];
        name_out[nl] = 0;
      }
      matches++;
    }
  }
  return matches;
}

// Returns a new (MAlloc'd) copy of `side_tree` with unambiguous renames
// (relative to `base_tree`) undone, or NULL if none applied. `map_from`/
// `map_to` (256-byte slots) accumulate base-name -> new-name pairs.
U8 *MergeNormalizeSide(U8 *base_tree, I64 base_len, U8 *side_tree, I64 side_len,
                       U8 *other_tree, I64 other_len,
                       U8 *map_from, U8 *map_to, I64 *map_count, I64 *out_len)
{
  if (base_tree == NULL || side_tree == NULL) return NULL;
  U32 sc = GetU32LE(side_tree, 0);
  U8 *buf = MAlloc(side_len + sc*256 + 16);
  I64 blen = 4;
  U32 kept = 0;
  Bool applied = FALSE;
  I64 pos = 4;
  U32 te;
  for (te=0; te<sc; te++) {
    U8 nl = side_tree[pos]; pos += 1;
    U8 *nm = side_tree + pos; pos += nl;
    U8 ty = side_tree[pos]; pos += 1;
    U8 *hs = side_tree + pos; pos += 64;
    U64 eid = GetU64LE(side_tree, pos); pos += 8;

    U8 use_name[256];
    I64 use_len = nl;
    I64 ui;
    for (ui=0; ui<nl; ui++) use_name[ui] = nm[ui];
    use_name[nl] = 0;

    if (ty == OBJ_BLOB) {
      U8 t1; U8 h1[64]; U64 e1;
      Bool in_base = TreeFindEntry(base_tree, base_len, nm, nl, &t1, h1, &e1);
      if (!in_base) {
        U8 bname[256];
        I64 bmatch = MergeFindEntityInTree(base_tree, eid, bname);
        U8 sname[256];
        I64 smatch = MergeFindEntityInTree(side_tree, eid, sname);
        if (bmatch == 1 && smatch == 1) {
          I64 bnl = StrLen(bname);
          U8 t2; U8 h2[64]; U64 e2;
          Bool side_has_bname = TreeFindEntry(side_tree, side_len, bname, bnl, &t2, h2, &e2);
          if (!side_has_bname) {
            Bool other_has_bname = FALSE;
            if (other_tree != NULL) other_has_bname = TreeFindEntry(other_tree, other_len, bname, bnl, &t2, h2, &e2);
            Bool ok_to_norm = other_has_bname;
            if (!other_has_bname) {
              U8 oname[256];
              I64 omatch = MergeFindEntityInTree(other_tree, eid, oname);
              if (omatch == 1) {
                if (StrCmp(oname, use_name) == 0) ok_to_norm = TRUE; // same rename on both sides
                else {
                  CommPrint(1, "MERGE_RENAME_RENAME %s\n", bname);
                  merge_rename_refused = 1;
                }
              }
            }
            if (ok_to_norm) {
              I64 bi;
              for (bi=0; bi<bnl; bi++) use_name[bi] = bname[bi];
              use_name[bnl] = 0;
              use_len = bnl;
              applied = TRUE;
              Bool already = FALSE;
              I64 mi;
              for (mi=0; mi<*map_count; mi++) if (StrCmp(map_from+mi*256, bname) == 0) already = TRUE;
              if (!already) {
                for (bi=0; bi<=bnl; bi++) map_from[(*map_count)*256+bi] = bname[bi];
                for (bi=0; bi<nl; bi++) map_to[(*map_count)*256+bi] = nm[bi];
                map_to[(*map_count)*256+nl] = 0;
                (*map_count)++;
              }
            }
          }
        }
      }
    }
    TreeEncodeEntry(buf, &blen, use_name, use_len, ty, hs, eid);
    kept++;
  }
  if (!applied) { Free(buf); return NULL; }
  PutU32LE(buf, 0, kept);
  *out_len = blen;
  return buf;
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
                         // ADR 0016: conflict_hashes_out is a parallel
                         // array to conflict_names_out (64 bytes per
                         // entry, same index) - the real OBJ_CONFLICT
                         // object hash for that conflict, already
                         // written into `archive` by the time this
                         // returns. Names alone (the pre-ADR-0016
                         // shape) were only ever for CLI display; the
                         // hash is what Meta.HC's conflict records
                         // actually reference.
                         U8 *conflict_names_out, U8 *conflict_hashes_out, I64 *conflict_count_out,
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
                         U8 *merged_attrs_content_out, I64 *merged_attrs_len_out,
                         // ADR 0016, `hgit merge continue`'s own real
                         // mechanism: an optional resolution table
                         // (resolution_count==0 for a normal first
                         // attempt - every other caller passes 0/NULL/
                         // NULL). Parallel arrays, 64 bytes each:
                         // resolution_conflict_hashes[i] is a conflict
                         // object hash already resolved (Meta.HC),
                         // resolution_hashes[i] is what it resolved TO
                         // (ours_hash or theirs_hash, whichever side
                         // `hgit resolve` picked). Since OBJ_CONFLICT
                         // is content-addressed, re-running this exact
                         // same algorithm against the same
                         // ours_head/theirs_head/base_head reproduces
                         // the IDENTICAL conflict hash at the same
                         // site - so a site whose freshly-recomputed
                         // conflict hash appears in this table is now
                         // resolved: it takes the matching side's
                         // entry (type+hash+entity_id+mode together,
                         // not content and mode separately) instead of
                         // recording a conflict, exactly like the
                         // ordinary take_ours/take_theirs path already
                         // does for a non-conflicting entry.
                         U8 *resolution_conflict_hashes, U8 *resolution_hashes, I64 resolution_count)
{
  U32 ours_tcount = 0; if (ours_tree != NULL) ours_tcount = GetU32LE(ours_tree, 0);
  U32 theirs_tcount = 0; if (theirs_tree != NULL) theirs_tcount = GetU32LE(theirs_tree, 0);
  U32 base_tcount = 0; if (base_tree != NULL) base_tcount = GetU32LE(base_tree, 0);

  // v1.8.5: undo unambiguous renames on each side (see the helpers above)
  // so the name-keyed logic below sees base names; written back under the
  // new name via out_name.
  U8 *map_from = MAlloc((ours_tcount+theirs_tcount+1)*256 + 256);
  U8 *map_to = MAlloc((ours_tcount+theirs_tcount+1)*256 + 256);
  I64 map_count = 0;
  I64 ours_norm_len = 0, theirs_norm_len = 0;
  U8 *ours_norm = MergeNormalizeSide(base_tree, base_tree_len, ours_tree, ours_tree_len,
                                     theirs_tree, theirs_tree_len, map_from, map_to, &map_count, &ours_norm_len);
  U8 *theirs_norm = MergeNormalizeSide(base_tree, base_tree_len, theirs_tree, theirs_tree_len,
                                       ours_tree, ours_tree_len, map_from, map_to, &map_count, &theirs_norm_len);
  if (ours_norm != NULL) { ours_tree = ours_norm; ours_tree_len = ours_norm_len; }
  if (theirs_norm != NULL) { theirs_tree = theirs_norm; theirs_tree_len = theirs_norm_len; }

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
    U8 *out_name = name;
    I64 out_name_len = name_len;
    I64 mpi;
    for (mpi=0; mpi<map_count; mpi++) {
      if (StrCmp(map_from+mpi*256, name) == 0) { out_name = map_to+mpi*256; out_name_len = StrLen(out_name); }
    }

    if (out_name != name) CommPrint(1, "MERGE_AUTO renamed %s%s -> %s\n", prefix, name, out_name);

    U8 full_name[256];
    I64 fi = 0, fj;
    for (fj=0; prefix[fj]; fj++) full_name[fi++] = prefix[fj];
    I64 fcap = out_name_len; if (fi+fcap > 254) fcap = 254-fi;
    for (fj=0; fj<fcap; fj++) full_name[fi++] = out_name[fj];
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
      U8 *sub_conflict_hashes = MAlloc(name_count*64 + 64); // ADR 0016:
                                                             // parallel to
                                                             // sub_conflict_names
      I64 sub_conflict_count;
      Bool sub_ok = MergeTreesRecursive(rbuf, idx_hashes, idx_offsets, idx_count,
                                        archive, alen,
                                        base_sub, base_sub_len, ours_sub, ours_sub_len,
                                        theirs_sub, theirs_sub_len, sub_prefix,
                                        sub_merged_content, &sub_merged_len,
                                        sub_conflict_names, sub_conflict_hashes, &sub_conflict_count,
                                        // same shared top-level attrs
                                        // buffers/output at every depth -
                                        // see this function's own signature
                                        // comment.
                                        base_attrs, base_attrs_len,
                                        ours_attrs, ours_attrs_len,
                                        theirs_attrs, theirs_attrs_len,
                                        merged_attrs_content_out, merged_attrs_len_out,
                                        resolution_conflict_hashes, resolution_hashes, resolution_count);
      if (!sub_ok) {
        all_ok = FALSE;
        I64 sci;
        for (sci=0; sci<sub_conflict_count; sci++) {
          I64 scap = StrLen(sub_conflict_names+sci*256); if (scap > 254) scap = 254;
          for (ci=0; ci<scap; ci++) conflict_names_out[(*conflict_count_out)*256+ci] = sub_conflict_names[sci*256+ci];
          conflict_names_out[(*conflict_count_out)*256+scap] = 0;
          for (ci=0; ci<64; ci++) conflict_hashes_out[(*conflict_count_out)*64+ci] = sub_conflict_hashes[sci*64+ci];
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
        TreeEncodeEntry(merged_tree_content_out, merged_tree_len_out, out_name, out_name_len,
                        OBJ_TREE, sub_hash, sub_entity_id);
        merged_entry_count++;
      }
      Free(sub_conflict_names);
      Free(sub_conflict_hashes);
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
      // ADR 0016: this conflict's real, persistent evidence object,
      // built FIRST (before deciding conflict vs. already-resolved) -
      // OBJ_CONFLICT is content-addressed, so this is the same real
      // lookup key `hgit resolve` recorded against, on a normal first
      // attempt or a `merge continue` re-walk alike. Mode is left 0
      // for every side here - a kind mismatch (tree vs blob) makes
      // "mode" not meaningfully comparable the way it is for two
      // blobs, and nothing upstream computed a mode for this branch
      // anyway; a real, deliberately narrower scope than the
      // content/mode branch below, not an oversight.
      Bool kc_present[3]; U8 kc_type[3]; U8 kc_mode[3]; U8 kc_hash[192];
      kc_present[0] = base_found2; kc_present[1] = ours_found; kc_present[2] = theirs_found;
      kc_mode[0] = 0; kc_mode[1] = 0; kc_mode[2] = 0;
      if (base_found2) { kc_type[0] = base_type; for (ci=0; ci<64; ci++) kc_hash[0*64+ci] = base_hash[ci]; }
      if (ours_found) { kc_type[1] = ours_type; for (ci=0; ci<64; ci++) kc_hash[1*64+ci] = ours_hash[ci]; }
      if (theirs_found) { kc_type[2] = theirs_type; for (ci=0; ci<64; ci++) kc_hash[2*64+ci] = theirs_hash[ci]; }
      U64 kc_entity_id;
      if (ours_found) kc_entity_id = ours_entity_id;
      else if (theirs_found) kc_entity_id = theirs_entity_id;
      else kc_entity_id = base_entity_id;

      U8 kc_content[512];
      I64 kc_len = 0;
      ConflictEncode(kc_content, &kc_len, CONFLICT_KIND_TYPE, kc_entity_id, full_name, cap,
                     kc_present, kc_type, kc_mode, kc_hash);
      U8 kc_tagged[513];
      kc_tagged[0] = OBJ_CONFLICT;
      for (ci=0; ci<kc_len; ci++) kc_tagged[1+ci] = kc_content[ci];
      U8 kc_object_hash[64];
      B2Hash512Any(kc_tagged, kc_len+1, kc_object_hash);

      // `hgit merge continue`'s own real mechanism: a matching entry
      // in the resolution table means this exact conflict was already
      // resolved - take the matching side's entry whole (type+hash+
      // entity_id together) instead of recording a conflict.
      Bool kc_resolved = FALSE;
      U8 kc_resolution_hash[64];
      I64 kri;
      for (kri=0; kri<resolution_count; kri++) {
        Bool kc_same = TRUE;
        I64 krj;
        for (krj=0; krj<64; krj++) if (resolution_conflict_hashes[kri*64+krj] != kc_object_hash[krj]) kc_same = FALSE;
        if (kc_same) { kc_resolved = TRUE; for (krj=0; krj<64; krj++) kc_resolution_hash[krj] = resolution_hashes[kri*64+krj]; }
      }

      if (kc_resolved) {
        // All-zero resolution hash = resolved to "absent" (v1.8.4):
        // the entry is simply omitted, a real deletion.
        Bool kc_zero = TRUE;
        I64 kzi; for (kzi=0; kzi<64; kzi++) if (kc_resolution_hash[kzi] != 0) kc_zero = FALSE;
        Bool kc_use_ours = ours_found;
        if (kc_use_ours) { I64 krj2; for (krj2=0; krj2<64; krj2++) if (ours_hash[krj2] != kc_resolution_hash[krj2]) kc_use_ours = FALSE; }
        if (kc_zero) {
        } else if (kc_use_ours) {
          TreeEncodeEntry(merged_tree_content_out, merged_tree_len_out, out_name, out_name_len, ours_type, ours_hash, ours_entity_id);
          merged_entry_count++;
        } else {
          TreeEncodeEntry(merged_tree_content_out, merged_tree_len_out, out_name, out_name_len, theirs_type, theirs_hash, theirs_entity_id);
          merged_entry_count++;
        }
      } else {
        ObjectPut(archive, alen, OBJ_CONFLICT, kc_content, kc_len);
        for (ci=0; ci<cap; ci++) conflict_names_out[(*conflict_count_out)*256+ci] = full_name[ci];
        conflict_names_out[(*conflict_count_out)*256+cap] = 0;
        for (ci=0; ci<64; ci++) conflict_hashes_out[(*conflict_count_out)*64+ci] = kc_object_hash[ci];
        (*conflict_count_out)++;
        all_ok = FALSE;
      }
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

        // ADR 0016: this conflict's real, persistent evidence object -
        // content and/or mode, whichever combination of is_conflict/
        // mode_conflict actually fired (a real file can conflict on
        // both at once, per the ADR's own conflict_kind bitmask). Same
        // "build first, then check resolution" order as the kind-
        // mismatch branch above - see its own comment for why.
        U8 cc_kind = 0;
        if (is_conflict) cc_kind = cc_kind | CONFLICT_KIND_CONTENT;
        if (mode_conflict) cc_kind = cc_kind | CONFLICT_KIND_MODE;

        Bool cc_present[3]; U8 cc_type[3]; U8 cc_mode[3]; U8 cc_hash[192];
        cc_present[0] = base_found2; cc_present[1] = ours_found; cc_present[2] = theirs_found;
        if (base_found2) { cc_type[0] = OBJ_BLOB; cc_mode[0] = base_mode; for (ci=0; ci<64; ci++) cc_hash[0*64+ci] = base_hash[ci]; }
        if (ours_found) { cc_type[1] = OBJ_BLOB; cc_mode[1] = ours_mode; for (ci=0; ci<64; ci++) cc_hash[1*64+ci] = ours_hash[ci]; }
        if (theirs_found) { cc_type[2] = OBJ_BLOB; cc_mode[2] = theirs_mode; for (ci=0; ci<64; ci++) cc_hash[2*64+ci] = theirs_hash[ci]; }
        U64 cc_entity_id;
        if (ours_found) cc_entity_id = ours_entity_id;
        else if (theirs_found) cc_entity_id = theirs_entity_id;
        else cc_entity_id = base_entity_id;

        U8 cc_content[512];
        I64 cc_len = 0;
        ConflictEncode(cc_content, &cc_len, cc_kind, cc_entity_id, full_name, cap,
                       cc_present, cc_type, cc_mode, cc_hash);
        U8 cc_tagged[513];
        cc_tagged[0] = OBJ_CONFLICT;
        for (ci=0; ci<cc_len; ci++) cc_tagged[1+ci] = cc_content[ci];
        U8 cc_object_hash[64];
        B2Hash512Any(cc_tagged, cc_len+1, cc_object_hash);

        Bool cc_resolved = FALSE;
        U8 cc_resolution_hash[64];
        I64 cri;
        for (cri=0; cri<resolution_count; cri++) {
          Bool cc_same = TRUE;
          I64 crj;
          for (crj=0; crj<64; crj++) if (resolution_conflict_hashes[cri*64+crj] != cc_object_hash[crj]) cc_same = FALSE;
          if (cc_same) { cc_resolved = TRUE; for (crj=0; crj<64; crj++) cc_resolution_hash[crj] = resolution_hashes[cri*64+crj]; }
        }

        if (cc_resolved) {
          Bool cc_zero = TRUE;
          I64 czi; for (czi=0; czi<64; czi++) if (cc_resolution_hash[czi] != 0) cc_zero = FALSE;
          Bool cc_use_ours = ours_found;
          if (cc_use_ours) { I64 crj2; for (crj2=0; crj2<64; crj2++) if (ours_hash[crj2] != cc_resolution_hash[crj2]) cc_use_ours = FALSE; }
          if (cc_zero) {
          } else if (cc_use_ours) {
            TreeEncodeEntry(merged_tree_content_out, merged_tree_len_out, out_name, out_name_len, ours_type, ours_hash, ours_entity_id);
            merged_entry_count++;
            if (ours_mode != 0) AttrsListEncode(merged_attrs_content_out, merged_attrs_len_out, ours_entity_id, ours_mode);
          } else {
            TreeEncodeEntry(merged_tree_content_out, merged_tree_len_out, out_name, out_name_len, theirs_type, theirs_hash, theirs_entity_id);
            merged_entry_count++;
            if (theirs_mode != 0) AttrsListEncode(merged_attrs_content_out, merged_attrs_len_out, theirs_entity_id, theirs_mode);
          }
        } else {
          ObjectPut(archive, alen, OBJ_CONFLICT, cc_content, cc_len);
          for (ci=0; ci<cap; ci++) conflict_names_out[(*conflict_count_out)*256+ci] = full_name[ci];
          conflict_names_out[(*conflict_count_out)*256+cap] = 0;
          for (ci=0; ci<64; ci++) conflict_hashes_out[(*conflict_count_out)*64+ci] = cc_object_hash[ci];
          (*conflict_count_out)++;
          all_ok = FALSE;
        }
      } else if (take_ours && ours_found) {
        TreeEncodeEntry(merged_tree_content_out, merged_tree_len_out, out_name, out_name_len,
                        ours_type, ours_hash, ours_entity_id);
        merged_entry_count++;
        if (winning_mode != 0) AttrsListEncode(merged_attrs_content_out, merged_attrs_len_out, ours_entity_id, winning_mode);
      } else if (take_theirs && theirs_found) {
        CommPrint(1, "MERGE_AUTO took-theirs %s\n", full_name);
        TreeEncodeEntry(merged_tree_content_out, merged_tree_len_out, out_name, out_name_len,
                        theirs_type, theirs_hash, theirs_entity_id);
        merged_entry_count++;
        if (winning_mode != 0) AttrsListEncode(merged_attrs_content_out, merged_attrs_len_out, theirs_entity_id, winning_mode);
      } else {
        CommPrint(1, "MERGE_AUTO deleted %s\n", full_name);
      }
      // else: a real deletion survived cleanly (removed on the
      // winning side, unchanged on the other) - correctly omitted
      // from the merged tree, no entry written.
    }
  }

  PutU32LE(merged_tree_content_out, 0, merged_entry_count);
  Free(names);
  Free(map_from);
  Free(map_to);
  if (ours_norm != NULL) Free(ours_norm);
  if (theirs_norm != NULL) Free(theirs_norm);
  return all_ok;
}

// The real "write the merge commit" tail, shared between a normal
// conflict-free `HgitMerge` and `HgitMergeContinue` (ADR 0016) once
// every conflict is resolved - identical logic either way, just
// pulled out so it isn't duplicated. Takes ownership of `archive`
// (frees it here); `merged_attrs_content` stays the caller's, freed
// there like every other caller-owned buffer in this file.
U0 MergeFinishSuccess(U8 *repo_path, U8 *archive, I64 alen, U16 rver,
                      U8 *ours_head, U8 *theirs_head,
                      U8 *merged_tree_content, I64 merged_tree_len,
                      U8 *merged_attrs_content, I64 merged_attrs_len,
                      U8 *other_path_name, U8 *msg_suffix, U64 timestamp)
{
  I64 i;
  U8 merged_tree_tagged[4096];
  merged_tree_tagged[0] = OBJ_TREE;
  for (i=0; i<merged_tree_len; i++) merged_tree_tagged[1+i] = merged_tree_content[i];
  U8 merged_tree_hash[64];
  B2Hash512Any(merged_tree_tagged, merged_tree_len+1, merged_tree_hash);
  ObjectPut(archive, &alen, OBJ_TREE, merged_tree_content, merged_tree_len);

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
  // v1.8.4: resolution provenance - which conflicts were resolved and
  // how, inspectable afterward via history/see (message capped, 255).
  for (pj=0; msg_suffix[pj] && mi<254; pj++) msg[mi++] = msg_suffix[pj];

  U8 commit_content[512];
  I64 clen = 0;
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

  // ADR 0016: a real conflict now persists as in-progress merge
  // state (Meta.HC), which starting a SECOND overlapping merge on
  // the same path would silently clobber or orphan - refuse, same
  // honest-refusal stance every other real hgit command already
  // takes rather than guessing.
  U8 mc_cur_name[HGIT_MAX_PATH_NAME];
  CurrentPathGet(repo_path, mc_cur_name);
  if (MetaMergeStateExists(repo_path, mc_cur_name)) {
    CommPrint(1, "MERGE_ERR conflicts_already_in_progress - resolve them ('hgit conflicts'/'hgit resolve') then 'hgit merge continue', or 'hgit merge abort' first\n");
    return;
  }

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
  U8 *conflict_hashes = MAlloc(max_names*64 + 64); // ADR 0016: parallel to conflict_names
  I64 conflict_count;
  U8 merged_tree_content[4096];
  I64 merged_tree_len;
  U8 root_prefix[1]; root_prefix[0] = 0;
  // Same real upper-bound reasoning as `conflict_names`/`max_names`
  // above: no merge can produce more distinct entities than the union
  // of all three sides' own trees.
  U8 *merged_attrs_content = MAlloc(max_names*9 + 9);
  I64 merged_attrs_len = 4; // room for the U32 count, filled in below

  merge_rename_refused = 0;
  Bool ok = MergeTreesRecursive(rbuf, idx_hashes, idx_offsets, idx_count,
                                archive, &alen,
                                base_tree, base_tree_len, ours_tree, ours_tree_len,
                                theirs_tree, theirs_tree_len, root_prefix,
                                merged_tree_content, &merged_tree_len,
                                conflict_names, conflict_hashes, &conflict_count,
                                base_attrs, base_attrs_len,
                                ours_attrs, ours_attrs_len,
                                theirs_attrs, theirs_attrs_len,
                                merged_attrs_content, &merged_attrs_len,
                                NULL, NULL, 0); // no resolutions yet - a fresh merge attempt

  if (merge_rename_refused) {
    CommPrint(1, "MERGE_REFUSED ambiguous_rename_rename - both sides renamed one file differently; nothing changed\n");
    Free(idx_hashes); Free(idx_offsets); Free(conflict_names); Free(conflict_hashes); Free(archive); Free(merged_attrs_content);
    return;
  }

  if (!ok) {
    // ADR 0016: a real conflict no longer means "nothing persisted" -
    // every OBJ_CONFLICT object MergeTreesRecursive already built into
    // `archive` above gets written for real (the object tree/commit
    // itself is still untouched - HEAD doesn't move, no merge commit
    // exists - only the conflict evidence and in-progress merge state
    // are new), then Meta.HC records the in-progress merge so `hgit
    // conflicts`/`hgit resolve`/`hgit merge continue`/`hgit merge
    // abort` can pick it up later, even across a restart.
    I64 fail_max_objects = alen/73 + 1;
    U8 *fail_idx_hashes = MAlloc(fail_max_objects*64 + 64);
    I64 *fail_idx_offsets = MAlloc((fail_max_objects+1)*8);
    I64 fail_idx_count;
    IndexBuild(archive+16, alen-16, fail_idx_hashes, fail_idx_offsets, &fail_idx_count);
    HgsWriteHeader(archive, rver, fail_idx_count);
    FileWrite(repo_path, archive, alen);
    Free(fail_idx_hashes); Free(fail_idx_offsets);

    MetaMergeStateWrite(repo_path, mc_cur_name, ours_head, theirs_head, other_path_name);
    I64 ci2;
    for (ci2=0; ci2<conflict_count; ci2++) {
      CommPrint(1, "MERGE_CONFLICT %s\n", conflict_names+ci2*256);
      MetaConflictAppend(repo_path, mc_cur_name, conflict_hashes+ci2*64);
    }
    CommPrint(1, "MERGE_ABORTED conflicts=%d\n", conflict_count);
    CommPrint(1, "MERGE_CONFLICTS_PERSISTED - see 'hgit conflicts', 'hgit resolve', 'hgit merge continue'/'hgit merge abort'\n");
    Free(idx_hashes); Free(idx_offsets); Free(conflict_names); Free(conflict_hashes); Free(archive); Free(merged_attrs_content);
    return;
  }

  // ADR 0015 follow-up (mode carried in the merge commit) and ADR
  // 0016 (this tail shared with `HgitMergeContinue`) both live in
  // `MergeFinishSuccess` now - see its own comment.
  MergeFinishSuccess(repo_path, archive, alen, rver, ours_head, theirs_head,
                     merged_tree_content, merged_tree_len,
                     merged_attrs_content, merged_attrs_len,
                     other_path_name, "", timestamp);

  Free(idx_hashes);
  Free(idx_offsets);
  Free(conflict_names);
  Free(conflict_hashes);
  Free(merged_attrs_content);
}

// --- ADR 0016 lifecycle commands: conflicts / resolve / merge continue / merge abort ---

// `hgit conflicts <repo>`: lists every real conflict record (resolved
// and unresolved both, ADR 0016's own "resolving doesn't erase
// evidence" requirement) for the current path's in-progress merge, if
// any. Numbered 0-based in real append order - that same number is
// what `hgit resolve` takes as its own conflict selector, a real,
// simple CLI convenience layered on top of `MetaConflictSetResolved`'s
// own hash-keyed identification underneath (see Meta.HC's own comment
// for why the storage itself is hash-keyed, not position-keyed).
U0 HgitConflicts(U8 *repo_path)
{
  U8 cur_name[HGIT_MAX_PATH_NAME];
  CurrentPathGet(repo_path, cur_name);
  if (!MetaMergeStateExists(repo_path, cur_name)) {
    CommPrint(1, "CONFLICTS_NONE\n");
    return;
  }

  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  if (rbuf == NULL) { CommPrint(1, "MERGE_ERR not_a_repository\n"); return; }
  U16 rver;
  U64 rcount;
  HgsReadHeader(rbuf, &rver, &rcount);
  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  I64 count = MetaConflictCount(repo_path, cur_name);
  CommPrint(1, "CONFLICTS_COUNT %d\n", count);
  I64 idx;
  for (idx=0; idx<count; idx++) {
    U8 conflict_hash[64], resolved, resolution_hash[64];
    MetaConflictGetAt(repo_path, cur_name, idx, conflict_hash, &resolved, resolution_hash);

    I64 off_rel;
    U8 path_out[256];
    I64 path_len;
    U8 conflict_kind = 0;
    Bool cf_ok = FALSE;
    if (IndexLookup(idx_hashes, idx_offsets, idx_count, conflict_hash, &off_rel)) {
      I64 off = 16 + off_rel;
      U8 *content = rbuf + off + 9;
      U64 entity_id;
      Bool present[3]; U8 type[3], mode[3], hash[192];
      U64 cf_rec = GetU64LE(rbuf, off);
      if (ConflictContentValid(content, cf_rec - 1)) {
        cf_ok = TRUE;
        ConflictDecode(content, &conflict_kind, &entity_id, path_out, &path_len,
                       present, type, mode, hash);
      } else {
        path_out[0] = 0;
      }
    } else {
      path_out[0] = 0; // real, honest fallback if the object went missing - Check.HC's own job to flag
    }

    U8 *state_word = "UNRESOLVED";
    if (resolved) state_word = "RESOLVED";
    CommPrint(1, "CONFLICT %d %s kind=%d %s\n", idx, state_word, conflict_kind, path_out);
    if (cf_ok && IndexLookup(idx_hashes, idx_offsets, idx_count, conflict_hash, &off_rel)) {
      // v1.8.4: base/ours/theirs evidence, first 16 hex chars of each hash.
      I64 doff = 16 + off_rel;
      U8 dkind; U64 dent; U8 dpath[256]; I64 dplen;
      Bool dpres[3]; U8 dtype[3], dmode[3], dhash[192];
      ConflictDecode(rbuf + doff + 9, &dkind, &dent, dpath, &dplen, dpres, dtype, dmode, dhash);
      U8 *side_names[3];
      side_names[0] = "base"; side_names[1] = "ours"; side_names[2] = "theirs";
      I64 ds;
      for (ds=0; ds<3; ds++) {
        if (dpres[ds]) {
          U8 dhex[129];
          HashToHex(dhash+ds*64, dhex);
          dhex[16] = 0;
          CommPrint(1, "  %s type=%d mode=%d hash=%s\n", side_names[ds], dtype[ds], dmode[ds], dhex);
        } else {
          CommPrint(1, "  %s ABSENT\n", side_names[ds]);
        }
      }
      if (resolved) {
        Bool rzero = TRUE;
        I64 rzi; for (rzi=0; rzi<64; rzi++) if (resolution_hash[rzi] != 0) rzero = FALSE;
        U8 *rword = "custom";
        if (rzero) rword = "deleted";
        else {
          Bool rours = dpres[1];
          if (rours) for (rzi=0; rzi<64; rzi++) if (dhash[64+rzi] != resolution_hash[rzi]) rours = FALSE;
          if (rours) rword = "take-ours"; else rword = "take-theirs";
        }
        CommPrint(1, "  resolved: %s\n", rword);
      }
    }
  }

  Free(idx_hashes);
  Free(idx_offsets);
}

// `hgit resolve <repo> <conflict-index> take-ours|take-theirs`: marks
// one conflict resolved (ADR 0016's own deliberately narrow first
// slice - no arbitrary replacement content yet). `which` must be
// exactly "take-ours" or "take-theirs".
U0 HgitResolve(U8 *repo_path, I64 conflict_index, U8 *which)
{
  U8 cur_name[HGIT_MAX_PATH_NAME];
  CurrentPathGet(repo_path, cur_name);
  if (!MetaMergeStateExists(repo_path, cur_name)) {
    CommPrint(1, "RESOLVE_ERR no_merge_in_progress\n");
    return;
  }

  U8 conflict_hash[64], resolved, old_resolution_hash[64];
  if (!MetaConflictGetAt(repo_path, cur_name, conflict_index, conflict_hash, &resolved, old_resolution_hash)) {
    CommPrint(1, "RESOLVE_ERR conflict_not_found %d\n", conflict_index);
    return;
  }

  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  if (rbuf == NULL) { CommPrint(1, "MERGE_ERR not_a_repository\n"); return; }
  U16 rver;
  U64 rcount;
  HgsReadHeader(rbuf, &rver, &rcount);
  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  I64 off_rel;
  if (!IndexLookup(idx_hashes, idx_offsets, idx_count, conflict_hash, &off_rel)) {
    CommPrint(1, "RESOLVE_ERR conflict_object_missing\n");
    Free(idx_hashes); Free(idx_offsets);
    return;
  }
  I64 off = 16 + off_rel;
  U8 *content = rbuf + off + 9;
  U8 conflict_kind;
  U64 entity_id;
  U8 path_out[256];
  I64 path_len;
  Bool present[3]; U8 type[3], mode[3], hash[192];
  U64 rs_rec = GetU64LE(rbuf, off);
  if (!ConflictContentValid(content, rs_rec - 1)) {
    CommPrint(1, "RESOLVE_ERR conflict_object_malformed - see hgit check; 'hgit merge abort' recovers\n");
    Free(idx_hashes); Free(idx_offsets);
    return;
  }
  ConflictDecode(content, &conflict_kind, &entity_id, path_out, &path_len,
                 present, type, mode, hash);

  Bool want_ours = (StrCmp(which, "take-ours") == 0);
  Bool want_theirs = (StrCmp(which, "take-theirs") == 0);
  if (!want_ours && !want_theirs) {
    CommPrint(1, "RESOLVE_ERR unknown_selector %s (use take-ours or take-theirs)\n", which);
    Free(idx_hashes); Free(idx_offsets);
    return;
  }
  I64 side = 1; if (want_theirs) side = 2; // 0=base,1=ours,2=theirs, ADR 0016's own fixed order
  // An absent side (a deletion) is a valid thing to resolve TO (v1.8.4):
  // recorded as an all-zero hash, which `merge continue` reads as "omit
  // this entry".
  U8 resolution_hash[64];
  I64 ri;
  for (ri=0; ri<64; ri++) resolution_hash[ri] = 0;
  if (present[side]) for (ri=0; ri<64; ri++) resolution_hash[ri] = hash[side*64+ri];

  MetaConflictSetResolved(repo_path, cur_name, conflict_hash, resolution_hash);
  CommPrint(1, "RESOLVE_OK %d %s\n", conflict_index, path_out);

  Free(idx_hashes);
  Free(idx_offsets);
}

// `hgit merge continue <repo>`: only proceeds once every real conflict
// for the current path's in-progress merge is resolved (ADR 0016).
// Re-runs the identical three-way merge (same ours_head/theirs_head,
// base_head re-derived - the object graph only ever grows between
// merge-start and now, ADR 0001, so this is deterministic) with the
// accumulated resolution table this time, so every previously-
// conflicting site now resolves via `MergeTreesRecursive`'s own
// resolution-lookup path instead of recording a conflict again.
U0 HgitMergeContinue(U8 *repo_path, U64 timestamp)
{
  U8 cur_name[HGIT_MAX_PATH_NAME];
  CurrentPathGet(repo_path, cur_name);
  if (!MetaMergeStateExists(repo_path, cur_name)) {
    CommPrint(1, "MERGE_ERR no_merge_in_progress\n");
    return;
  }

  U8 ours_head[64], theirs_head[64];
  U8 other_path_name[HGIT_MAX_PATH_NAME];
  MetaMergeStateRead(repo_path, cur_name, ours_head, theirs_head, other_path_name);

  I64 conflict_total = MetaConflictCount(repo_path, cur_name);
  U8 *resolution_conflict_hashes = MAlloc(conflict_total*64 + 64);
  U8 *resolution_hashes = MAlloc(conflict_total*64 + 64);
  I64 resolution_count = 0;
  I64 idx;
  I64 unresolved_count = 0;
  for (idx=0; idx<conflict_total; idx++) {
    U8 conflict_hash[64], resolved, resolution_hash[64];
    MetaConflictGetAt(repo_path, cur_name, idx, conflict_hash, &resolved, resolution_hash);
    if (!resolved) {
      CommPrint(1, "MERGE_ERR conflict_unresolved %d\n", idx);
      unresolved_count++;
    } else {
      I64 ri;
      for (ri=0; ri<64; ri++) resolution_conflict_hashes[resolution_count*64+ri] = conflict_hash[ri];
      for (ri=0; ri<64; ri++) resolution_hashes[resolution_count*64+ri] = resolution_hash[ri];
      resolution_count++;
    }
  }
  if (unresolved_count > 0) {
    CommPrint(1, "MERGE_ERR conflicts_still_unresolved count=%d\n", unresolved_count);
    Free(resolution_conflict_hashes); Free(resolution_hashes);
    return;
  }

  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  if (rbuf == NULL) { CommPrint(1, "MERGE_ERR not_a_repository\n"); Free(resolution_conflict_hashes); Free(resolution_hashes); return; }
  U16 rver;
  U64 rcount;
  HgsReadHeader(rbuf, &rver, &rcount);
  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  U8 base_head[64];
  Bool base_found = FindMergeBase(rbuf, idx_hashes, idx_offsets, idx_count,
                                  ours_head, theirs_head, base_head);
  if (!base_found) {
    CommPrint(1, "MERGE_ERR no_common_ancestor\n");
    Free(idx_hashes); Free(idx_offsets); Free(resolution_conflict_hashes); Free(resolution_hashes);
    return;
  }

  U8 *ours_tree = NULL; I64 ours_tree_len = 0;
  U8 *theirs_tree = NULL; I64 theirs_tree_len = 0;
  U8 *base_tree = NULL; I64 base_tree_len = 0;
  MergeResolveCommitTree(rbuf, idx_hashes, idx_offsets, idx_count, ours_head, &ours_tree, &ours_tree_len);
  MergeResolveCommitTree(rbuf, idx_hashes, idx_offsets, idx_count, theirs_head, &theirs_tree, &theirs_tree_len);
  Bool base_tree_ok = MergeResolveCommitTree(rbuf, idx_hashes, idx_offsets, idx_count, base_head, &base_tree, &base_tree_len);
  if (!base_tree_ok) base_tree = NULL;

  U8 *ours_attrs = NULL; I64 ours_attrs_len = 0;
  U8 *theirs_attrs = NULL; I64 theirs_attrs_len = 0;
  U8 *base_attrs = NULL; I64 base_attrs_len = 0;
  MergeResolveCommitAttrs(rbuf, idx_hashes, idx_offsets, idx_count, ours_head, &ours_attrs, &ours_attrs_len);
  MergeResolveCommitAttrs(rbuf, idx_hashes, idx_offsets, idx_count, theirs_head, &theirs_attrs, &theirs_attrs_len);
  MergeResolveCommitAttrs(rbuf, idx_hashes, idx_offsets, idx_count, base_head, &base_attrs, &base_attrs_len);

  // v1.8.4 provenance suffix: " [resolved path=take-ours ...]"
  U8 prov[200];
  I64 pvn = 0;
  prov[0] = 0;
  {
    U8 *pv_open = " [resolved";
    I64 pvj;
    for (pvj=0; pv_open[pvj]; pvj++) prov[pvn++] = pv_open[pvj];
    I64 pvk;
    for (pvk=0; pvk<resolution_count; pvk++) {
      I64 poff;
      if (IndexLookup(idx_hashes, idx_offsets, idx_count, resolution_conflict_hashes+pvk*64, &poff)) {
        I64 poff2 = 16 + poff;
        U8 pkind; U64 pent; U8 ppath[256]; I64 pplen;
        Bool ppres[3]; U8 ptype[3], pmode[3], phash[192];
        ConflictDecode(rbuf + poff2 + 9, &pkind, &pent, ppath, &pplen, ppres, ptype, pmode, phash);
        Bool pzero = TRUE;
        for (pvj=0; pvj<64; pvj++) if (resolution_hashes[pvk*64+pvj] != 0) pzero = FALSE;
        U8 *pw = "theirs";
        if (pzero) pw = "deleted";
        else {
          Bool pours = ppres[1];
          if (pours) for (pvj=0; pvj<64; pvj++) if (phash[64+pvj] != resolution_hashes[pvk*64+pvj]) pours = FALSE;
          if (pours) pw = "ours";
        }
        if (pvn < 150) {
          prov[pvn++] = ' ';
          for (pvj=0; ppath[pvj] && pvn<170; pvj++) prov[pvn++] = ppath[pvj];
          prov[pvn++] = '=';
          for (pvj=0; pw[pvj]; pvj++) prov[pvn++] = pw[pvj];
        }
      }
    }
    prov[pvn++] = ']';
    prov[pvn] = 0;
  }

  I64 archive_cap = rsize + MERGE_ARCHIVE_HEADROOM;
  U8 *archive = MAlloc(archive_cap);
  I64 alen;
  I64 i;
  for (i=0; i<rsize-16; i++) archive[16+i] = rbuf[16+i];
  alen = rsize;

  U32 ours_tcount = 0; if (ours_tree != NULL) ours_tcount = GetU32LE(ours_tree, 0);
  U32 theirs_tcount = 0; if (theirs_tree != NULL) theirs_tcount = GetU32LE(theirs_tree, 0);
  U32 base_tcount = 0; if (base_tree != NULL) base_tcount = GetU32LE(base_tree, 0);
  I64 max_names = ours_tcount + theirs_tcount + base_tcount + 1;
  U8 *conflict_names = MAlloc(max_names*256 + 256);
  U8 *conflict_hashes = MAlloc(max_names*64 + 64);
  I64 conflict_count;
  U8 merged_tree_content[4096];
  I64 merged_tree_len;
  U8 root_prefix[1]; root_prefix[0] = 0;
  U8 *merged_attrs_content = MAlloc(max_names*9 + 9);
  I64 merged_attrs_len = 4;

  Bool ok = MergeTreesRecursive(rbuf, idx_hashes, idx_offsets, idx_count,
                                archive, &alen,
                                base_tree, base_tree_len, ours_tree, ours_tree_len,
                                theirs_tree, theirs_tree_len, root_prefix,
                                merged_tree_content, &merged_tree_len,
                                conflict_names, conflict_hashes, &conflict_count,
                                base_attrs, base_attrs_len,
                                ours_attrs, ours_attrs_len,
                                theirs_attrs, theirs_attrs_len,
                                merged_attrs_content, &merged_attrs_len,
                                resolution_conflict_hashes, resolution_hashes, resolution_count);

  if (!ok) {
    // Should not happen - every conflict was confirmed resolved above,
    // and OBJ_CONFLICT hashes are deterministic given the same
    // ours_head/theirs_head/base_head. A real, honest defensive report
    // rather than silently mis-merging if it somehow does.
    CommPrint(1, "MERGE_ERR internal_still_conflicted_after_resolution count=%d\n", conflict_count);
    Free(idx_hashes); Free(idx_offsets); Free(conflict_names); Free(conflict_hashes);
    Free(archive); Free(merged_attrs_content); Free(resolution_conflict_hashes); Free(resolution_hashes);
    return;
  }

  MergeFinishSuccess(repo_path, archive, alen, rver, ours_head, theirs_head,
                     merged_tree_content, merged_tree_len,
                     merged_attrs_content, merged_attrs_len,
                     other_path_name, prov, timestamp);

  // The in-progress merge is over - clear it. The OBJ_CONFLICT objects
  // themselves stay in the archive forever (content-addressed, now
  // unreferenced - a real, honest CHECK_DANGLING, the same already-
  // accepted tradeoff `undo` leaves behind, ADR 0013).
  MetaMergeStateClear(repo_path, cur_name);

  Free(idx_hashes);
  Free(idx_offsets);
  Free(conflict_names);
  Free(conflict_hashes);
  Free(merged_attrs_content);
  Free(resolution_conflict_hashes);
  Free(resolution_hashes);
}

// `hgit merge abort <repo>`: discards the in-progress merge state
// (ADR 0016). The OBJ_CONFLICT objects themselves are left in the
// archive, unreferenced - same real, honest CHECK_DANGLING tradeoff as
// above. Nothing about the object tree or HEAD was ever touched by a
// conflicting merge attempt in the first place, so this restores the
// exact pre-merge repository state with no further work needed.
U0 HgitMergeAbort(U8 *repo_path)
{
  U8 cur_name[HGIT_MAX_PATH_NAME];
  CurrentPathGet(repo_path, cur_name);
  if (!MetaMergeStateExists(repo_path, cur_name)) {
    CommPrint(1, "MERGE_ERR no_merge_in_progress\n");
    return;
  }
  MetaMergeStateClear(repo_path, cur_name);
  CommPrint(1, "MERGE_ABORT_OK\n");
}

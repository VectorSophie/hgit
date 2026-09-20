// Status.HC — `hgit status`: compare the working directory against
// HEAD's tree.
//
// Three cases, all verified:
//   - Zero-offering repo (probe 16): every working-directory file is
//     untracked by definition - lists them via WorkDir.HC's
//     WorkDirList.
//   - Repo with a real HEAD (probe 20): walks HEAD -> its commit -> its
//     tree via Index.HC, then for each file matching `find_mask`,
//     hashes its current content and looks up the same name in the
//     tree's entry list (Tree.HC's TreeFindEntry) to classify it as
//     NEW (not in the tree), MODIFIED (in the tree, hash differs), or
//     UNCHANGED (in the tree, hash matches).
//   - Deleted files (probe 21): walks every entry in HEAD's tree and
//     checks whether a file by that name still exists under
//     `dir_prefix` on disk - if not, reports it DELETED. This needed
//     its own pass over the tree's entries (not just name lookups),
//     since nothing else builds a full listing of "everything the tree
//     says should exist."
//
// `find_mask`/`dir_prefix` exist for the same reason Offer.HC takes a
// mask: no self-exclusion logic yet, so the caller aims them away from
// the repo's own `.hgs`/`.head` files. `dir_prefix` must be the literal
// directory portion of `find_mask` (e.g. "C:/Home/" for
// "C:/Home/OfferFile*") - not derived automatically here.
//
// Depends on Canon.HC, Blake2b.HC, Archive.HC, Hgs.HC, Object.HC,
// Tree.HC, Commit.HC, Index.HC, Fossil.HC, WorkDir.HC (the whole
// hgit-core object layer plus the CLI pieces built so far).
//
// Both tree-entry walks (TreeFindEntry's new signature, and the manual
// pass-2 walk below) updated for ADR 0004's 8-byte entity ID field
// (experiments/49-entity-id/).
//
// ADR 0009 addendum (experiments/71-status-rename-surfacing/): status
// now also surfaces exact-content renames, not just NEW/MODIFIED/
// UNCHANGED/DELETED. A NEW-on-disk file and a DELETED tree entry that
// share the same content hash are reported as a single STATUS_RENAMED
// <old> -> <new> line instead of two separate NEW/DELETED lines - the
// same exact-content matching Offer.HC already uses to carry an entity
// ID forward (TreeFindEntryByHash), just applied here to working-dir
// vs HEAD-tree status instead of old-tree vs new-tree at offer time.
// This only *reports* the match; it doesn't change what gets committed
// - the next real `hgit offer` still does its own independent rename
// detection when the file is actually offered.
//
// ADR 0009 addendum (experiments/85-status-fuzzy-rename/): a second
// rename pass, for renames WITH an edit - reusing Fossil's similarity
// measure (ADR 0008, `experiments/83-fossil-similarity/`) the same
// way `Offer.HC`'s own fuzzy detection does (probe 84), same git-style
// `-M50%` threshold (`Fossil.HC`'s own `FOSSIL_RENAME_SIMILARITY_THRESHOLD`).
// Runs only against pairs the exact-hash pass above left unmatched.
// Now depends on `Fossil.HC` too (for the similarity call).
//
// ADR 0015 addendum: mode changes are surfaced independently of
// content changes, entity-ID-keyed (the same ID `TreeFindEntry`
// already returns, unaffected by rename), never inferred from
// content alone. For each already-tracked candidate, HEAD's own
// stored mode (looked up in HEAD's OBJ_ATTRS list, if any - 0/plain
// if HEAD has none or never listed this entity) is compared against
// the working-directory candidate's current effective mode
// (`.hgitattributes` rules + auto-detection, the exact same
// resolution `Offer.HC` itself uses) - a mismatch prints
// STATUS_MODE_CHANGED alongside (not instead of) the existing
// UNCHANGED/MODIFIED line, since content and mode are independent
// dimensions.

U0 HgitStatus(U8 *repo_path, U8 *find_mask, U8 *dir_prefix)
{
  I64 rsize;
  U8 *rbuf = HgitFileRead(repo_path, &rsize);
  if (rbuf == NULL) { CommPrint(1, "STATUS_ERR not_a_repository %s\n", repo_path); return; }
  U16 rver;
  U64 rcount;
  Bool hok = HgsReadHeader(rbuf, &rver, &rcount);
  if (!hok) {
    if (hgs_unsupported_version) CommPrint(1, "STATUS_ERR unsupported_format_version=%d (this build reads up to %d) %s\n", hgs_unsupported_version, HGS_MAX_SUPPORTED_VERSION, repo_path);
    else CommPrint(1, "STATUS_ERR bad_header %s\n", repo_path);
    return;
  }

  // ADR 0016: a real, early check before the usual UNCHANGED/MODIFIED/
  // NEW/DELETED/RENAMED walk - the roadmap's own "hgit status visibly
  // reports [conflicts]" requirement, satisfied at the top of the
  // existing output rather than a separate command a user has to
  // remember to run.
  U8 status_cur_name[HGIT_MAX_PATH_NAME];
  CurrentPathGet(repo_path, status_cur_name);
  if (MetaMergeStateExists(repo_path, status_cur_name)) {
    I64 status_conflict_total = MetaConflictCount(repo_path, status_cur_name);
    I64 status_unresolved = 0;
    I64 status_ci;
    for (status_ci=0; status_ci<status_conflict_total; status_ci++) {
      U8 status_ch[64], status_resolved, status_rh[64];
      MetaConflictGetAt(repo_path, status_cur_name, status_ci, status_ch, &status_resolved, status_rh);
      if (!status_resolved) status_unresolved++;
    }
    CommPrint(1, "STATUS_MERGE_IN_PROGRESS conflicts=%d unresolved=%d - see 'hgit conflicts'\n",
              status_conflict_total, status_unresolved);
  }

  if (rcount == 0) {
    CommPrint(1, "STATUS_NO_OFFERINGS_YET\n");
    WorkDirList();
    return;
  }

  U8 head_hash[64];
  if (!CurrentHeadRead(repo_path, head_hash)) {
    CommPrint(1, "STATUS_ERR no_head_but_objects_exist\n");
    return;
  }

  // ADR 0007's same fix, applied here (experiments/62-index-buffer-sweep/):
  // idx_hashes/idx_offsets used to be fixed [64*64]/[64] stack arrays, a
  // hardcoded 64-object-in-the-whole-repo cap - MAlloc'd from `rcount`
  // (exact, from the .HGS header) instead. Only one exit path here
  // after this point, freed right before it.
  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  I64 commit_off_rel;
  IndexLookup(idx_hashes, idx_offsets, idx_count, head_hash, &commit_off_rel);
  I64 commit_off = 16 + commit_off_rel; // Index offsets are relative to
                                        // the object section (rbuf+16)
                                        // - see probe 12/19's lesson.
  U64 commit_record_len = GetU64LE(rbuf, commit_off);
  U8 *commit_content = rbuf + commit_off + 9;
  I64 commit_content_len = commit_record_len - 1;
  U8 *tree_hash = CommitTreeHash(commit_content);

  I64 tree_off_rel;
  IndexLookup(idx_hashes, idx_offsets, idx_count, tree_hash, &tree_off_rel);
  I64 tree_off = 16 + tree_off_rel;
  U64 tree_record_len = GetU64LE(rbuf, tree_off);
  U8 *tree_content = rbuf + tree_off + 9;
  I64 tree_content_len = tree_record_len - 1; // minus the OBJ_TREE tag byte

  // ADR 0015: HEAD's own OBJ_ATTRS list (NULL/0 if HEAD has no
  // non-default mode anywhere - the common case).
  U8 *head_attrs_content = NULL;
  I64 head_attrs_len = 0;
  if (CommitHasAttrs(commit_content, commit_content_len)) {
    U8 *head_attrs_hash = CommitAttrsHash(commit_content);
    I64 attrs_off_rel;
    if (IndexLookup(idx_hashes, idx_offsets, idx_count, head_attrs_hash, &attrs_off_rel)) {
      I64 attrs_off = 16 + attrs_off_rel;
      U64 attrs_record_len = GetU64LE(rbuf, attrs_off);
      head_attrs_content = rbuf + attrs_off + 9;
      head_attrs_len = attrs_record_len - 1;
    }
  }

  // Pass 1: new / modified / unchanged, driven by what's actually on
  // disk right now. NEW files aren't printed immediately anymore - per
  // the ADR 0009 addendum above, they're buffered (name + hash) so
  // pass 2's deleted entries can be checked against them for an
  // exact-content rename match before anything is printed.
  I64 disk_count = 0;
  CDirEntry *count_de = FilesFind(find_mask, 0);
  CDirEntry *count_de1 = count_de;
  while (count_de) { disk_count++; count_de = count_de->next; }
  DirTreeDel(count_de1);

  U8 *new_names = MAlloc(disk_count*256 + 256);   // one 256-byte slot each
  U8 *new_hashes = MAlloc(disk_count*64 + 64);
  Bool *new_matched = MAlloc(disk_count + 1);
  // ADR 0009 addendum (experiments/85-status-fuzzy-rename/): a fuzzy
  // rename check needs each candidate's real CONTENT, not just its
  // hash - one 512-byte slot each. Probe 108 (experiments/108-status-large-file-support/):
  // this fixed per-slot stride is still real (a jagged/variable-offset
  // layout would be a bigger structural change than this probe scopes
  // to), so a candidate whose own content doesn't fit in one slot
  // simply isn't buffered for FUZZY matching - `new_content_lens[ni]`
  // is set to 0 for it (safe: `FossilSimilarityPercent` against a
  // zero-length target never matches), not skipped entirely - it still
  // gets a real hash (for exact-match rename detection) and a real
  // NEW/MODIFIED/UNCHANGED classification, unlike before this probe.
  U8 *new_contents = MAlloc(disk_count*512 + 512);
  I64 *new_content_lens = MAlloc(disk_count*8 + 8);
  I64 new_count = 0;

  // ADR 0014 (docs/adr/0014-ignore-rules.md): `.hgitignore` lives
  // alongside `dir_prefix` - loaded once per call, fresh from disk.
  U8 ignore_path[256];
  StrPrint(ignore_path, "%s.hgitignore", dir_prefix);
  U8 *ign_patterns, *ign_negate, *ign_kind;
  I64 ign_count;
  IgnoreLoad(ignore_path, &ign_patterns, &ign_negate, &ign_kind, &ign_count);

  // ADR 0015: `.hgitattributes` lives alongside `.hgitignore`, same
  // directory derivation, loaded once per call fresh from disk.
  U8 attrs_rules_path[256];
  StrPrint(attrs_rules_path, "%s.hgitattributes", dir_prefix);
  U8 *attr_patterns, *attr_kind, *attr_sets, *attr_values;
  I64 attr_count;
  AttrsRulesLoad(attrs_rules_path, &attr_patterns, &attr_kind, &attr_sets, &attr_values, &attr_count);

  CDirEntry *tmpde = FilesFind(find_mask, 0);
  CDirEntry *tmpde1 = tmpde;
  while (tmpde) {
    I64 fsize;
    U8 *fbuf = HgitFileRead(tmpde->full_name, &fsize);

    I64 name_start = 0, j;
    for (j=0; tmpde->full_name[j]; j++) if (tmpde->full_name[j]=='/') name_start=j+1;
    I64 name_len = j - name_start;

    // Probe 108: was a fixed `tagged[512]` stack buffer (a file over
    // 511 bytes overflowed it - guarded before this probe by skipping
    // the whole file with `STATUS_TOO_LARGE_TO_CHECK`, reporting
    // nothing else about it at all). `MAlloc`'d at the file's own real
    // size instead, same fix as probes 105-107's own version - a large
    // file now gets a real hash and a real NEW/MODIFIED/UNCHANGED
    // classification; only fuzzy-rename buffering (below) keeps a
    // real, separate, smaller size limit (`new_contents`'s own fixed
    // per-slot stride).
    U8 *tagged = MAlloc(fsize+1);
    tagged[0] = OBJ_BLOB;
    I64 i;
    for (i=0; i<fsize; i++) tagged[1+i] = fbuf[i];
    U8 file_hash[64];
    B2Hash512Any(tagged, fsize+1, file_hash);
    Free(tagged);

    U8 tree_type;
    U8 tree_entry_hash[64];
    U64 tree_entity_id;
    Bool in_tree = TreeFindEntry(tree_content, tree_content_len,
                                  tmpde->full_name+name_start, name_len,
                                  &tree_type, tree_entry_hash, &tree_entity_id);
    if (!in_tree && IsIgnored(ign_patterns, ign_negate, ign_kind, ign_count,
                              tmpde->full_name+name_start, "")) {
      // ADR 0014's safety rule already holds structurally here: this
      // branch is only reached when `!in_tree` (not already tracked),
      // so an ignored name is simply never treated as NEW at all -
      // never buffered, never reported. A tracked file matching this
      // same rule would have taken the `in_tree` branch below instead,
      // completely unaffected by ignore.
    } else if (!in_tree) {
      // Buffered, not printed - a possible rename source. Names over
      // 254 chars are truncated to fit the fixed 256-byte slot; this
      // repo's own 33-char path ceiling (ADR 0003) means a real name
      // this project has to handle never gets close to that anyway.
      I64 cap = name_len; if (cap > 254) cap = 254;
      for (i=0; i<cap; i++) new_names[new_count*256+i] = tmpde->full_name[name_start+i];
      new_names[new_count*256+cap] = 0;
      for (i=0; i<64; i++) new_hashes[new_count*64+i] = file_hash[i];
      if (fsize+1 <= 512) {
        for (i=0; i<fsize; i++) new_contents[new_count*512+i] = fbuf[i];
        new_content_lens[new_count] = fsize;
      } else {
        new_content_lens[new_count] = 0; // too large to buffer for fuzzy matching - see comment above
      }
      new_matched[new_count] = FALSE;
      new_count++;
    } else {
      Bool same = TRUE;
      for (i=0; i<64; i++) if (file_hash[i] != tree_entry_hash[i]) same = FALSE;
      if (same) CommPrint(1, "STATUS_UNCHANGED ");
      else CommPrint(1, "STATUS_MODIFIED ");
      for (j=name_start; tmpde->full_name[j]; j++) CommPrint(1, "%c", tmpde->full_name[j]);
      CommPrint(1, "\n");

      // ADR 0015: mode is a separate dimension from content - checked
      // and reported regardless of the content verdict just above.
      U8 old_mode = 0;
      if (head_attrs_content != NULL) {
        AttrsListFindMode(head_attrs_content, head_attrs_len, tree_entity_id, &old_mode);
      }
      Bool auto_binary = IsContentBinary(fbuf, fsize);
      U8 new_mode = GetEffectiveMode(attr_patterns, attr_kind, attr_sets, attr_values, attr_count,
                                     tmpde->full_name+name_start, "", auto_binary);
      if (old_mode != new_mode) {
        CommPrint(1, "STATUS_MODE_CHANGED ");
        for (j=name_start; tmpde->full_name[j]; j++) CommPrint(1, "%c", tmpde->full_name[j]);
        CommPrint(1, " %d -> %d\n", old_mode, new_mode);
      }
    }
    tmpde = tmpde->next;
  }
  DirTreeDel(tmpde1);
  IgnoreFree(ign_patterns, ign_negate, ign_kind);
  AttrsRulesFree(attr_patterns, attr_kind, attr_sets, attr_values);

  // Pass 2: deleted - walk every tree entry, check it still exists on
  // disk. This is the only place hgit-core needs "everything the tree
  // says should exist," so it's done inline here rather than adding a
  // generic tree-iteration API to Tree.HC for a single caller. Same as
  // pass 1, DELETED candidates are buffered (name + hash) instead of
  // printed immediately, so they can be checked against `new_names`/
  // `new_hashes` for a rename match first.
  U32 tcount = GetU32LE(tree_content, 0);
  U8 *del_names = MAlloc(tcount*256 + 256);
  U8 *del_hashes = MAlloc(tcount*64 + 64);
  Bool *del_matched = MAlloc(tcount + 1);
  I64 del_count = 0;

  I64 tpos = 4;
  U32 te;
  for (te=0; te<tcount; te++) {
    U8 tname_len = tree_content[tpos]; tpos += 1;
    U8 *tname = tree_content + tpos; tpos += tname_len;
    tpos += 1; // skip type
    U8 *thash = tree_content + tpos; tpos += 64; // keep for rename match
    tpos += 8; // skip entity_id (ADR 0004)

    U8 check_path[256];
    I64 k = 0;
    while (dir_prefix[k]) { check_path[k] = dir_prefix[k]; k++; }
    I64 m;
    for (m=0; m<tname_len; m++) check_path[k+m] = tname[m];
    check_path[k+tname_len] = 0;

    I64 check_size;
    U8 *check_buf = HgitFileRead(check_path, &check_size);
    if (check_buf == NULL) {
      I64 dcap = tname_len; if (dcap > 254) dcap = 254;
      for (m=0; m<dcap; m++) del_names[del_count*256+m] = tname[m];
      del_names[del_count*256+dcap] = 0;
      for (m=0; m<64; m++) del_hashes[del_count*64+m] = thash[m];
      del_matched[del_count] = FALSE;
      del_count++;
    }
  }

  // Rename match: exact-content only, same "first match wins"
  // simplification ADR 0009 already documents for Offer.HC's own
  // TreeFindEntryByHash - a genuine ambiguity (two deleted files with
  // identical content, one new file matching both) picks whichever
  // deleted entry is scanned first, not disambiguated further here.
  I64 di, ni;
  for (di=0; di<del_count; di++) {
    for (ni=0; ni<new_count; ni++) {
      Bool hmatch = !new_matched[ni];
      I64 hi;
      if (hmatch) for (hi=0; hi<64; hi++) if (del_hashes[di*64+hi] != new_hashes[ni*64+hi]) hmatch = FALSE;
      if (hmatch) {
        CommPrint(1, "STATUS_RENAMED %s -> %s\n", del_names+di*256, new_names+ni*256);
        new_matched[ni] = TRUE;
        del_matched[di] = TRUE;
        ni = new_count; // matched - stop scanning new[] for this del entry
      }
    }
  }

  // ADR 0009 addendum (experiments/85-status-fuzzy-rename/): a second
  // pass for renames WITH an edit - exact hash already failed above,
  // so try Fossil's similarity measure (ADR 0008, probe 83) against
  // each still-unmatched pair, same git-style -M50% threshold Offer.HC
  // already uses (probe 84). Each deleted entry's real content is
  // resolved on demand via the index already built above - deleted
  // candidates only ever store a hash, not their own content buffer,
  // since (unlike new-on-disk files) their bytes already live in the
  // repo's own archive and don't need a second copy. Same "first/best
  // match wins" simplification as the exact-hash pass just above.
  for (di=0; di<del_count; di++) {
    if (!del_matched[di]) {
      I64 del_off_rel;
      if (IndexLookup(idx_hashes, idx_offsets, idx_count, del_hashes+di*64, &del_off_rel)) {
        I64 del_off = 16 + del_off_rel;
        U64 del_rec_len = GetU64LE(rbuf, del_off);
        U8 *del_content = rbuf + del_off + 9; // skip the OBJ_BLOB type tag
        I64 del_content_len = del_rec_len - 1;

        I64 best_ni = -1, best_sim = -1;
        for (ni=0; ni<new_count; ni++) {
          if (!new_matched[ni]) {
            I64 sim = FossilSimilarityPercent(del_content, del_content_len,
                                              new_contents+ni*512, new_content_lens[ni]);
            if (sim > best_sim) { best_sim = sim; best_ni = ni; }
          }
        }
        if (best_ni >= 0 && best_sim >= FOSSIL_RENAME_SIMILARITY_THRESHOLD) {
          CommPrint(1, "STATUS_RENAMED %s -> %s\n", del_names+di*256, new_names+best_ni*256);
          new_matched[best_ni] = TRUE;
          del_matched[di] = TRUE;
        }
      }
    }
  }

  for (ni=0; ni<new_count; ni++) {
    if (!new_matched[ni]) CommPrint(1, "STATUS_NEW %s\n", new_names+ni*256);
  }
  for (di=0; di<del_count; di++) {
    if (!del_matched[di]) CommPrint(1, "STATUS_DELETED %s\n", del_names+di*256);
  }

  CommPrint(1, "STATUS_END\n");
  Free(idx_hashes);
  Free(idx_offsets);
  Free(new_names);
  Free(new_hashes);
  Free(new_contents);
  Free(new_content_lens);
  Free(new_matched);
  Free(del_names);
  Free(del_hashes);
  Free(del_matched);
}

// ADR 0010 addendum (experiments/95-statustree/): `hgit statustree
// <repo> <dir_path>` - a real, separate command, not a change to
// `hgit status`'s own `find_mask`/`dir_prefix` semantics (same
// CLI-semantics decision `offertree` already made for `offer`, and
// `Diff.HC`'s own recursion already made for `diff`). Closes the last
// item on ADR 0010's own "rendering-command awareness of nested
// trees" list.
//
// `StatusTreeWalk` recurses one real directory level at a time -
// same generic-per-object-type pattern this project already
// established (`Check.HC`'s `CheckMarkReachable`, `See.HC`'s
// `SeePrintTreeEntries`, `Diff.HC`'s `DiffPrintTreeChanges`): a real
// subdirectory on disk with a matching, same-typed tree entry is
// recursed into; a real subdirectory with no tree match (or a
// type-changed match) is recursed against an empty tree/reported
// `STATUS_TYPE_CHANGED`; a tree-only entry (a subdirectory that
// existed before but is no longer on disk at all) is recursed against
// an empty real directory listing, so every real entry it used to
// contain gets its own `STATUS_DELETED <path>` line. Rename detection
// (exact-hash, then fuzzy) stays scoped to one directory level at a
// time and blob-only, exactly like `Diff.HC`'s own - cross-directory
// rename detection remains ADR 0010's own deliberately deferred item.
U0 StatusTreeWalk(U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                  U8 *dir_path, U8 *tree_content, I64 tree_content_len,
                  U8 *prefix,
                  U8 *ign_patterns, U8 *ign_negate, U8 *ign_kind, I64 ign_count,
                  U8 *rel_dir,
                  U8 *attr_patterns, U8 *attr_kind, U8 *attr_sets, U8 *attr_values, I64 attr_count,
                  U8 *head_attrs_content, I64 head_attrs_len)
{
  U8 mask[256];
  StrPrint(mask, "%s*", dir_path);

  I64 disk_count = 0;
  CDirEntry *count_de = FilesFind(mask, 0);
  CDirEntry *count_de1 = count_de;
  while (count_de) { disk_count++; count_de = count_de->next; }
  DirTreeDel(count_de1);

  U8 *new_names = MAlloc(disk_count*256 + 256);
  U8 *new_hashes = MAlloc(disk_count*64 + 64);
  Bool *new_matched = MAlloc(disk_count + 1);
  U8 *new_contents = MAlloc(disk_count*512 + 512);
  I64 *new_content_lens = MAlloc(disk_count*8 + 8);
  I64 new_count = 0;

  U32 tcount = 0;
  if (tree_content != NULL) tcount = GetU32LE(tree_content, 0);
  U8 *del_names = MAlloc(tcount*256 + 256);
  U8 *del_hashes = MAlloc(tcount*64 + 64);
  Bool *del_matched = MAlloc(tcount + 1);
  I64 del_count = 0;

  I64 i;
  CDirEntry *tmpde = FilesFind(mask, 0);
  CDirEntry *tmpde1 = tmpde;
  while (tmpde) {
    I64 name_start = 0, j;
    for (j=0; tmpde->full_name[j]; j++) if (tmpde->full_name[j]=='/') name_start=j+1;
    I64 name_len = j - name_start;
    Bool is_dot = StrCmp(tmpde->full_name+name_start, ".") == 0;
    Bool is_dotdot = StrCmp(tmpde->full_name+name_start, "..") == 0;

    if (!is_dot && !is_dotdot) {
      U8 full_name[256];
      I64 fi = 0, fj;
      for (fj=0; prefix[fj]; fj++) full_name[fi++] = prefix[fj];
      I64 cap0 = name_len; if (fi+cap0 > 254) cap0 = 254-fi;
      for (fj=0; fj<cap0; fj++) full_name[fi++] = tmpde->full_name[name_start+fj];
      full_name[fi] = 0;

      if (tmpde->attr & 16) {
        U8 old_type;
        U8 old_hash[64];
        U64 old_entity_id;
        Bool found = FALSE;
        if (tree_content != NULL) {
          found = TreeFindEntry(tree_content, tree_content_len,
                                tmpde->full_name+name_start, name_len,
                                &old_type, old_hash, &old_entity_id);
        }
        U8 subdir_path[256];
        I64 spi = 0, spj;
        for (spj=0; tmpde->full_name[spj]; spj++) subdir_path[spi++] = tmpde->full_name[spj];
        subdir_path[spi++] = '/'; subdir_path[spi] = 0;

        U8 child_rel_dir[256];
        if (rel_dir[0] == 0) StrPrint(child_rel_dir, "%s", tmpde->full_name+name_start);
        else StrPrint(child_rel_dir, "%s/%s", rel_dir, tmpde->full_name+name_start);

        if (found && old_type == OBJ_TREE) {
          U8 *sub_tree_content_a = NULL; I64 sub_tree_len_a = 0;
          I64 sub_off_rel_a;
          if (IndexLookup(idx_hashes, idx_offsets, idx_count, old_hash, &sub_off_rel_a)) {
            I64 sub_off_a = 16 + sub_off_rel_a;
            U64 sub_rec_len_a = GetU64LE(rbuf, sub_off_a);
            sub_tree_content_a = rbuf + sub_off_a + 9;
            sub_tree_len_a = sub_rec_len_a - 1;
          }
          U8 sub_prefix_a[256];
          I64 pia = 0, pja;
          for (pja=0; full_name[pja]; pja++) sub_prefix_a[pia++] = full_name[pja];
          sub_prefix_a[pia++] = '/'; sub_prefix_a[pia] = 0;
          StatusTreeWalk(rbuf, idx_hashes, idx_offsets, idx_count,
                        subdir_path, sub_tree_content_a, sub_tree_len_a, sub_prefix_a,
                        ign_patterns, ign_negate, ign_kind, ign_count, child_rel_dir,
                        attr_patterns, attr_kind, attr_sets, attr_values, attr_count,
                        head_attrs_content, head_attrs_len);
        } else if (found) {
          CommPrint(1, "STATUS_TYPE_CHANGED %s\n", full_name);
        } else if (IsIgnored(ign_patterns, ign_negate, ign_kind, ign_count,
                              tmpde->full_name+name_start, rel_dir)) {
          // ADR 0014: not already tracked, and ignored - don't even
          // recurse, so nothing inside is reported as STATUS_NEW.
        } else {
          U8 sub_prefix_b[256];
          I64 pib = 0, pjb;
          for (pjb=0; full_name[pjb]; pjb++) sub_prefix_b[pib++] = full_name[pjb];
          sub_prefix_b[pib++] = '/'; sub_prefix_b[pib] = 0;
          StatusTreeWalk(rbuf, idx_hashes, idx_offsets, idx_count,
                        subdir_path, NULL, 0, sub_prefix_b,
                        ign_patterns, ign_negate, ign_kind, ign_count, child_rel_dir,
                        attr_patterns, attr_kind, attr_sets, attr_values, attr_count,
                        head_attrs_content, head_attrs_len);
        }
      } else {
        I64 fsize;
        U8 *fbuf = HgitFileRead(tmpde->full_name, &fsize);
        {
          // Probe 108 (experiments/108-status-large-file-support/):
          // was `if (fsize+1 > 512) STATUS_TOO_LARGE_TO_CHECK` guarding
          // a fixed `tagged[512]` stack buffer - `MAlloc`'d at the
          // file's own real size instead, same fix as the flat `hgit
          // status` version above. Only fuzzy-rename buffering below
          // keeps a real, separate size limit (`new_contents`'s own
          // fixed per-slot stride).
          U8 *tagged = MAlloc(fsize+1);
          tagged[0] = OBJ_BLOB;
          for (i=0; i<fsize; i++) tagged[1+i] = fbuf[i];
          U8 file_hash[64];
          B2Hash512Any(tagged, fsize+1, file_hash);
          Free(tagged);

          U8 tree_type;
          U8 tree_entry_hash[64];
          U64 tree_entity_id;
          Bool in_tree = FALSE;
          if (tree_content != NULL) {
            in_tree = TreeFindEntry(tree_content, tree_content_len,
                                    tmpde->full_name+name_start, name_len,
                                    &tree_type, tree_entry_hash, &tree_entity_id);
          }
          if (in_tree && tree_type == OBJ_BLOB) {
            Bool same_c = TRUE;
            for (i=0; i<64; i++) if (file_hash[i] != tree_entry_hash[i]) same_c = FALSE;
            if (!same_c) CommPrint(1, "STATUS_MODIFIED %s\n", full_name);

            // ADR 0015: mode is independent of content - checked even
            // when content itself is unchanged (same_c, otherwise
            // silent at this recursion level).
            U8 old_mode_r = 0;
            if (head_attrs_content != NULL) {
              AttrsListFindMode(head_attrs_content, head_attrs_len, tree_entity_id, &old_mode_r);
            }
            Bool auto_binary_r = IsContentBinary(fbuf, fsize);
            U8 new_mode_r = GetEffectiveMode(attr_patterns, attr_kind, attr_sets, attr_values, attr_count,
                                            tmpde->full_name+name_start, rel_dir, auto_binary_r);
            if (old_mode_r != new_mode_r) {
              CommPrint(1, "STATUS_MODE_CHANGED %s %d -> %d\n", full_name, old_mode_r, new_mode_r);
            }
          } else if (in_tree) {
            CommPrint(1, "STATUS_TYPE_CHANGED %s\n", full_name);
          } else if (IsIgnored(ign_patterns, ign_negate, ign_kind, ign_count,
                                tmpde->full_name+name_start, rel_dir)) {
            // ADR 0014: not already tracked, and ignored - never
            // reported as STATUS_NEW.
          } else {
            I64 cap = fi; if (cap > 254) cap = 254;
            for (i=0; i<cap; i++) new_names[new_count*256+i] = full_name[i];
            new_names[new_count*256+cap] = 0;
            for (i=0; i<64; i++) new_hashes[new_count*64+i] = file_hash[i];
            if (fsize+1 <= 512) {
              for (i=0; i<fsize; i++) new_contents[new_count*512+i] = fbuf[i];
              new_content_lens[new_count] = fsize;
            } else {
              new_content_lens[new_count] = 0; // too large to buffer for fuzzy matching
            }
            new_matched[new_count] = FALSE;
            new_count++;
          }
        }
      }
    }
    tmpde = tmpde->next;
  }
  DirTreeDel(tmpde1);

  // Deletion pass: a tree-only entry (no longer on disk at all, or on
  // disk with a different kind) at THIS level. Existence is checked
  // by real kind, not just FileRead success, since a tree entry can
  // now legitimately be a directory too (ADR 0010) - reusing the
  // already-real check_path convention every prior version of this
  // function used, extended with a FilesFind-based directory check.
  if (tree_content != NULL) {
    I64 tpos = 4;
    U32 te;
    for (te=0; te<tcount; te++) {
      U8 tname_len = tree_content[tpos]; tpos += 1;
      U8 *tname = tree_content + tpos; tpos += tname_len;
      U8 ttype = tree_content[tpos]; tpos += 1;
      U8 *thash = tree_content + tpos; tpos += 64;
      tpos += 8; // entity_id

      U8 check_path[256];
      I64 k = 0;
      while (dir_path[k]) { check_path[k] = dir_path[k]; k++; }
      I64 m;
      for (m=0; m<tname_len; m++) check_path[k+m] = tname[m];
      check_path[k+tname_len] = 0;

      U8 full_tname[256];
      I64 fti = 0, ftj;
      for (ftj=0; prefix[ftj]; ftj++) full_tname[fti++] = prefix[ftj];
      I64 tcap = tname_len; if (fti+tcap > 254) tcap = 254-fti;
      for (ftj=0; ftj<tcap; ftj++) full_tname[fti++] = tname[ftj];
      full_tname[fti] = 0;

      if (ttype == OBJ_TREE) {
        U8 dmask[256];
        StrPrint(dmask, "%s*", check_path);
        CDirEntry *dde = FilesFind(dmask, 0);
        Bool still_dir = (dde != NULL);
        if (dde != NULL) DirTreeDel(dde);
        if (!still_dir) {
          U8 *sub_content_c = NULL; I64 sub_len_c = 0;
          I64 sub_off_rel_c;
          if (IndexLookup(idx_hashes, idx_offsets, idx_count, thash, &sub_off_rel_c)) {
            I64 sub_off_c = 16 + sub_off_rel_c;
            U64 sub_rec_len_c = GetU64LE(rbuf, sub_off_c);
            sub_content_c = rbuf + sub_off_c + 9;
            sub_len_c = sub_rec_len_c - 1;
          }
          U8 sub_prefix_c[256];
          I64 pic = 0, pjc;
          for (pjc=0; full_tname[pjc]; pjc++) sub_prefix_c[pic++] = full_tname[pjc];
          sub_prefix_c[pic++] = '/'; sub_prefix_c[pic] = 0;
          // The directory itself is confirmed gone from disk (!still_dir),
          // so no NEW candidate can ever be found inside this recursive
          // call - ignore rules are structurally moot here, but rel_dir
          // is still threaded through for signature consistency.
          U8 tname_str[256];
          I64 tni; for (tni=0; tni<tname_len && tni<254; tni++) tname_str[tni] = tname[tni];
          tname_str[tni] = 0;
          U8 child_rel_dir_c[256];
          if (rel_dir[0] == 0) StrPrint(child_rel_dir_c, "%s", tname_str);
          else StrPrint(child_rel_dir_c, "%s/%s", rel_dir, tname_str);
          StatusTreeWalk(rbuf, idx_hashes, idx_offsets, idx_count,
                        check_path, sub_content_c, sub_len_c, sub_prefix_c,
                        ign_patterns, ign_negate, ign_kind, ign_count, child_rel_dir_c,
                        attr_patterns, attr_kind, attr_sets, attr_values, attr_count,
                        head_attrs_content, head_attrs_len);
        }
        // still_dir==TRUE: already handled by the new-tree pass above
        // (found && old_type==OBJ_TREE branch), skip to avoid a
        // duplicate report.
      } else {
        I64 check_size;
        U8 *check_buf = HgitFileRead(check_path, &check_size);
        if (check_buf == NULL) {
          I64 dcap = fti; if (dcap > 254) dcap = 254;
          for (m=0; m<dcap; m++) del_names[del_count*256+m] = full_tname[m];
          del_names[del_count*256+dcap] = 0;
          for (m=0; m<64; m++) del_hashes[del_count*64+m] = thash[m];
          del_matched[del_count] = FALSE;
          del_count++;
        }
      }
    }
  }

  // Rename match, exact-hash then fuzzy - blob-only, one directory
  // level at a time, same as Diff.HC's own recursive version.
  I64 di, ni;
  for (di=0; di<del_count; di++) {
    for (ni=0; ni<new_count; ni++) {
      Bool hmatch = !new_matched[ni];
      I64 hi;
      if (hmatch) for (hi=0; hi<64; hi++) if (del_hashes[di*64+hi] != new_hashes[ni*64+hi]) hmatch = FALSE;
      if (hmatch) {
        CommPrint(1, "STATUS_RENAMED %s -> %s\n", del_names+di*256, new_names+ni*256);
        new_matched[ni] = TRUE;
        del_matched[di] = TRUE;
        ni = new_count;
      }
    }
  }
  for (di=0; di<del_count; di++) {
    if (!del_matched[di]) {
      I64 del_off_rel;
      if (IndexLookup(idx_hashes, idx_offsets, idx_count, del_hashes+di*64, &del_off_rel)) {
        I64 del_off = 16 + del_off_rel;
        U64 del_rec_len = GetU64LE(rbuf, del_off);
        U8 *del_content = rbuf + del_off + 9;
        I64 del_content_len = del_rec_len - 1;

        I64 best_ni = -1, best_sim = -1;
        for (ni=0; ni<new_count; ni++) {
          if (!new_matched[ni]) {
            I64 sim = FossilSimilarityPercent(del_content, del_content_len,
                                              new_contents+ni*512, new_content_lens[ni]);
            if (sim > best_sim) { best_sim = sim; best_ni = ni; }
          }
        }
        if (best_ni >= 0 && best_sim >= FOSSIL_RENAME_SIMILARITY_THRESHOLD) {
          CommPrint(1, "STATUS_RENAMED %s -> %s\n", del_names+di*256, new_names+best_ni*256);
          new_matched[best_ni] = TRUE;
          del_matched[di] = TRUE;
        }
      }
    }
  }

  for (ni=0; ni<new_count; ni++) {
    if (!new_matched[ni]) CommPrint(1, "STATUS_NEW %s\n", new_names+ni*256);
  }
  for (di=0; di<del_count; di++) {
    if (!del_matched[di]) CommPrint(1, "STATUS_DELETED %s\n", del_names+di*256);
  }

  Free(new_names);
  Free(new_hashes);
  Free(new_contents);
  Free(new_content_lens);
  Free(new_matched);
  Free(del_names);
  Free(del_hashes);
  Free(del_matched);
}

U0 HgitStatusTree(U8 *repo_path, U8 *dir_path)
{
  I64 rsize;
  U8 *rbuf = HgitFileRead(repo_path, &rsize);
  if (rbuf == NULL) { CommPrint(1, "STATUS_ERR not_a_repository %s\n", repo_path); return; }
  U16 rver;
  U64 rcount;
  Bool hok = HgsReadHeader(rbuf, &rver, &rcount);
  if (!hok) {
    if (hgs_unsupported_version) CommPrint(1, "STATUS_ERR unsupported_format_version=%d (this build reads up to %d) %s\n", hgs_unsupported_version, HGS_MAX_SUPPORTED_VERSION, repo_path);
    else CommPrint(1, "STATUS_ERR bad_header %s\n", repo_path);
    return;
  }

  // ADR 0016 - see HgitStatus's own identical block for the rationale.
  U8 status_cur_name[HGIT_MAX_PATH_NAME];
  CurrentPathGet(repo_path, status_cur_name);
  if (MetaMergeStateExists(repo_path, status_cur_name)) {
    I64 status_conflict_total = MetaConflictCount(repo_path, status_cur_name);
    I64 status_unresolved = 0;
    I64 status_ci;
    for (status_ci=0; status_ci<status_conflict_total; status_ci++) {
      U8 status_ch[64], status_resolved, status_rh[64];
      MetaConflictGetAt(repo_path, status_cur_name, status_ci, status_ch, &status_resolved, status_rh);
      if (!status_resolved) status_unresolved++;
    }
    CommPrint(1, "STATUS_MERGE_IN_PROGRESS conflicts=%d unresolved=%d - see 'hgit conflicts'\n",
              status_conflict_total, status_unresolved);
  }

  if (rcount == 0) {
    CommPrint(1, "STATUS_NO_OFFERINGS_YET\n");
    WorkDirList();
    return;
  }

  U8 head_hash[64];
  if (!CurrentHeadRead(repo_path, head_hash)) {
    CommPrint(1, "STATUS_ERR no_head_but_objects_exist\n");
    return;
  }

  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  I64 commit_off_rel;
  IndexLookup(idx_hashes, idx_offsets, idx_count, head_hash, &commit_off_rel);
  I64 commit_off = 16 + commit_off_rel;
  U64 commit_record_len = GetU64LE(rbuf, commit_off);
  U8 *commit_content = rbuf + commit_off + 9;
  I64 commit_content_len = commit_record_len - 1;
  U8 *tree_hash = CommitTreeHash(commit_content);

  I64 tree_off_rel;
  IndexLookup(idx_hashes, idx_offsets, idx_count, tree_hash, &tree_off_rel);
  I64 tree_off = 16 + tree_off_rel;
  U64 tree_record_len = GetU64LE(rbuf, tree_off);
  U8 *tree_content = rbuf + tree_off + 9;
  I64 tree_content_len = tree_record_len - 1;

  // ADR 0015: HEAD's own OBJ_ATTRS list, if any.
  U8 *head_attrs_content = NULL;
  I64 head_attrs_len = 0;
  if (CommitHasAttrs(commit_content, commit_content_len)) {
    U8 *head_attrs_hash = CommitAttrsHash(commit_content);
    I64 attrs_off_rel;
    if (IndexLookup(idx_hashes, idx_offsets, idx_count, head_attrs_hash, &attrs_off_rel)) {
      I64 attrs_off = 16 + attrs_off_rel;
      U64 attrs_record_len = GetU64LE(rbuf, attrs_off);
      head_attrs_content = rbuf + attrs_off + 9;
      head_attrs_len = attrs_record_len - 1;
    }
  }

  U8 root_prefix[1]; root_prefix[0] = 0;

  // ADR 0014: `.hgitignore` lives at `dir_path` itself.
  U8 ignore_path[256];
  StrPrint(ignore_path, "%s.hgitignore", dir_path);
  U8 *ign_patterns, *ign_negate, *ign_kind;
  I64 ign_count;
  IgnoreLoad(ignore_path, &ign_patterns, &ign_negate, &ign_kind, &ign_count);

  // ADR 0015: `.hgitattributes` lives at `dir_path` itself, same
  // convention as `.hgitignore` just above.
  U8 attrs_rules_path[256];
  StrPrint(attrs_rules_path, "%s.hgitattributes", dir_path);
  U8 *attr_patterns, *attr_kind, *attr_sets, *attr_values;
  I64 attr_count;
  AttrsRulesLoad(attrs_rules_path, &attr_patterns, &attr_kind, &attr_sets, &attr_values, &attr_count);

  StatusTreeWalk(rbuf, idx_hashes, idx_offsets, idx_count,
                dir_path, tree_content, tree_content_len, root_prefix,
                ign_patterns, ign_negate, ign_kind, ign_count, "",
                attr_patterns, attr_kind, attr_sets, attr_values, attr_count,
                head_attrs_content, head_attrs_len);
  IgnoreFree(ign_patterns, ign_negate, ign_kind);
  AttrsRulesFree(attr_patterns, attr_kind, attr_sets, attr_values);

  CommPrint(1, "STATUS_END\n");
  Free(idx_hashes);
  Free(idx_offsets);
}

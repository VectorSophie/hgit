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
// Tree.HC, Commit.HC, Index.HC, WorkDir.HC (the whole
// hgit-core object layer plus the CLI pieces built so far).
//
// Both tree-entry walks (TreeFindEntry's new signature, and the manual
// pass-2 walk below) updated for ADR 0004's 8-byte entity ID field
// (experiments/49-entity-id/).

U0 HgitStatus(U8 *repo_path, U8 *find_mask, U8 *dir_prefix)
{
  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  if (rbuf == NULL) { CommPrint(1, "STATUS_ERR not_a_repository %s\n", repo_path); return; }
  U16 rver;
  U64 rcount;
  Bool hok = HgsReadHeader(rbuf, &rver, &rcount);
  if (!hok) { CommPrint(1, "STATUS_ERR bad_header %s\n", repo_path); return; }

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
  U8 *commit_content = rbuf + commit_off + 9;
  U8 *tree_hash = CommitTreeHash(commit_content);

  I64 tree_off_rel;
  IndexLookup(idx_hashes, idx_offsets, idx_count, tree_hash, &tree_off_rel);
  I64 tree_off = 16 + tree_off_rel;
  U64 tree_record_len = GetU64LE(rbuf, tree_off);
  U8 *tree_content = rbuf + tree_off + 9;
  I64 tree_content_len = tree_record_len - 1; // minus the OBJ_TREE tag byte

  // Pass 1: new / modified / unchanged, driven by what's actually on
  // disk right now.
  CDirEntry *tmpde = FilesFind(find_mask, 0);
  CDirEntry *tmpde1 = tmpde;
  while (tmpde) {
    I64 fsize;
    U8 *fbuf = FileRead(tmpde->full_name, &fsize);

    I64 name_start = 0, j;
    for (j=0; tmpde->full_name[j]; j++) if (tmpde->full_name[j]=='/') name_start=j+1;
    I64 name_len = j - name_start;

    // Real bug found and fixed (experiments/67-historydoc-buffer-guard/),
    // same class as probe 56's own Offer.HC finding: `tagged[512]` had
    // no bound against a matched file's real size - a file over 511
    // bytes overflows it. Guarded the same way: skip with a clear
    // message instead of corrupting memory.
    if (fsize+1 > 512) {
      CommPrint(1, "STATUS_TOO_LARGE_TO_CHECK ");
      for (j=name_start; tmpde->full_name[j]; j++) CommPrint(1, "%c", tmpde->full_name[j]);
      CommPrint(1, "\n");
    } else {
      U8 tagged[512];
      tagged[0] = OBJ_BLOB;
      I64 i;
      for (i=0; i<fsize; i++) tagged[1+i] = fbuf[i];
      U8 file_hash[64];
      B2Hash512Any(tagged, fsize+1, file_hash);

      U8 tree_type;
      U8 tree_entry_hash[64];
      U64 tree_entity_id;
      Bool in_tree = TreeFindEntry(tree_content, tree_content_len,
                                    tmpde->full_name+name_start, name_len,
                                    &tree_type, tree_entry_hash, &tree_entity_id);
      if (!in_tree) {
        CommPrint(1, "STATUS_NEW ");
      } else {
        Bool same = TRUE;
        for (i=0; i<64; i++) if (file_hash[i] != tree_entry_hash[i]) same = FALSE;
        if (same) CommPrint(1, "STATUS_UNCHANGED ");
        else CommPrint(1, "STATUS_MODIFIED ");
      }
      for (j=name_start; tmpde->full_name[j]; j++) CommPrint(1, "%c", tmpde->full_name[j]);
      CommPrint(1, "\n");
    }
    tmpde = tmpde->next;
  }
  DirTreeDel(tmpde1);

  // Pass 2: deleted - walk every tree entry, check it still exists on
  // disk. This is the only place hgit-core needs "everything the tree
  // says should exist," so it's done inline here rather than adding a
  // generic tree-iteration API to Tree.HC for a single caller.
  U32 tcount = GetU32LE(tree_content, 0);
  I64 tpos = 4;
  U32 te;
  for (te=0; te<tcount; te++) {
    U8 tname_len = tree_content[tpos]; tpos += 1;
    U8 *tname = tree_content + tpos; tpos += tname_len;
    tpos += 1; // skip type
    tpos += 64; // skip hash
    tpos += 8; // skip entity_id (ADR 0004)

    U8 check_path[256];
    I64 k = 0;
    while (dir_prefix[k]) { check_path[k] = dir_prefix[k]; k++; }
    I64 m;
    for (m=0; m<tname_len; m++) check_path[k+m] = tname[m];
    check_path[k+tname_len] = 0;

    I64 check_size;
    U8 *check_buf = FileRead(check_path, &check_size);
    if (check_buf == NULL) {
      CommPrint(1, "STATUS_DELETED ");
      for (m=0; m<tname_len; m++) CommPrint(1, "%c", tname[m]);
      CommPrint(1, "\n");
    }
  }
  CommPrint(1, "STATUS_END\n");
  Free(idx_hashes);
  Free(idx_offsets);
}

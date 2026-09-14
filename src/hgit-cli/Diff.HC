// Diff.HC — `hgit diff <repo> <commit_hex>`: show what changed in one
// commit relative to its own parent's tree (or, for a root commit
// with no parent, every entry is new). For a real merge commit (ADR
// 0011), "its own parent" means specifically the FIRST parent
// (`ours` at merge time) - the same convention `git show`/`git log -p`
// use by default for a merge - not a special case added for merge
// commits, just this file's own pre-existing single-parent behavior
// applied unchanged. Confirmed sane against a real merge commit
// (probe 111, `experiments/111-diff-on-merge-commit/`): a file that
// only entered the tree via the merge's SECOND parent correctly shows
// as `DIFF_NEW`, since it wasn't present in the first parent's own
// tree - not a crash, not a wrong answer, a real and coherent (if
// partial) view.
//
// This is the per-commit counterpart to `hgit status`'s own
// working-directory-vs-HEAD-tree diff (`Status.HC`) - same
// classification vocabulary (NEW/MODIFIED/DELETED/RENAMED, both exact-
// content and fuzzy), same two-pass rename-matching logic, just
// comparing two COMMITTED trees instead of a live directory against
// one. Closes the "hgit history/reconciledoc don't surface renames"
// gap ADR 0009 left open (probes 71/85 only covered `status`) - not by
// changing `history`'s own per-line format, but by giving renames (and
// every other kind of change) a real, dedicated place to be shown per
// commit.
//
// Simpler than `Status.HC` in one real way: both sides here are
// already-stored blobs, so content for a fuzzy-match candidate is
// always resolved via the index (IndexLookup + rbuf), never a live
// FileRead - no need to buffer full file content ahead of time the way
// `Status.HC`'s NEW-on-disk candidates require.
//
// Recurses into nested trees (ADR 0010, experiments/94-diff-nested-
// trees/) - the same generic-per-object-type recursion pattern this
// project already established (Check.HC's CheckMarkReachable, See.HC's
// SeePrintTreeEntries): a subdirectory entry whose own hash changed is
// diffed recursively instead of just reported as one opaque
// "MODIFIED <dirname>" line, and a wholly new/deleted subdirectory is
// recursed into against an empty tree, so every real nested file gets
// its own DIFF_NEW/DIFF_DELETED line (prefixed with its real path,
// e.g. "SubA/inner.txt") instead of naming only the directory once.
// Deliberately out of scope, same as ADR 0010's own deferred item:
// cross-directory rename detection, and a same-name entry that
// changes KIND (file<->directory) - reported as a real, honest
// DIFF_TYPE_CHANGED signal, not silently mis-diffed as a content
// change or guessed at either side.
//
// Depends on Canon.HC, Blake2b.HC, Hgs.HC, Object.HC, Commit.HC,
// Tree.HC, Index.HC, Fossil.HC, Hex.HC.

// Resolves a tree object's own content/length by its hash, via the
// same IndexLookup every other real command uses. Returns FALSE (not
// a crash) if the hash isn't in the index - a broken reference is
// Check.HC's own job to report, not this file's.
Bool DiffResolveTreeByHash(U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
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

// Diffs one tree level (old vs new, either side may be NULL - a real,
// valid base case for recursing into a wholly new/deleted
// subdirectory against an empty tree, not a special case needing its
// own logic), printing every real change with `prefix` prepended to
// its name (e.g. "SubA/"). Recurses into any OBJ_TREE entry whose own
// hash changed, or that's wholly new/deleted, one directory level at
// a time.
U0 DiffPrintTreeChanges(U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                        U8 *old_tree_content, I64 old_tree_content_len,
                        U8 *new_tree_content, I64 new_tree_content_len,
                        U8 *prefix)
{
  U32 new_tcount = 0;
  if (new_tree_content != NULL) new_tcount = GetU32LE(new_tree_content, 0);
  U32 old_tcount = 0;
  if (old_tree_content != NULL) old_tcount = GetU32LE(old_tree_content, 0);

  // Buffers sized from each tree's own exact entry count (already
  // known, same "no premature fixed cap" discipline every other
  // MAlloc'd index/buffer in this project already follows). Only
  // OBJ_BLOB entries ever populate these - a tree entry is either
  // handled immediately (recursed into) or reported directly, never
  // buffered as a rename candidate (see file header).
  U8 *new_names = MAlloc(new_tcount*256 + 256);
  U8 *new_hashes = MAlloc(new_tcount*64 + 64);
  Bool *new_matched = MAlloc(new_tcount + 1);
  I64 new_count = 0;

  U8 *del_names = MAlloc(old_tcount*256 + 256);
  U8 *del_hashes = MAlloc(old_tcount*64 + 64);
  Bool *del_matched = MAlloc(old_tcount + 1);
  I64 del_count = 0;

  I64 pos = 4;
  U32 te;
  I64 i;
  if (new_tree_content != NULL) {
    for (te=0; te<new_tcount; te++) {
      U8 nlen = new_tree_content[pos]; pos += 1;
      U8 *name = new_tree_content + pos; pos += nlen;
      U8 new_type = new_tree_content[pos]; pos += 1;
      U8 *hash = new_tree_content + pos; pos += 64;
      pos += 8; // entity_id - not needed here

      U8 full_name[256];
      I64 fi = 0, fj;
      for (fj=0; prefix[fj]; fj++) full_name[fi++] = prefix[fj];
      I64 cap = nlen; if (fi + cap > 254) cap = 254 - fi;
      for (fj=0; fj<cap; fj++) full_name[fi++] = name[fj];
      full_name[fi] = 0;

      Bool found_by_name = FALSE;
      U8 old_type;
      U8 old_hash[64];
      U64 old_entity_id;
      if (old_tree_content != NULL) {
        found_by_name = TreeFindEntry(old_tree_content, old_tree_content_len,
                                      name, nlen, &old_type, old_hash, &old_entity_id);
      }

      if (new_type == OBJ_TREE) {
        if (found_by_name && old_type == OBJ_TREE) {
          Bool same_a = TRUE;
          for (i=0; i<64; i++) if (hash[i] != old_hash[i]) same_a = FALSE;
          if (!same_a) {
            U8 *sub_old_content_a = NULL; I64 sub_old_len_a = 0;
            U8 *sub_new_content_a = NULL; I64 sub_new_len_a = 0;
            DiffResolveTreeByHash(rbuf, idx_hashes, idx_offsets, idx_count,
                                 old_hash, &sub_old_content_a, &sub_old_len_a);
            DiffResolveTreeByHash(rbuf, idx_hashes, idx_offsets, idx_count,
                                 hash, &sub_new_content_a, &sub_new_len_a);
            U8 sub_prefix_a[256];
            I64 spi_a=0, spj_a;
            for (spj_a=0; full_name[spj_a]; spj_a++) sub_prefix_a[spi_a++] = full_name[spj_a];
            sub_prefix_a[spi_a++] = '/'; sub_prefix_a[spi_a] = 0;
            DiffPrintTreeChanges(rbuf, idx_hashes, idx_offsets, idx_count,
                                 sub_old_content_a, sub_old_len_a,
                                 sub_new_content_a, sub_new_len_a, sub_prefix_a);
          }
        } else if (found_by_name) {
          // Same name, old side isn't a tree - a real kind-change
          // (file->directory), deliberately out of scope (see file
          // header): report it plainly, don't guess at either side.
          CommPrint(1, "DIFF_TYPE_CHANGED ");
          for (i=0; full_name[i]; i++) CommPrint(1, "%c", full_name[i]);
          CommPrint(1, "\n");
        } else {
          // A wholly new subdirectory - recurse against an empty old
          // tree so every real nested entry gets its own DIFF_NEW
          // line, not just one line naming the directory.
          U8 *sub_new_content_b = NULL; I64 sub_new_len_b = 0;
          DiffResolveTreeByHash(rbuf, idx_hashes, idx_offsets, idx_count,
                               hash, &sub_new_content_b, &sub_new_len_b);
          U8 sub_prefix_b[256];
          I64 spi_b=0, spj_b;
          for (spj_b=0; full_name[spj_b]; spj_b++) sub_prefix_b[spi_b++] = full_name[spj_b];
          sub_prefix_b[spi_b++] = '/'; sub_prefix_b[spi_b] = 0;
          DiffPrintTreeChanges(rbuf, idx_hashes, idx_offsets, idx_count,
                               NULL, 0, sub_new_content_b, sub_new_len_b, sub_prefix_b);
        }
      } else {
        // OBJ_BLOB: unchanged from before - same name/same type in old
        // tree -> UNCHANGED (silent) or MODIFIED (printed immediately);
        // no match by name -> buffered as a rename candidate.
        if (found_by_name && old_type == OBJ_BLOB) {
          Bool same_b = TRUE;
          for (i=0; i<64; i++) if (hash[i] != old_hash[i]) same_b = FALSE;
          if (!same_b) {
            CommPrint(1, "DIFF_MODIFIED ");
            for (i=0; full_name[i]; i++) CommPrint(1, "%c", full_name[i]);
            CommPrint(1, "\n");
          }
        } else if (found_by_name) {
          CommPrint(1, "DIFF_TYPE_CHANGED ");
          for (i=0; full_name[i]; i++) CommPrint(1, "%c", full_name[i]);
          CommPrint(1, "\n");
        } else {
          I64 ncap = fi; if (ncap > 254) ncap = 254;
          for (i=0; i<ncap; i++) new_names[new_count*256+i] = full_name[i];
          new_names[new_count*256+ncap] = 0;
          for (i=0; i<64; i++) new_hashes[new_count*64+i] = hash[i];
          new_matched[new_count] = FALSE;
          new_count++;
        }
      }
    }
  }

  // Deletion pass over the old tree: an entry found in the new tree by
  // name (any type) was already handled above (unchanged/modified/
  // recursed/type-changed) - skip it here to avoid double-reporting.
  if (old_tree_content != NULL) {
    I64 opos = 4;
    U32 oe;
    for (oe=0; oe<old_tcount; oe++) {
      U8 onlen = old_tree_content[opos]; opos += 1;
      U8 *oname = old_tree_content + opos; opos += onlen;
      U8 old_type2 = old_tree_content[opos]; opos += 1;
      U8 *ohash = old_tree_content + opos; opos += 64;
      opos += 8; // entity_id

      U8 dummy_type;
      U8 dummy_hash[64];
      U64 dummy_entity_id;
      Bool found_in_new = FALSE;
      if (new_tree_content != NULL) {
        found_in_new = TreeFindEntry(new_tree_content, new_tree_content_len,
                                     oname, onlen, &dummy_type, dummy_hash, &dummy_entity_id);
      }
      if (!found_in_new) {
        U8 full_oname[256];
        I64 ofi = 0, ofj;
        for (ofj=0; prefix[ofj]; ofj++) full_oname[ofi++] = prefix[ofj];
        I64 ocap = onlen; if (ofi + ocap > 254) ocap = 254 - ofi;
        for (ofj=0; ofj<ocap; ofj++) full_oname[ofi++] = oname[ofj];
        full_oname[ofi] = 0;

        if (old_type2 == OBJ_TREE) {
          // A wholly deleted subdirectory - recurse against an empty
          // new tree so every real nested entry gets its own
          // DIFF_DELETED line.
          U8 *sub_old_content_c = NULL; I64 sub_old_len_c = 0;
          DiffResolveTreeByHash(rbuf, idx_hashes, idx_offsets, idx_count,
                               ohash, &sub_old_content_c, &sub_old_len_c);
          U8 sub_prefix_c[256];
          I64 spi_c=0, spj_c;
          for (spj_c=0; full_oname[spj_c]; spj_c++) sub_prefix_c[spi_c++] = full_oname[spj_c];
          sub_prefix_c[spi_c++] = '/'; sub_prefix_c[spi_c] = 0;
          DiffPrintTreeChanges(rbuf, idx_hashes, idx_offsets, idx_count,
                               sub_old_content_c, sub_old_len_c, NULL, 0, sub_prefix_c);
        } else {
          I64 dcap = ofi; if (dcap > 254) dcap = 254;
          for (i=0; i<dcap; i++) del_names[del_count*256+i] = full_oname[i];
          del_names[del_count*256+dcap] = 0;
          for (i=0; i<64; i++) del_hashes[del_count*64+i] = ohash[i];
          del_matched[del_count] = FALSE;
          del_count++;
        }
      }
    }
  }

  // Rename pass 1: exact content match, same "first match wins"
  // simplification every other rename check in this project documents.
  // Blob-only, same as before - a tree's own serialized content isn't
  // meaningful to compare this way (see file header).
  I64 di, ni;
  for (di=0; di<del_count; di++) {
    for (ni=0; ni<new_count; ni++) {
      Bool hmatch = !new_matched[ni];
      I64 hi;
      if (hmatch) for (hi=0; hi<64; hi++) if (del_hashes[di*64+hi] != new_hashes[ni*64+hi]) hmatch = FALSE;
      if (hmatch) {
        CommPrint(1, "DIFF_RENAMED %s -> %s\n", del_names+di*256, new_names+ni*256);
        new_matched[ni] = TRUE;
        del_matched[di] = TRUE;
        ni = new_count;
      }
    }
  }

  // Rename pass 2: fuzzy match (ADR 0008/0009, Fossil.HC's own
  // similarity measure), same git-style -M50% threshold Offer.HC and
  // Status.HC already use. Both sides resolved on demand via the
  // index - no content buffering needed ahead of time, since both are
  // already-stored blobs.
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
            I64 new_off_rel;
            if (IndexLookup(idx_hashes, idx_offsets, idx_count, new_hashes+ni*64, &new_off_rel)) {
              I64 new_off = 16 + new_off_rel;
              U64 new_rec_len = GetU64LE(rbuf, new_off);
              U8 *new_content = rbuf + new_off + 9;
              I64 new_content_len = new_rec_len - 1;
              I64 sim = FossilSimilarityPercent(del_content, del_content_len,
                                                new_content, new_content_len);
              if (sim > best_sim) { best_sim = sim; best_ni = ni; }
            }
          }
        }
        if (best_ni >= 0 && best_sim >= FOSSIL_RENAME_SIMILARITY_THRESHOLD) {
          CommPrint(1, "DIFF_RENAMED %s -> %s\n", del_names+di*256, new_names+best_ni*256);
          new_matched[best_ni] = TRUE;
          del_matched[di] = TRUE;
        }
      }
    }
  }

  for (ni=0; ni<new_count; ni++) {
    if (!new_matched[ni]) CommPrint(1, "DIFF_NEW %s\n", new_names+ni*256);
  }
  for (di=0; di<del_count; di++) {
    if (!del_matched[di]) CommPrint(1, "DIFF_DELETED %s\n", del_names+di*256);
  }

  Free(new_names);
  Free(new_hashes);
  Free(new_matched);
  Free(del_names);
  Free(del_hashes);
  Free(del_matched);
}

U0 HgitDiff(U8 *repo_path, U8 *commit_hash)
{
  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  if (rbuf == NULL) { CommPrint(1, "DIFF_ERR not_a_repository\n"); return; }
  U16 rver;
  U64 rcount;
  Bool hok = HgsReadHeader(rbuf, &rver, &rcount);
  if (!hok) { CommPrint(1, "DIFF_ERR bad_header\n"); return; }

  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  I64 c_off_rel;
  if (!IndexLookup(idx_hashes, idx_offsets, idx_count, commit_hash, &c_off_rel)) {
    CommPrint(1, "DIFF_ERR commit_not_found\n");
    Free(idx_hashes); Free(idx_offsets);
    return;
  }
  I64 c_off = 16 + c_off_rel;
  U8 c_type = rbuf[c_off+8];
  if (c_type != OBJ_COMMIT) {
    CommPrint(1, "DIFF_ERR not_a_commit type=%d\n", c_type);
    Free(idx_hashes); Free(idx_offsets);
    return;
  }
  U8 *c_content = rbuf + c_off + 9;
  U8 *new_tree_hash = CommitTreeHash(c_content);

  I64 nt_off_rel;
  if (!IndexLookup(idx_hashes, idx_offsets, idx_count, new_tree_hash, &nt_off_rel)) {
    CommPrint(1, "DIFF_ERR tree_not_found\n");
    Free(idx_hashes); Free(idx_offsets);
    return;
  }
  I64 nt_off = 16 + nt_off_rel;
  U64 nt_rec_len = GetU64LE(rbuf, nt_off);
  U8 *new_tree_content = rbuf + nt_off + 9;
  I64 new_tree_content_len = nt_rec_len - 1;

  U8 *old_tree_content = NULL;
  I64 old_tree_content_len = 0;
  U8 pcount = CommitParentCount(c_content);
  if (pcount > 0) {
    U8 *parent_hash = CommitParentHash(c_content, 0);
    I64 p_off_rel;
    if (IndexLookup(idx_hashes, idx_offsets, idx_count, parent_hash, &p_off_rel)) {
      I64 p_off = 16 + p_off_rel;
      U8 *p_content = rbuf + p_off + 9;
      U8 *old_tree_hash = CommitTreeHash(p_content);
      I64 ot_off_rel;
      if (IndexLookup(idx_hashes, idx_offsets, idx_count, old_tree_hash, &ot_off_rel)) {
        I64 ot_off = 16 + ot_off_rel;
        U64 ot_rec_len = GetU64LE(rbuf, ot_off);
        old_tree_content = rbuf + ot_off + 9;
        old_tree_content_len = ot_rec_len - 1;
      }
    }
  }

  U8 root_prefix[1]; root_prefix[0] = 0;
  DiffPrintTreeChanges(rbuf, idx_hashes, idx_offsets, idx_count,
                       old_tree_content, old_tree_content_len,
                       new_tree_content, new_tree_content_len, root_prefix);

  CommPrint(1, "DIFF_END\n");

  Free(idx_hashes);
  Free(idx_offsets);
}

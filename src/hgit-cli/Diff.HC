// Diff.HC — `hgit diff <repo> <commit_hex>`: show what changed in one
// commit relative to its own parent's tree (or, for a root commit
// with no parent, every entry is new).
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
// Depends on Canon.HC, Blake2b.HC, Hgs.HC, Object.HC, Commit.HC,
// Tree.HC, Index.HC, Fossil.HC, Hex.HC.

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

  U32 new_tcount = GetU32LE(new_tree_content, 0);
  U32 old_tcount = 0;
  if (old_tree_content != NULL) old_tcount = GetU32LE(old_tree_content, 0);

  // Buffers sized from each tree's own exact entry count (already
  // known, same "no premature fixed cap" discipline every other
  // MAlloc'd index/buffer in this project already follows).
  U8 *new_names = MAlloc(new_tcount*256 + 256);
  U8 *new_hashes = MAlloc(new_tcount*64 + 64);
  Bool *new_matched = MAlloc(new_tcount + 1);
  I64 new_count = 0;

  U8 *del_names = MAlloc(old_tcount*256 + 256);
  U8 *del_hashes = MAlloc(old_tcount*64 + 64);
  Bool *del_matched = MAlloc(old_tcount + 1);
  I64 del_count = 0;

  // Pass 1 over the new tree: same name in old tree -> UNCHANGED
  // (silent, matching every real diff tool's own default) or MODIFIED
  // (printed immediately); no match by name -> buffered as a rename
  // candidate.
  I64 pos = 4;
  U32 te;
  I64 i;
  for (te=0; te<new_tcount; te++) {
    U8 nlen = new_tree_content[pos]; pos += 1;
    U8 *name = new_tree_content + pos; pos += nlen;
    pos += 1; // child_type
    U8 *hash = new_tree_content + pos; pos += 64;
    pos += 8; // entity_id - not needed here

    Bool found_by_name = FALSE;
    U8 old_type;
    U8 old_hash[64];
    U64 old_entity_id;
    if (old_tree_content != NULL) {
      found_by_name = TreeFindEntry(old_tree_content, old_tree_content_len,
                                    name, nlen, &old_type, old_hash, &old_entity_id);
    }
    if (found_by_name) {
      Bool same = TRUE;
      for (i=0; i<64; i++) if (hash[i] != old_hash[i]) same = FALSE;
      if (!same) {
        CommPrint(1, "DIFF_MODIFIED ");
        for (i=0; i<nlen; i++) CommPrint(1, "%c", name[i]);
        CommPrint(1, "\n");
      }
    } else {
      I64 cap = nlen; if (cap > 254) cap = 254;
      for (i=0; i<cap; i++) new_names[new_count*256+i] = name[i];
      new_names[new_count*256+cap] = 0;
      for (i=0; i<64; i++) new_hashes[new_count*64+i] = hash[i];
      new_matched[new_count] = FALSE;
      new_count++;
    }
  }

  // Pass 2 over the old tree: no match by name in the new tree ->
  // buffered as a deleted/renamed-from candidate.
  if (old_tree_content != NULL) {
    I64 opos = 4;
    U32 oe;
    for (oe=0; oe<old_tcount; oe++) {
      U8 onlen = old_tree_content[opos]; opos += 1;
      U8 *oname = old_tree_content + opos; opos += onlen;
      opos += 1; // child_type
      U8 *ohash = old_tree_content + opos; opos += 64;
      opos += 8; // entity_id

      U8 dummy_type;
      U8 dummy_hash[64];
      U64 dummy_entity_id;
      Bool found_in_new = TreeFindEntry(new_tree_content, new_tree_content_len,
                                        oname, onlen, &dummy_type, dummy_hash, &dummy_entity_id);
      if (!found_in_new) {
        I64 dcap = onlen; if (dcap > 254) dcap = 254;
        for (i=0; i<dcap; i++) del_names[del_count*256+i] = oname[i];
        del_names[del_count*256+dcap] = 0;
        for (i=0; i<64; i++) del_hashes[del_count*64+i] = ohash[i];
        del_matched[del_count] = FALSE;
        del_count++;
      }
    }
  }

  // Rename pass 1: exact content match, same "first match wins"
  // simplification every other rename check in this project documents.
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

  CommPrint(1, "DIFF_END\n");

  Free(idx_hashes);
  Free(idx_offsets);
  Free(new_names);
  Free(new_hashes);
  Free(new_matched);
  Free(del_names);
  Free(del_hashes);
  Free(del_matched);
}

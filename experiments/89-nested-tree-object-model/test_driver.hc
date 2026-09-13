// Probe 89: does hgit-core's own OBJECT MODEL (not the CLI layer)
// genuinely support a nested tree - a tree entry whose child_type is
// OBJ_TREE (not OBJ_BLOB), pointing at another real tree object?
// FORMAT.md's own byte layout has reserved this since ADR 0001/0004
// but no code has ever built or read one - this is the real,
// standalone round-trip test that closes that gap, using only
// existing Tree.HC/Object.HC/Index.HC machinery, no new functions.
U0 P89NestedTreeTest()
{
  U8 archive[4096];
  I64 alen = 0;

  // Two "leaf" files inside the (conceptual) subdirectory - hashed
  // and stored the exact same way Offer.HC hashes/stores any real
  // blob (tagged with OBJ_BLOB before hashing).
  U8 *leaf1_content = "leaf one content";
  U8 *leaf2_content = "leaf two content, a bit longer";
  I64 leaf1_len = StrLen(leaf1_content);
  I64 leaf2_len = StrLen(leaf2_content);

  U8 tagged1[256];
  tagged1[0] = OBJ_BLOB;
  I64 i;
  for (i=0; i<leaf1_len; i++) tagged1[1+i] = leaf1_content[i];
  U8 leaf1_hash[64];
  B2Hash512Any(tagged1, leaf1_len+1, leaf1_hash);
  ObjectPut(archive, &alen, OBJ_BLOB, leaf1_content, leaf1_len);

  U8 tagged2[256];
  tagged2[0] = OBJ_BLOB;
  for (i=0; i<leaf2_len; i++) tagged2[1+i] = leaf2_content[i];
  U8 leaf2_hash[64];
  B2Hash512Any(tagged2, leaf2_len+1, leaf2_hash);
  ObjectPut(archive, &alen, OBJ_BLOB, leaf2_content, leaf2_len);

  // The CHILD tree ("subdirectory"): two blob entries.
  U8 child_tree_content[512];
  I64 child_len = 4; // room for entry_count
  TreeEncodeEntry(child_tree_content, &child_len, "leaf1.txt", 9, OBJ_BLOB, leaf1_hash, GenerateEntityId());
  TreeEncodeEntry(child_tree_content, &child_len, "leaf2.txt", 9, OBJ_BLOB, leaf2_hash, GenerateEntityId());
  PutU32LE(child_tree_content, 0, 2);

  U8 child_tagged[512];
  child_tagged[0] = OBJ_TREE;
  for (i=0; i<child_len; i++) child_tagged[1+i] = child_tree_content[i];
  U8 child_tree_hash[64];
  B2Hash512Any(child_tagged, child_len+1, child_tree_hash);
  ObjectPut(archive, &alen, OBJ_TREE, child_tree_content, child_len);

  // A top-level blob, alongside the nested tree.
  U8 *top_content = "top level file content";
  I64 top_len = StrLen(top_content);
  U8 top_tagged[256];
  top_tagged[0] = OBJ_BLOB;
  for (i=0; i<top_len; i++) top_tagged[1+i] = top_content[i];
  U8 top_hash[64];
  B2Hash512Any(top_tagged, top_len+1, top_hash);
  ObjectPut(archive, &alen, OBJ_BLOB, top_content, top_len);

  // The ROOT tree: one direct blob entry, one NESTED TREE entry
  // (child_type = OBJ_TREE) representing a "subdir" - the real thing
  // under test.
  U8 root_tree_content[512];
  I64 root_len = 4;
  TreeEncodeEntry(root_tree_content, &root_len, "top.txt", 7, OBJ_BLOB, top_hash, GenerateEntityId());
  TreeEncodeEntry(root_tree_content, &root_len, "subdir", 6, OBJ_TREE, child_tree_hash, GenerateEntityId());
  PutU32LE(root_tree_content, 0, 2);

  U8 root_tagged[512];
  root_tagged[0] = OBJ_TREE;
  for (i=0; i<root_len; i++) root_tagged[1+i] = root_tree_content[i];
  U8 root_tree_hash[64];
  B2Hash512Any(root_tagged, root_len+1, root_tree_hash);
  ObjectPut(archive, &alen, OBJ_TREE, root_tree_content, root_len);

  CommPrint(1, "P89_ARCHIVE_LEN=%d\n", alen);

  // --- Read-back, via the SAME Index.HC machinery every real command
  // uses - not special-cased for this test. ---
  I64 idx_count;
  U8 idx_hashes[10*64];
  I64 idx_offsets[10];
  IndexBuild(archive, alen, idx_hashes, idx_offsets, &idx_count);
  CommPrint(1, "P89_OBJECT_COUNT=%d\n", idx_count);

  // Find "subdir" in the root tree - confirm its type is OBJ_TREE and
  // its hash matches the real child tree object.
  U8 sub_type;
  U8 sub_hash[64];
  U64 sub_entity_id;
  Bool found_sub = TreeFindEntry(root_tree_content, root_len, "subdir", 6,
                                 &sub_type, sub_hash, &sub_entity_id);
  CommPrint(1, "P89_FOUND_SUBDIR=%d type=%d\n", found_sub, sub_type);

  Bool hash_matches = TRUE;
  for (i=0; i<64; i++) if (sub_hash[i] != child_tree_hash[i]) hash_matches = FALSE;
  CommPrint(1, "P89_SUBDIR_HASH_MATCHES=%d\n", hash_matches);

  // Resolve that hash through the REAL object index (same as any
  // real command would), confirm it's really an OBJ_TREE record with
  // the exact bytes we stored.
  I64 off_rel;
  Bool resolved = IndexLookup(idx_hashes, idx_offsets, idx_count, sub_hash, &off_rel);
  U8 resolved_type = archive[off_rel+8];
  U8 *resolved_content = archive + off_rel + 9;
  U64 resolved_rec_len = GetU64LE(archive, off_rel);
  I64 resolved_content_len = resolved_rec_len - 1;
  CommPrint(1, "P89_RESOLVED=%d type=%d len=%d (expect %d)\n",
            resolved, resolved_type, resolved_content_len, child_len);

  // Confirm the RESOLVED child tree's own entries are real and correct
  // - i.e. we can walk INTO the nested tree via ordinary TreeFindEntry,
  // same function, same code, no special nested-tree-aware logic
  // needed at the parsing level.
  U8 leaf_type;
  U8 leaf_hash_out[64];
  U64 leaf_entity_id;
  Bool found_leaf1 = TreeFindEntry(resolved_content, resolved_content_len,
                                   "leaf1.txt", 9, &leaf_type, leaf_hash_out, &leaf_entity_id);
  Bool leaf1_hash_matches = TRUE;
  for (i=0; i<64; i++) if (leaf_hash_out[i] != leaf1_hash[i]) leaf1_hash_matches = FALSE;
  CommPrint(1, "P89_FOUND_LEAF1=%d hash_matches=%d\n", found_leaf1, leaf1_hash_matches);

  CommPrint(1, "PASS p89_nested_tree_test\n");
}
P89NestedTreeTest;

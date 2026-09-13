// Probe 90 test driver: TreeBuildRecursive - a standalone recursive
// tree-building primitive (ADR 0010), NOT wired into hgit offer's own
// dispatch. Builds a real nested directory structure on disk, builds
// a tree from it (root commit - no old tree), then edits one nested
// file and rebuilds AGAINST the first build's own tree, confirming
// entity IDs carry forward correctly at every directory level.
U0 P90RecursiveTreeTest()
{
  DirMk("C:/Home/P90Root");
  DirMk("C:/Home/P90Root/SubA");
  DirMk("C:/Home/P90Root/SubA/SubAA");
  FileWrite("C:/Home/P90Root/top.txt", "top level content", 18);
  FileWrite("C:/Home/P90Root/SubA/a1.txt", "version one", 11);
  FileWrite("C:/Home/P90Root/SubA/SubAA/deep.txt", "deeply nested content", 22);

  // A real .HGS header prefix, matching every real caller's own
  // convention exactly - TreeBuildRecursive's internal offset math
  // (`16 + off_rel`) assumes `rbuf` is a real archive with this
  // 16-byte header before the object section, same as every other
  // real command's own rbuf (from a real FileRead). A first version
  // of this test skipped the header (objects starting at position 0),
  // which caused every internal offset resolution inside
  // TreeBuildRecursive to read 16 bytes into the wrong place - garbage
  // interpreted as a record length, which hung the shared dev daemon
  // in a runaway loop. Real bug, logged in
  // docs/research/failed-approaches.md.
  U8 archive1[8192];
  HgsWriteHeader(archive1, 1, 0);
  I64 alen1 = 16;
  U8 root_tree1[2048];
  I64 root_tree1_len;
  TreeBuildRecursive("C:/Home/P90Root/", archive1, &alen1, NULL, NULL, NULL, 0,
                     NULL, 0, root_tree1, &root_tree1_len);

  CommPrint(1, "P90_BUILD1_ALEN=%d ROOT_LEN=%d\n", alen1, root_tree1_len);

  U8 top_type, suba_type;
  U8 top_hash[64], suba_hash[64];
  U64 top_entity1, suba_entity1;
  Bool found_top1 = TreeFindEntry(root_tree1, root_tree1_len, "top.txt", 7, &top_type, top_hash, &top_entity1);
  Bool found_suba1 = TreeFindEntry(root_tree1, root_tree1_len, "SubA", 4, &suba_type, suba_hash, &suba_entity1);
  CommPrint(1, "P90_B1_TOP found=%d type=%d\n", found_top1, top_type);
  CommPrint(1, "P90_B1_SUBA found=%d type=%d\n", found_suba1, suba_type);

  // Resolve SubA's own tree content directly from the archive (same
  // technique any real command already uses) - idx_offsets are
  // relative to archive1+16 (the object section), matching every
  // real command's own "Index offsets are relative to..." convention.
  I64 idx_count1;
  U8 idx_hashes1[20*64];
  I64 idx_offsets1[20];
  IndexBuild(archive1+16, alen1-16, idx_hashes1, idx_offsets1, &idx_count1);
  I64 suba_off_rel1;
  Bool suba_resolved1 = IndexLookup(idx_hashes1, idx_offsets1, idx_count1, suba_hash, &suba_off_rel1);
  I64 suba_off1 = 16 + suba_off_rel1;
  U8 *suba_content1 = archive1 + suba_off1 + 9;
  U64 suba_rec_len1 = GetU64LE(archive1, suba_off1);
  I64 suba_content_len1 = suba_rec_len1 - 1;

  U8 a1_type, subaa_type;
  U8 a1_hash[64], subaa_hash[64];
  U64 a1_entity1, subaa_entity1;
  Bool found_a1_1 = TreeFindEntry(suba_content1, suba_content_len1, "a1.txt", 6, &a1_type, a1_hash, &a1_entity1);
  Bool found_subaa1 = TreeFindEntry(suba_content1, suba_content_len1, "SubAA", 5, &subaa_type, subaa_hash, &subaa_entity1);
  CommPrint(1, "P90_B1_A1 found=%d type=%d\n", found_a1_1, a1_type);
  CommPrint(1, "P90_B1_SUBAA found=%d type=%d\n", found_subaa1, subaa_type);

  I64 subaa_off_rel1;
  Bool subaa_resolved1 = IndexLookup(idx_hashes1, idx_offsets1, idx_count1, subaa_hash, &subaa_off_rel1);
  I64 subaa_off1 = 16 + subaa_off_rel1;
  U8 *subaa_content1 = archive1 + subaa_off1 + 9;
  U64 subaa_rec_len1 = GetU64LE(archive1, subaa_off1);
  I64 subaa_content_len1 = subaa_rec_len1 - 1;

  U8 deep_type;
  U8 deep_hash[64];
  U64 deep_entity1;
  Bool found_deep1 = TreeFindEntry(subaa_content1, subaa_content_len1, "deep.txt", 8, &deep_type, deep_hash, &deep_entity1);
  CommPrint(1, "P90_B1_DEEP found=%d type=%d\n", found_deep1, deep_type);

  // --- Second build: edit the DEEPLY NESTED file only, rebuild
  // against the FIRST build's own root tree as "old". ---
  FileWrite("C:/Home/P90Root/SubA/SubAA/deep.txt", "deeply nested content, EDITED", 30);

  U8 archive2[8192];
  HgsWriteHeader(archive2, 1, 0);
  I64 alen2 = 16;
  U8 root_tree2[2048];
  I64 root_tree2_len;
  TreeBuildRecursive("C:/Home/P90Root/", archive2, &alen2, archive1, idx_hashes1, idx_offsets1, idx_count1,
                     root_tree1, root_tree1_len, root_tree2, &root_tree2_len);

  U8 top_type2, suba_type2;
  U8 top_hash2[64], suba_hash2[64];
  U64 top_entity2, suba_entity2;
  TreeFindEntry(root_tree2, root_tree2_len, "top.txt", 7, &top_type2, top_hash2, &top_entity2);
  TreeFindEntry(root_tree2, root_tree2_len, "SubA", 4, &suba_type2, suba_hash2, &suba_entity2);
  CommPrint(1, "P90_B2_TOP_ID_SAME=%d\n", top_entity1 == top_entity2);
  CommPrint(1, "P90_B2_SUBA_ID_SAME=%d\n", suba_entity1 == suba_entity2);

  I64 idx_count2;
  U8 idx_hashes2[20*64];
  I64 idx_offsets2[20];
  IndexBuild(archive2+16, alen2-16, idx_hashes2, idx_offsets2, &idx_count2);
  I64 suba_off_rel2;
  IndexLookup(idx_hashes2, idx_offsets2, idx_count2, suba_hash2, &suba_off_rel2);
  I64 suba_off2 = 16 + suba_off_rel2;
  U8 *suba_content2 = archive2 + suba_off2 + 9;
  U64 suba_rec_len2 = GetU64LE(archive2, suba_off2);
  I64 suba_content_len2 = suba_rec_len2 - 1;

  U8 a1_type2, subaa_type2;
  U8 a1_hash2[64], subaa_hash2[64];
  U64 a1_entity2, subaa_entity2;
  TreeFindEntry(suba_content2, suba_content_len2, "a1.txt", 6, &a1_type2, a1_hash2, &a1_entity2);
  TreeFindEntry(suba_content2, suba_content_len2, "SubAA", 5, &subaa_type2, subaa_hash2, &subaa_entity2);
  CommPrint(1, "P90_B2_A1_ID_SAME=%d\n", a1_entity1 == a1_entity2);
  CommPrint(1, "P90_B2_SUBAA_ID_SAME=%d\n", subaa_entity1 == subaa_entity2);

  I64 subaa_off_rel2;
  IndexLookup(idx_hashes2, idx_offsets2, idx_count2, subaa_hash2, &subaa_off_rel2);
  I64 subaa_off2 = 16 + subaa_off_rel2;
  U8 *subaa_content2 = archive2 + subaa_off2 + 9;
  U64 subaa_rec_len2 = GetU64LE(archive2, subaa_off2);
  I64 subaa_content_len2 = subaa_rec_len2 - 1;

  U8 deep_type2;
  U8 deep_hash2[64];
  U64 deep_entity2;
  TreeFindEntry(subaa_content2, subaa_content_len2, "deep.txt", 8, &deep_type2, deep_hash2, &deep_entity2);
  CommPrint(1, "P90_B2_DEEP_ID_SAME=%d (expect 1 - same name, edited content, ADR 0004 by-name carry)\n",
            deep_entity1 == deep_entity2);

  Bool deep_hash_changed = FALSE;
  I64 hi;
  for (hi=0; hi<64; hi++) if (deep_hash[hi] != deep_hash2[hi]) deep_hash_changed = TRUE;
  CommPrint(1, "P90_B2_DEEP_HASH_CHANGED=%d (expect 1 - content really did change)\n", deep_hash_changed);

  CommPrint(1, "PASS p90_recursive_tree_test\n");
}
P90RecursiveTreeTest;

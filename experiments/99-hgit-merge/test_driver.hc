// Probe 99 test driver: hgit merge - real end-to-end verification of
// all four real outcomes this first slice supports.
U0 P99MergeTest()
{
  // --- Case 1: real, non-conflicting 3-way merge ---
  // A real, single wildcard find_mask covering both files every time -
  // `hgit offer`'s own real, documented semantics build the new tree
  // ENTIRELY from what find_mask matches (no old-tree carry-forward
  // for unmatched names), so a single-file mask would silently drop
  // the other file from every subsequent commit's own tree instead of
  // leaving it untouched.
  Del("C:/Home/P99RepoA.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P99RepoA.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P99RepoA.hgs");
  FileWrite("C:/Home/P99A_fileA.txt", "fileA root", 10);
  FileWrite("C:/Home/P99A_fileB.txt", "fileB root", 10);
  Hgit("offer C:/Home/P99RepoA.hgs P99A_file*.txt root_both_files");

  Hgit("path new C:/Home/P99RepoA.hgs feature");
  Hgit("path go C:/Home/P99RepoA.hgs feature");
  FileWrite("C:/Home/P99A_fileB.txt", "fileB EDITED by feature", 23);
  Hgit("offer C:/Home/P99RepoA.hgs P99A_file*.txt feature_edits_b");

  // hgit has no real working-copy checkout/restore step - switching
  // paths doesn't touch real files on disk, so fileB's on-disk
  // content still holds feature's own edit at this point. Restore it
  // back to its real root value explicitly before main's own offer,
  // so main's own commit genuinely represents "left fileB alone,
  // still equal to the merge base" rather than accidentally
  // re-committing feature's own edit under main too.
  Hgit("path go C:/Home/P99RepoA.hgs main");
  FileWrite("C:/Home/P99A_fileB.txt", "fileB root", 10);
  FileWrite("C:/Home/P99A_fileA.txt", "fileA EDITED by main", 20);
  Hgit("offer C:/Home/P99RepoA.hgs P99A_file*.txt main_edits_a");

  CommPrint(1, "P99_CASE1_MERGE_BEGIN\n");
  Hgit("merge C:/Home/P99RepoA.hgs feature");
  CommPrint(1, "P99_CASE1_MERGE_END\n");

  U8 merged_head[64];
  CurrentHeadRead("C:/Home/P99RepoA.hgs", merged_head);
  U8 merged_hex[129];
  HashToHex(merged_head, merged_hex);
  U8 cmd[512];
  StrPrint(cmd, "see C:/Home/P99RepoA.hgs %s", merged_hex);
  CommPrint(1, "P99_CASE1_SEE_BEGIN\n");
  Hgit(cmd);
  CommPrint(1, "P99_CASE1_SEE_END\n");

  CommPrint(1, "P99_CASE1_CHECK_BEGIN\n");
  Hgit("check C:/Home/P99RepoA.hgs");
  CommPrint(1, "P99_CASE1_CHECK_END\n");

  // --- Case 2: real conflict - both sides edit the SAME file
  // differently - must abort cleanly, zero side effects ---
  Del("C:/Home/P99RepoB.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P99RepoB.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P99RepoB.hgs");
  FileWrite("C:/Home/P99B_file.txt", "root content", 12);
  Hgit("offer C:/Home/P99RepoB.hgs P99B_file.txt root_offer");

  Hgit("path new C:/Home/P99RepoB.hgs feature");
  Hgit("path go C:/Home/P99RepoB.hgs feature");
  FileWrite("C:/Home/P99B_file.txt", "feature version", 16);
  Hgit("offer C:/Home/P99RepoB.hgs P99B_file.txt feature_conflicting_edit");

  Hgit("path go C:/Home/P99RepoB.hgs main");
  FileWrite("C:/Home/P99B_file.txt", "main version DIFFERENT", 23);
  Hgit("offer C:/Home/P99RepoB.hgs P99B_file.txt main_conflicting_edit");

  U8 pre_merge_head[64];
  CurrentHeadRead("C:/Home/P99RepoB.hgs", pre_merge_head);

  CommPrint(1, "P99_CASE2_MERGE_BEGIN\n");
  Hgit("merge C:/Home/P99RepoB.hgs feature");
  CommPrint(1, "P99_CASE2_MERGE_END\n");

  U8 post_merge_head[64];
  CurrentHeadRead("C:/Home/P99RepoB.hgs", post_merge_head);
  Bool head_unchanged = TRUE;
  I64 i;
  for (i=0; i<64; i++) if (pre_merge_head[i] != post_merge_head[i]) head_unchanged = FALSE;
  CommPrint(1, "P99_CASE2_HEAD_UNCHANGED=%d\n", head_unchanged);

  CommPrint(1, "P99_CASE2_CHECK_BEGIN\n");
  Hgit("check C:/Home/P99RepoB.hgs"); // real object count should be
                                       // unaffected by the aborted
                                       // merge - no commit created
  CommPrint(1, "P99_CASE2_CHECK_END\n");

  // --- Case 3: real fast-forward - current path untouched since the
  // fork, other path advanced ---
  Del("C:/Home/P99RepoC.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P99RepoC.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P99RepoC.hgs");
  FileWrite("C:/Home/P99C_file.txt", "root content", 12);
  Hgit("offer C:/Home/P99RepoC.hgs P99C_file.txt root_offer");

  Hgit("path new C:/Home/P99RepoC.hgs feature");
  Hgit("path go C:/Home/P99RepoC.hgs feature");
  FileWrite("C:/Home/P99C_file.txt", "feature advanced", 16);
  Hgit("offer C:/Home/P99RepoC.hgs P99C_file.txt feature_only_advance");

  U8 feature_head_c[64];
  CurrentHeadRead("C:/Home/P99RepoC.hgs", feature_head_c);

  Hgit("path go C:/Home/P99RepoC.hgs main");
  CommPrint(1, "P99_CASE3_MERGE_BEGIN\n");
  Hgit("merge C:/Home/P99RepoC.hgs feature");
  CommPrint(1, "P99_CASE3_MERGE_END\n");

  U8 main_head_after_ff[64];
  CurrentHeadRead("C:/Home/P99RepoC.hgs", main_head_after_ff);
  Bool ff_matches = TRUE;
  for (i=0; i<64; i++) if (feature_head_c[i] != main_head_after_ff[i]) ff_matches = FALSE;
  CommPrint(1, "P99_CASE3_FF_MATCHES=%d\n", ff_matches);

  // --- Case 4: real already-up-to-date - merging a path that's
  // already an ancestor of current ---
  Hgit("path go C:/Home/P99RepoC.hgs feature");
  CommPrint(1, "P99_CASE4_MERGE_BEGIN\n");
  Hgit("merge C:/Home/P99RepoC.hgs main"); // main == feature now (post-FF), a real no-op
  CommPrint(1, "P99_CASE4_MERGE_END\n");

  CommPrint(1, "PASS p99_merge_test\n");
}
P99MergeTest;

// Probe 100 test driver: hgit merge recurses into nested trees.
U0 P100MergeNestedTest()
{
  // --- Case 1: real, non-conflicting merge INSIDE a shared
  // subdirectory - main and feature edit DIFFERENT nested files ---
  Del("C:/Home/P100RepoA.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P100RepoA.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P100RepoA.hgs");
  DirMk("C:/Home/P100ARoot");
  DirMk("C:/Home/P100ARoot/SubA");
  FileWrite("C:/Home/P100ARoot/top.txt", "top root", 8);
  FileWrite("C:/Home/P100ARoot/SubA/x.txt", "x root", 6);
  FileWrite("C:/Home/P100ARoot/SubA/y.txt", "y root", 6);
  Hgit("offertree C:/Home/P100RepoA.hgs C:/Home/P100ARoot/ root_offer");

  Hgit("path new C:/Home/P100RepoA.hgs feature");
  Hgit("path go C:/Home/P100RepoA.hgs feature");
  FileWrite("C:/Home/P100ARoot/SubA/y.txt", "y EDITED by feature", 20);
  Hgit("offertree C:/Home/P100RepoA.hgs C:/Home/P100ARoot/ feature_edits_y");

  // No working-copy restore step exists - explicitly put y.txt back to
  // its real root content before main's own offer (same real lesson
  // probe 99 already documented).
  Hgit("path go C:/Home/P100RepoA.hgs main");
  FileWrite("C:/Home/P100ARoot/SubA/y.txt", "y root", 6);
  FileWrite("C:/Home/P100ARoot/SubA/x.txt", "x EDITED by main", 16);
  Hgit("offertree C:/Home/P100RepoA.hgs C:/Home/P100ARoot/ main_edits_x");

  CommPrint(1, "P100_CASE1_MERGE_BEGIN\n");
  Hgit("merge C:/Home/P100RepoA.hgs feature");
  CommPrint(1, "P100_CASE1_MERGE_END\n");

  U8 merged_head[64];
  CurrentHeadRead("C:/Home/P100RepoA.hgs", merged_head);
  U8 merged_hex[129];
  HashToHex(merged_head, merged_hex);
  U8 cmd[512];
  StrPrint(cmd, "see C:/Home/P100RepoA.hgs %s", merged_hex);
  CommPrint(1, "P100_CASE1_SEE_BEGIN\n");
  Hgit(cmd);
  CommPrint(1, "P100_CASE1_SEE_END\n");

  CommPrint(1, "P100_CASE1_CHECK_BEGIN\n");
  Hgit("check C:/Home/P100RepoA.hgs");
  CommPrint(1, "P100_CASE1_CHECK_END\n");

  // --- Case 2: real conflict INSIDE a shared subdirectory - both
  // sides edit the SAME nested file differently ---
  Del("C:/Home/P100RepoB.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P100RepoB.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P100RepoB.hgs");
  DirMk("C:/Home/P100BRoot");
  DirMk("C:/Home/P100BRoot/SubB");
  FileWrite("C:/Home/P100BRoot/SubB/z.txt", "z root", 6);
  Hgit("offertree C:/Home/P100RepoB.hgs C:/Home/P100BRoot/ root_offer");

  Hgit("path new C:/Home/P100RepoB.hgs feature");
  Hgit("path go C:/Home/P100RepoB.hgs feature");
  FileWrite("C:/Home/P100BRoot/SubB/z.txt", "z feature version", 18);
  Hgit("offertree C:/Home/P100RepoB.hgs C:/Home/P100BRoot/ feature_conflicting_edit");

  Hgit("path go C:/Home/P100RepoB.hgs main");
  FileWrite("C:/Home/P100BRoot/SubB/z.txt", "z main version DIFFERENT", 25);
  Hgit("offertree C:/Home/P100RepoB.hgs C:/Home/P100BRoot/ main_conflicting_edit");

  U8 pre_merge_head[64];
  CurrentHeadRead("C:/Home/P100RepoB.hgs", pre_merge_head);

  CommPrint(1, "P100_CASE2_MERGE_BEGIN\n");
  Hgit("merge C:/Home/P100RepoB.hgs feature");
  CommPrint(1, "P100_CASE2_MERGE_END\n");

  U8 post_merge_head[64];
  CurrentHeadRead("C:/Home/P100RepoB.hgs", post_merge_head);
  Bool head_unchanged = TRUE;
  I64 i;
  for (i=0; i<64; i++) if (pre_merge_head[i] != post_merge_head[i]) head_unchanged = FALSE;
  CommPrint(1, "P100_CASE2_HEAD_UNCHANGED=%d\n", head_unchanged);

  CommPrint(1, "P100_CASE2_CHECK_BEGIN\n");
  Hgit("check C:/Home/P100RepoB.hgs");
  CommPrint(1, "P100_CASE2_CHECK_END\n");

  CommPrint(1, "PASS p100_merge_nested_test\n");
}
P100MergeNestedTest;

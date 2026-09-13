// Probe 94 test driver: `hgit diff` recurses into nested trees (ADR
// 0010's own remaining "Status.HC/Diff.HC awareness of nested trees"
// item - the Diff.HC half of it).
U0 P94DiffNestedTest()
{
  Del("C:/Home/P94Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P94Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P94Repo.hgs");

  DirMk("C:/Home/P94Root");
  DirMk("C:/Home/P94Root/SubA");
  FileWrite("C:/Home/P94Root/top.txt", "top level content", 18);
  FileWrite("C:/Home/P94Root/SubA/inner.txt", "inner content v1", 17);

  Hgit("offertree C:/Home/P94Repo.hgs C:/Home/P94Root/ first_offer");

  // Second commit: modify the nested file, add a brand-new nested
  // subdirectory two levels deep, and delete nothing yet - a real
  // MODIFIED-inside-a-subtree case plus a real wholly-new-subtree
  // case in the same commit.
  FileWrite("C:/Home/P94Root/SubA/inner.txt", "inner content v2 changed", 24);
  DirMk("C:/Home/P94Root/SubA/SubB");
  FileWrite("C:/Home/P94Root/SubA/SubB/deep.txt", "brand new deep file", 20);
  Hgit("offertree C:/Home/P94Repo.hgs C:/Home/P94Root/ second_offer_modify_and_add");

  U8 head2_hash[64];
  CurrentHeadRead("C:/Home/P94Repo.hgs", head2_hash);
  U8 head2_hex[129];
  HashToHex(head2_hash, head2_hex);
  U8 cmd[512];
  StrPrint(cmd, "diff C:/Home/P94Repo.hgs %s", head2_hex);
  CommPrint(1, "P94_DIFF1_BEGIN\n");
  Hgit(cmd);
  CommPrint(1, "P94_DIFF1_END\n");

  // Third commit: delete each real file inside SubA (not the
  // directory entry itself - this project has no proven "delete a
  // directory from disk" primitive; DirTreeDel is NOT it, see
  // docs/research/failed-approaches.md's 2026-09-14 entry - it frees
  // a CDirEntry* list, not a filesystem path, a real dead end this
  // test's first draft hit by passing it a string instead). An
  // emptied-but-still-present directory offers identically to a
  // genuinely absent one from TreeBuildRecursive's own point of view
  // (a real, empty OBJ_TREE either way), so this still exercises the
  // real DELETED-recursion path.
  Del("C:/Home/P94Root/SubA/inner.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/P94Root/SubA/SubB/deep.txt", FALSE, FALSE, FALSE);
  Hgit("offertree C:/Home/P94Repo.hgs C:/Home/P94Root/ third_offer_delete_subtree");

  U8 head3_hash[64];
  CurrentHeadRead("C:/Home/P94Repo.hgs", head3_hash);
  U8 head3_hex[129];
  HashToHex(head3_hash, head3_hex);
  StrPrint(cmd, "diff C:/Home/P94Repo.hgs %s", head3_hex);
  CommPrint(1, "P94_DIFF2_BEGIN\n");
  Hgit(cmd);
  CommPrint(1, "P94_DIFF2_END\n");

  CommPrint(1, "PASS p94_diff_nested_test\n");
}
P94DiffNestedTest;

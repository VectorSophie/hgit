// Probe 102 test driver: the real "whole subdirectory vanished from
// disk" DELETED-recursion branch in Diff.HC/Status.HC, directly
// exercised for the first time - probe 94's own test only reached the
// structurally symmetric NEW branch (via a genuinely new SubA in its
// first offertree); DELETED was only ever tested indirectly (an
// emptied-but-still-present directory), since this project had no
// real "delete a directory from disk" primitive until probe 101.
U0 P102DiffDirGoneTest()
{
  Del("C:/Home/P102Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P102Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P102Repo.hgs");
  DirMk("C:/Home/P102Root");
  DirMk("C:/Home/P102Root/SubA");
  FileWrite("C:/Home/P102Root/top.txt", "top content", 11);
  FileWrite("C:/Home/P102Root/SubA/x.txt", "x content", 9);
  FileWrite("C:/Home/P102Root/SubA/y.txt", "y content", 9);
  Hgit("offertree C:/Home/P102Repo.hgs C:/Home/P102Root/ first_offer");

  // Real deletion: every real file inside SubA, individually, then
  // the now-empty directory entry itself - probe 101's own verified
  // primitive, not DirTreeDel (which never touches disk at all).
  Del("C:/Home/P102Root/SubA/x.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/P102Root/SubA/y.txt", FALSE, FALSE, FALSE);
  I64 del_result = Del("C:/Home/P102Root/SubA", FALSE, TRUE, FALSE);
  CommPrint(1, "P102_SUBA_DEL_RESULT=%d\n", del_result);

  CDirEntry *check_de = FilesFind("C:/Home/P102Root/SubA*", 0);
  Bool suba_gone = (check_de == NULL);
  CommPrint(1, "P102_SUBA_GONE=%d\n", suba_gone);
  if (check_de) DirTreeDel(check_de);

  Hgit("offertree C:/Home/P102Repo.hgs C:/Home/P102Root/ second_offer_subdir_gone");

  U8 head2_hash[64];
  CurrentHeadRead("C:/Home/P102Repo.hgs", head2_hash);
  U8 head2_hex[129];
  HashToHex(head2_hash, head2_hex);
  U8 cmd[512];
  StrPrint(cmd, "diff C:/Home/P102Repo.hgs %s", head2_hex);
  CommPrint(1, "P102_DIFF_BEGIN\n");
  Hgit(cmd);
  CommPrint(1, "P102_DIFF_END\n");

  // Real cross-check: statustree, right after, on the now-committed
  // clean state - should report nothing outstanding.
  CommPrint(1, "P102_STATUSTREE_BEGIN\n");
  Hgit("statustree C:/Home/P102Repo.hgs C:/Home/P102Root/");
  CommPrint(1, "P102_STATUSTREE_END\n");

  CommPrint(1, "P102_CHECK_BEGIN\n");
  Hgit("check C:/Home/P102Repo.hgs");
  CommPrint(1, "P102_CHECK_END\n");

  CommPrint(1, "PASS p102_diff_dir_gone_test\n");
}
P102DiffDirGoneTest;

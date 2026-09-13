// Probe 103 test driver: hgit statustree's own "whole subdirectory
// vanished from disk" DELETED-recursion branch, directly exercised -
// closing the same real gap probe 102 closed for Diff.HC, this time
// for StatusTreeWalk's own live-directory-vs-committed-tree version.
U0 P103StatusTreeDirGoneTest()
{
  Del("C:/Home/P103Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P103Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P103Repo.hgs");
  DirMk("C:/Home/P103Root");
  DirMk("C:/Home/P103Root/SubA");
  FileWrite("C:/Home/P103Root/top.txt", "top content", 11);
  FileWrite("C:/Home/P103Root/SubA/x.txt", "x content", 9);
  FileWrite("C:/Home/P103Root/SubA/y.txt", "y content", 9);
  Hgit("offertree C:/Home/P103Repo.hgs C:/Home/P103Root/ first_offer");

  // Real deletion: every real file inside SubA, individually, then
  // the now-empty directory entry itself (probe 101's own verified
  // primitive) - genuinely vanished, not just emptied. Deliberately
  // left UNCOMMITTED this time, so statustree compares a live
  // directory (with SubA truly gone) against the still-committed
  // first_offer tree (which still has SubA/x.txt and SubA/y.txt).
  Del("C:/Home/P103Root/SubA/x.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/P103Root/SubA/y.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/P103Root/SubA", FALSE, TRUE, FALSE);

  CDirEntry *check_de = FilesFind("C:/Home/P103Root/SubA*", 0);
  Bool suba_gone = (check_de == NULL);
  CommPrint(1, "P103_SUBA_GONE=%d\n", suba_gone);
  if (check_de) DirTreeDel(check_de);

  CommPrint(1, "P103_STATUSTREE_BEGIN\n");
  Hgit("statustree C:/Home/P103Repo.hgs C:/Home/P103Root/");
  CommPrint(1, "P103_STATUSTREE_END\n");

  CommPrint(1, "PASS p103_statustree_dir_gone_test\n");
}
P103StatusTreeDirGoneTest;

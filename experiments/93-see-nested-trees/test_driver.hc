// Probe 93 test driver: `hgit see` recursing into nested trees (ADR
// 0010's own remaining doc item - "See.HC/HistoryDoc.HC/
// ReconcileDoc.HC/Graph.HC awareness of nested trees", closing the
// See.HC part of it).
U0 P93SeeNestedTest()
{
  Del("C:/Home/P93Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P93Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P93Repo.hgs");

  DirMk("C:/Home/P93Root");
  DirMk("C:/Home/P93Root/SubA");
  DirMk("C:/Home/P93Root/SubA/SubB");
  FileWrite("C:/Home/P93Root/top.txt", "top level content", 18);
  FileWrite("C:/Home/P93Root/SubA/mid.txt", "mid level content", 18);
  FileWrite("C:/Home/P93Root/SubA/SubB/deep.txt", "deep level content", 18);

  Hgit("offertree C:/Home/P93Repo.hgs C:/Home/P93Root/ two_levels_deep");

  U8 head_hash[64];
  CurrentHeadRead("C:/Home/P93Repo.hgs", head_hash);
  U8 head_hex[129];
  HashToHex(head_hash, head_hex);
  U8 cmd[512];
  StrPrint(cmd, "see C:/Home/P93Repo.hgs %s", head_hex);
  CommPrint(1, "P93_SEE_BEGIN\n");
  Hgit(cmd);
  CommPrint(1, "P93_SEE_END\n");

  CommPrint(1, "PASS p93_see_nested_test\n");
}
P93SeeNestedTest;

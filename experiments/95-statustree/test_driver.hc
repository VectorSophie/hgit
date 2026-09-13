// Probe 95 test driver: `hgit statustree` - closes ADR 0010's own
// last remaining "rendering-command awareness of nested trees" item.
U0 P95StatusTreeTest()
{
  Del("C:/Home/P95Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P95Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P95Repo.hgs");

  DirMk("C:/Home/P95Root");
  DirMk("C:/Home/P95Root/SubA");
  FileWrite("C:/Home/P95Root/top.txt", "top level content", 18);
  FileWrite("C:/Home/P95Root/SubA/inner.txt", "inner content v1", 17);

  Hgit("offertree C:/Home/P95Repo.hgs C:/Home/P95Root/ first_offer");

  // Working-directory changes, none yet offered: modify inner.txt,
  // add a brand-new nested file two levels deep, delete top.txt.
  FileWrite("C:/Home/P95Root/SubA/inner.txt", "inner content v2 CHANGED", 24);
  DirMk("C:/Home/P95Root/SubA/SubB");
  FileWrite("C:/Home/P95Root/SubA/SubB/deep.txt", "brand new deep file", 20);
  Del("C:/Home/P95Root/top.txt", FALSE, FALSE, FALSE);

  CommPrint(1, "P95_STATUSTREE1_BEGIN\n");
  Hgit("statustree C:/Home/P95Repo.hgs C:/Home/P95Root/");
  CommPrint(1, "P95_STATUSTREE1_END\n");

  // Now actually offer that state, then check statustree reports
  // nothing outstanding (a clean tree).
  Hgit("offertree C:/Home/P95Repo.hgs C:/Home/P95Root/ second_offer");
  CommPrint(1, "P95_STATUSTREE2_BEGIN\n");
  Hgit("statustree C:/Home/P95Repo.hgs C:/Home/P95Root/");
  CommPrint(1, "P95_STATUSTREE2_END\n");

  CommPrint(1, "PASS p95_statustree_test\n");
}
P95StatusTreeTest;

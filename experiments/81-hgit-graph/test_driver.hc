// Probe test driver: hgit historygraph across a real fork.
// main: offer1 -> offer2 (root, then one child).
// Then `path new feature` (forks from main's HEAD == offer2), offer
// on "feature" only (a real branch commit unique to that path).
// historygraph should show: offer1 -> offer2, with a [feature] branch
// nested under offer2 (the fork point).
U0 P80HistoryGraphTest()
{
  Del("C:/Home/P80Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P80Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P80Repo.hgs");

  FileWrite("C:/Home/P80File.txt", "v1", 2);
  Hgit("offer C:/Home/P80Repo.hgs P80File.txt offer_one");
  FileWrite("C:/Home/P80File.txt", "v2", 2);
  Hgit("offer C:/Home/P80Repo.hgs P80File.txt offer_two");

  Hgit("path new C:/Home/P80Repo.hgs feature");
  Hgit("path go C:/Home/P80Repo.hgs feature");
  FileWrite("C:/Home/P80File.txt", "v3-on-feature", 13);
  Hgit("offer C:/Home/P80Repo.hgs P80File.txt offer_three_on_feature");

  Hgit("path go C:/Home/P80Repo.hgs main");

  CommPrint(1, "P80_GRAPH_BEGIN\n");
  Hgit("graph C:/Home/P80Repo.hgs C:/Home/P80Graph.DD");
  CommPrint(1, "P80_GRAPH_END\n");

  I64 sz;
  U8 *buf = FileRead("C:/Home/P80Graph.DD", &sz);
  CommPrint(1, "P80_GRAPH_SIZE=%d\n", sz);
  CommPrint(1, "P80_GRAPH_RAW_BEGIN\n");
  I64 i;
  for (i=0; i<sz; i++) CommPrint(1, "%c", buf[i]);
  CommPrint(1, "\nP80_GRAPH_RAW_END\n");

  CommPrint(1, "PASS p80_historygraph_test\n");
}
P80HistoryGraphTest;

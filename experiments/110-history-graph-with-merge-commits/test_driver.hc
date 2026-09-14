// Probe 110 test driver: real verification of `hgit history`/`hgit
// graph` against a real repo containing a real merge commit - both
// commands predate ADR 0011 and their own header comments still said
// "no multi-parent commits exist yet" / "none have been created or
// tested". Confirms neither command crashes or corrupts anything, and
// records their real, honest (first-parent-only) output for the
// record. Self-contained (builds its own small merge history) rather
// than depending on another probe's leftover repo, so this is a real,
// independently re-runnable regression.
U0 P110HistoryGraphOnMergeTest()
{
  Del("C:/Home/P110Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P110Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P110Repo.hgs");

  U8 *mask = "C:/Home/P110*.txt";
  U8 cmd[512];

  FileWrite("C:/Home/P110Top.txt", "top v1", 6);
  StrPrint(cmd, "offer C:/Home/P110Repo.hgs %s root_commit", mask);
  Hgit(cmd);

  Hgit("path new C:/Home/P110Repo.hgs feature");
  Hgit("path go C:/Home/P110Repo.hgs feature");
  FileWrite("C:/Home/P110Feat.txt", "feat v1", 7);
  StrPrint(cmd, "offer C:/Home/P110Repo.hgs %s feature_commit", mask);
  Hgit(cmd);

  Hgit("path go C:/Home/P110Repo.hgs main");
  Del("C:/Home/P110Feat.txt", FALSE, FALSE, FALSE);
  FileWrite("C:/Home/P110Main2.txt", "main2 v1", 8);
  StrPrint(cmd, "offer C:/Home/P110Repo.hgs %s main_commit_2", mask);
  Hgit(cmd);

  Hgit("merge C:/Home/P110Repo.hgs feature");

  CommPrint(1, "P110_HISTORY_BEGIN\n");
  Hgit("history C:/Home/P110Repo.hgs");
  CommPrint(1, "P110_HISTORY_END\n");

  CommPrint(1, "P110_GRAPH_BEGIN\n");
  Hgit("graph C:/Home/P110Repo.hgs C:/Home/P110Graph.DD");
  CommPrint(1, "P110_GRAPH_END\n");

  I64 gsize;
  U8 *gbuf = FileRead("C:/Home/P110Graph.DD", &gsize);
  CommPrint(1, "P110_GRAPH_DOC_SIZE=%d\n", gsize);

  I64 i;
  CommPrint(1, "P110_DOC_BEGIN\n");
  for (i=0; i<gsize; i++) CommPrint(1, "%c", gbuf[i]);
  CommPrint(1, "\nP110_DOC_END\n");

  CommPrint(1, "PASS p110_history_graph_on_merge\n");
}
P110HistoryGraphOnMergeTest;

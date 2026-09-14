// Probe 115 test driver: `hgit operation restore <index>` had never
// been tested against a real merge commit either - the gap probe
// 114's own README explicitly flagged as separate and not covered.
// Structurally identical to OpLogUndo/OpLogRedo (per-current-path,
// jumps HEAD to a logged new_head by index, no inspection of a
// commit's own internals), so no bug is expected, but this closes the
// flagged gap with a real, direct test rather than an inference from
// a sibling function's own already-verified behavior.
U0 P115OperationRestoreToMergeTest()
{
  Del("C:/Home/P115Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P115Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P115Repo.hgs");

  U8 *mask = "C:/Home/P115*.txt";
  U8 cmd[512];

  FileWrite("C:/Home/P115Top.txt", "top v1", 6);
  StrPrint(cmd, "offer C:/Home/P115Repo.hgs %s root_commit", mask);
  Hgit(cmd); // op 0

  Hgit("path new C:/Home/P115Repo.hgs feature");
  Hgit("path go C:/Home/P115Repo.hgs feature");
  FileWrite("C:/Home/P115Feat.txt", "feat v1", 7);
  StrPrint(cmd, "offer C:/Home/P115Repo.hgs %s feature_commit", mask);
  Hgit(cmd);

  Hgit("path go C:/Home/P115Repo.hgs main");
  Del("C:/Home/P115Feat.txt", FALSE, FALSE, FALSE);
  FileWrite("C:/Home/P115Main2.txt", "main2 v1", 8);
  StrPrint(cmd, "offer C:/Home/P115Repo.hgs %s main_commit_2", mask);
  Hgit(cmd); // op 1 (on main's own path-scoped oplog)

  Hgit("merge C:/Home/P115Repo.hgs feature"); // op 2 (on main)
  U8 merge_head[64];
  CurrentHeadRead("C:/Home/P115Repo.hgs", merge_head);
  U8 merge_hex[129];
  HashToHex(merge_head, merge_hex);
  CommPrint(1, "P115_MERGE=%s\n", merge_hex);

  // Advance further so restoring to op 2 is a real jump backward, not
  // a no-op.
  FileWrite("C:/Home/P115Main3.txt", "main3 v1", 8);
  StrPrint(cmd, "offer C:/Home/P115Repo.hgs %s main_commit_3", mask);
  Hgit(cmd); // op 3

  CommPrint(1, "P115_OPHISTORY_BEGIN\n");
  Hgit("operation history C:/Home/P115Repo.hgs");
  CommPrint(1, "P115_OPHISTORY_END\n");

  Hgit("operation restore C:/Home/P115Repo.hgs 2");
  U8 after_restore_head[64];
  CurrentHeadRead("C:/Home/P115Repo.hgs", after_restore_head);
  U8 after_restore_hex[129];
  HashToHex(after_restore_head, after_restore_hex);
  CommPrint(1, "P115_AFTER_RESTORE=%s\n", after_restore_hex);

  CommPrint(1, "P115_CHECK_BEGIN\n");
  Hgit("check C:/Home/P115Repo.hgs");
  CommPrint(1, "P115_CHECK_END\n");

  CommPrint(1, "PASS p115_operation_restore_to_merge\n");
}
P115OperationRestoreToMergeTest;

// Probe 114 test driver: `hgit undo`/`hgit redo` had never been
// tested against a real merge commit. `OpLogUndo`/`OpLogRedo` are
// entirely per-CURRENT-path and don't inspect commit internals at
// all (just restore/reapply a logged prev_head/new_head pair) - a
// real merge commit is already logged the same way any other offer
// is (Merge.HC's own OpLogAppend calls) - but this was never directly
// exercised end to end until now.
U0 P114UndoRedoAfterMergeTest()
{
  Del("C:/Home/P114Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P114Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P114Repo.hgs");

  U8 *mask = "C:/Home/P114*.txt";
  U8 cmd[512];

  FileWrite("C:/Home/P114Top.txt", "top v1", 6);
  StrPrint(cmd, "offer C:/Home/P114Repo.hgs %s root_commit", mask);
  Hgit(cmd);

  Hgit("path new C:/Home/P114Repo.hgs feature");
  Hgit("path go C:/Home/P114Repo.hgs feature");
  FileWrite("C:/Home/P114Feat.txt", "feat v1", 7);
  StrPrint(cmd, "offer C:/Home/P114Repo.hgs %s feature_commit", mask);
  Hgit(cmd);
  U8 feature_head[64];
  CurrentHeadRead("C:/Home/P114Repo.hgs", feature_head);
  U8 feature_hex[129];
  HashToHex(feature_head, feature_hex);

  Hgit("path go C:/Home/P114Repo.hgs main");
  Del("C:/Home/P114Feat.txt", FALSE, FALSE, FALSE);
  FileWrite("C:/Home/P114Main2.txt", "main2 v1", 8);
  StrPrint(cmd, "offer C:/Home/P114Repo.hgs %s main_commit_2", mask);
  Hgit(cmd);
  U8 premerge_head[64];
  CurrentHeadRead("C:/Home/P114Repo.hgs", premerge_head);
  U8 premerge_hex[129];
  HashToHex(premerge_head, premerge_hex);

  Hgit("merge C:/Home/P114Repo.hgs feature");
  U8 merge_head[64];
  CurrentHeadRead("C:/Home/P114Repo.hgs", merge_head);
  U8 merge_hex[129];
  HashToHex(merge_head, merge_hex);

  CommPrint(1, "P114_PREMERGE=%s\n", premerge_hex);
  CommPrint(1, "P114_MERGE=%s\n", merge_hex);
  CommPrint(1, "P114_FEATURE=%s\n", feature_hex);

  CommPrint(1, "P114_CHECK_BEFORE_UNDO_BEGIN\n");
  Hgit("check C:/Home/P114Repo.hgs");
  CommPrint(1, "P114_CHECK_BEFORE_UNDO_END\n");

  // Undo the merge on main - should restore main's HEAD to its real
  // pre-merge commit. feature's own HEAD must be completely
  // unaffected (undo is scoped to the CURRENT path only).
  Hgit("undo C:/Home/P114Repo.hgs");
  U8 after_undo_head[64];
  CurrentHeadRead("C:/Home/P114Repo.hgs", after_undo_head);
  U8 after_undo_hex[129];
  HashToHex(after_undo_head, after_undo_hex);
  CommPrint(1, "P114_AFTER_UNDO=%s\n", after_undo_hex);

  Hgit("path go C:/Home/P114Repo.hgs feature");
  U8 feature_after_undo[64];
  CurrentHeadRead("C:/Home/P114Repo.hgs", feature_after_undo);
  U8 feature_after_undo_hex[129];
  HashToHex(feature_after_undo, feature_after_undo_hex);
  CommPrint(1, "P114_FEATURE_AFTER_UNDO=%s\n", feature_after_undo_hex);
  Hgit("path go C:/Home/P114Repo.hgs main");

  // The merge commit's own unique objects are now genuinely
  // unreachable (main no longer points to it, feature never did) -
  // real, expected, non-destructive-history behavior, same as any
  // other undo (probe 65's own regression).
  CommPrint(1, "P114_CHECK_AFTER_UNDO_BEGIN\n");
  Hgit("check C:/Home/P114Repo.hgs");
  CommPrint(1, "P114_CHECK_AFTER_UNDO_END\n");

  // Redo - should restore main's HEAD back to the real merge commit,
  // making those same objects reachable again.
  Hgit("redo C:/Home/P114Repo.hgs");
  U8 after_redo_head[64];
  CurrentHeadRead("C:/Home/P114Repo.hgs", after_redo_head);
  U8 after_redo_hex[129];
  HashToHex(after_redo_head, after_redo_hex);
  CommPrint(1, "P114_AFTER_REDO=%s\n", after_redo_hex);

  CommPrint(1, "P114_CHECK_AFTER_REDO_BEGIN\n");
  Hgit("check C:/Home/P114Repo.hgs");
  CommPrint(1, "P114_CHECK_AFTER_REDO_END\n");

  CommPrint(1, "PASS p114_undo_redo_after_merge\n");
}
P114UndoRedoAfterMergeTest;

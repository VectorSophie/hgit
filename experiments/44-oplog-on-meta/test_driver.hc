// probe 44 — OpLog.HC's public API now backed by Meta.HC's operation-
// log slice internally, completing ADR 0003's real-command cutover.
// Reuses probe 36's exact scenario (undo on "feature" only reverts
// feature's own HEAD, leaving main untouched; redo restores it; undo
// on "main" doesn't touch feature) plus probe 38's operation-restore
// scenario, both through the real Hgit(cmdline) dispatcher.

Hgit("init \"C:/Home/P44Repo.hgs\"");

U8 fa44[3]; fa44[0]='o';fa44[1]='n';fa44[2]='e';
FileWrite("C:/Home/P44FileA.txt", fa44, 3);
Hgit("offer \"C:/Home/P44Repo.hgs\" \"C:/Home/P44FileA*\" main commit 1");
U8 main_head_before_44[64];
MetaReadHead("C:/Home/P44Repo.hgs", "main", main_head_before_44);

Hgit("path new \"C:/Home/P44Repo.hgs\" feature");
Hgit("path go \"C:/Home/P44Repo.hgs\" feature");

U8 fa2_44[3]; fa2_44[0]='t';fa2_44[1]='w';fa2_44[2]='o';
FileWrite("C:/Home/P44FileA.txt", fa2_44, 3);
Hgit("offer \"C:/Home/P44Repo.hgs\" \"C:/Home/P44FileA*\" feature commit 1");
U8 feature_head_before_undo_44[64];
MetaReadHead("C:/Home/P44Repo.hgs", "feature", feature_head_before_undo_44);

// undo while on "feature" - should revert ONLY feature's HEAD.
Hgit("undo \"C:/Home/P44Repo.hgs\"");
U8 feature_head_after_undo_44[64];
MetaReadHead("C:/Home/P44Repo.hgs", "feature", feature_head_after_undo_44);
// undo must CHANGE the HEAD away from what it was right before undo
// (back to the previous commit) - so these must DIFFER, not match.
Bool feature_reverted = FALSE;
I64 k44;
for (k44=0;k44<64;k44++) if (feature_head_after_undo_44[k44]!=feature_head_before_undo_44[k44]) feature_reverted=TRUE;
CommPrint(1, "feature_reverted_by_own_undo=%d\n", feature_reverted);

U8 main_head_after_44[64];
MetaReadHead("C:/Home/P44Repo.hgs", "main", main_head_after_44);
Bool main_untouched = TRUE;
for (k44=0;k44<64;k44++) if (main_head_after_44[k44]!=main_head_before_44[k44]) main_untouched=FALSE;
CommPrint(1, "main_untouched_by_feature_undo=%d\n", main_untouched);

// redo while still on "feature" - should restore.
Hgit("redo \"C:/Home/P44Repo.hgs\"");
U8 feature_head_after_redo_44[64];
MetaReadHead("C:/Home/P44Repo.hgs", "feature", feature_head_after_redo_44);
Bool feature_restored = TRUE;
for (k44=0;k44<64;k44++) if (feature_head_after_redo_44[k44]!=feature_head_before_undo_44[k44]) feature_restored=FALSE;
CommPrint(1, "feature_restored_by_own_redo=%d\n", feature_restored);

// switch to main, undo there - must not touch feature at all.
Hgit("path go \"C:/Home/P44Repo.hgs\" main");
Hgit("undo \"C:/Home/P44Repo.hgs\"");
U8 feature_head_final_44[64];
MetaReadHead("C:/Home/P44Repo.hgs", "feature", feature_head_final_44);
Bool feature_untouched_by_main_undo = TRUE;
for (k44=0;k44<64;k44++) if (feature_head_final_44[k44]!=feature_head_before_undo_44[k44]) feature_untouched_by_main_undo=FALSE;
CommPrint(1, "feature_untouched_by_main_undo=%d\n", feature_untouched_by_main_undo);

// operation history + restore on "feature" (probe 38 style).
Hgit("path go \"C:/Home/P44Repo.hgs\" feature");
Hgit("operation history \"C:/Home/P44Repo.hgs\"");
Hgit("operation restore \"C:/Home/P44Repo.hgs\" 0");
U8 feature_after_restore0_44[64];
MetaReadHead("C:/Home/P44Repo.hgs", "feature", feature_after_restore0_44);
// entry 0 for feature is (prev=main's copied head at branch time, new=feature's first commit).
CommPrint(1, "restore0_ran=1\n");

if (feature_reverted && main_untouched && feature_restored && feature_untouched_by_main_undo)
  CommPrint(1, "PASS oplog_on_meta\n");
else
  CommPrint(1, "FAIL oplog_on_meta\n");

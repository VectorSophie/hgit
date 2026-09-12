// probe 36 — the operation log becomes path-scoped, so undo/redo are
// now safe to make current-path-aware (probe 35 deliberately left them
// main-only until this existed). Verifies: undo on "feature" reverts
// ONLY feature's HEAD, leaving main's own HEAD/oplog completely
// unaffected - through the real Hgit(cmdline) dispatcher.

Hgit("init \"C:/Home/P36Repo.hgs\"");

U8 fa36[3]; fa36[0]='o';fa36[1]='n';fa36[2]='e';
FileWrite("C:/Home/P36FileA.txt", fa36, 3);
Hgit("offer \"C:/Home/P36Repo.hgs\" \"C:/Home/P36FileA*\" main commit 1");
U8 main_head_before_36[64];
HeadRead("C:/Home/P36Repo.hgs", main_head_before_36);

Hgit("path new \"C:/Home/P36Repo.hgs\" feature");
Hgit("path go \"C:/Home/P36Repo.hgs\" feature");

U8 fa2_36[3]; fa2_36[0]='t';fa2_36[1]='w';fa2_36[2]='o';
FileWrite("C:/Home/P36FileA.txt", fa2_36, 3);
Hgit("offer \"C:/Home/P36Repo.hgs\" \"C:/Home/P36FileA*\" feature commit 1");
U8 feature_head_path_36[256];
PathHeadFilePath("C:/Home/P36Repo.hgs", "feature", feature_head_path_36);
I64 fsize36a;
U8 *fhead_before_undo = FileRead(feature_head_path_36, &fsize36a);
U8 feature_head_before_undo_36[64];
I64 k36;
for (k36=0;k36<64;k36++) feature_head_before_undo_36[k36] = fhead_before_undo[k36];

// undo while on "feature" - should revert ONLY feature's HEAD back to
// the all-zero sentinel (feature had exactly one commit of its own
// logged in ITS OWN oplog since path-new copied main's head but didn't
// log an "operation" for that copy).
Hgit("undo \"C:/Home/P36Repo.hgs\"");
I64 fsize36b;
U8 *fhead_after_undo = FileRead(feature_head_path_36, &fsize36b);
Bool feature_head_reverted = TRUE;
if (fsize36b == 64) {
  Bool same = TRUE;
  for (k36=0;k36<64;k36++) if (fhead_after_undo[k36]!=feature_head_before_undo_36[k36]) same=FALSE;
  feature_head_reverted = !same;
} else {
  feature_head_reverted = FALSE;
}
CommPrint(1, "feature_head_reverted_by_own_undo=%d\n", feature_head_reverted);

// main's own HEAD must be completely unaffected by an undo issued
// while "feature" was current.
U8 main_head_after_36[64];
HeadRead("C:/Home/P36Repo.hgs", main_head_after_36);
Bool main_untouched_by_feature_undo = TRUE;
for (k36=0;k36<64;k36++) if (main_head_after_36[k36]!=main_head_before_36[k36]) main_untouched_by_feature_undo=FALSE;
CommPrint(1, "main_untouched_by_feature_undo=%d\n", main_untouched_by_feature_undo);

// redo while still on "feature" - should restore feature's HEAD.
Hgit("redo \"C:/Home/P36Repo.hgs\"");
I64 fsize36c;
U8 *fhead_after_redo = FileRead(feature_head_path_36, &fsize36c);
Bool feature_head_restored = TRUE;
if (fsize36c == 64) {
  for (k36=0;k36<64;k36++) if (fhead_after_redo[k36]!=feature_head_before_undo_36[k36]) feature_head_restored=FALSE;
} else {
  feature_head_restored = FALSE;
}
CommPrint(1, "feature_head_restored_by_own_redo=%d\n", feature_head_restored);

// switch to main - undo here (main's own log has its own one entry)
// must not touch feature's HEAD at all.
Hgit("path go \"C:/Home/P36Repo.hgs\" main");
Hgit("undo \"C:/Home/P36Repo.hgs\"");
I64 fsize36d;
U8 *fhead_after_main_undo = FileRead(feature_head_path_36, &fsize36d);
Bool feature_untouched_by_main_undo = TRUE;
if (fsize36d == 64) {
  for (k36=0;k36<64;k36++) if (fhead_after_main_undo[k36]!=feature_head_before_undo_36[k36]) feature_untouched_by_main_undo=FALSE;
} else {
  feature_untouched_by_main_undo = FALSE;
}
CommPrint(1, "feature_untouched_by_main_undo=%d\n", feature_untouched_by_main_undo);

if (feature_head_reverted && main_untouched_by_feature_undo &&
    feature_head_restored && feature_untouched_by_main_undo)
  CommPrint(1, "PASS path_scoped_oplog\n");
else
  CommPrint(1, "FAIL path_scoped_oplog\n");

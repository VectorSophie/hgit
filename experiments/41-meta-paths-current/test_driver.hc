// probe 41 — Meta.HC's path-declaration/listing and current-path slice
// (MetaPathExists/MetaPathDeclare/MetaPathList/MetaCurrentGet/
// MetaCurrentSet), standalone, same not-yet-wired-in status as
// probe 40's HEAD slice.

U8 *repo = "C:/Home/P41Repo.hgs";

// fresh repo: only "main" exists, current path defaults to "main".
Bool main_exists_before = MetaPathExists(repo, "main");
Bool feature_exists_before = MetaPathExists(repo, "feature");
U8 cur0[64];
MetaCurrentGet(repo, cur0);
CommPrint(1, "main_exists_before=%d feature_exists_before=%d cur0=%s\n",
          main_exists_before, feature_exists_before, cur0);

MetaPathList(repo);

// declare a new path, confirm it now exists.
MetaPathDeclare(repo, "feature");
Bool feature_exists_after = MetaPathExists(repo, "feature");
CommPrint(1, "feature_exists_after=%d\n", feature_exists_after);

// declaring the same path again must be idempotent - not add a
// second entry (checked via MetaPathList's output below, by eye,
// same style as Paths.HC's own probe).
MetaPathDeclare(repo, "feature");

MetaPathList(repo);

// switch current path, read it back.
MetaCurrentSet(repo, "feature");
U8 cur1[64];
MetaCurrentGet(repo, cur1);
Bool cur1_is_feature = (StrCmp(cur1, "feature") == 0);
CommPrint(1, "cur1=%s cur1_is_feature=%d\n", cur1, cur1_is_feature);

// switch back to main, confirm.
MetaCurrentSet(repo, "main");
U8 cur2[64];
MetaCurrentGet(repo, cur2);
Bool cur2_is_main = (StrCmp(cur2, "main") == 0);
CommPrint(1, "cur2=%s cur2_is_main=%d\n", cur2, cur2_is_main);

// a path never declared reports FALSE.
Bool never_declared = MetaPathExists(repo, "nope");
CommPrint(1, "never_declared_exists=%d (expect 0)\n", never_declared);

if (main_exists_before && !feature_exists_before &&
    StrCmp(cur0, "main") == 0 &&
    feature_exists_after && cur1_is_feature && cur2_is_main && !never_declared)
  CommPrint(1, "PASS meta_paths_current\n");
else
  CommPrint(1, "FAIL meta_paths_current\n");

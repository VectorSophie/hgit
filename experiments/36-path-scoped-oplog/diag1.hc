// diagnostic: probe 36's redo failure - check the actual redolog.feature
// file state right after undo, and confirm CurrentPathGet is stable.

U8 cur1[64];
CurrentPathGet("C:/Home/P36Repo.hgs", cur1);
CommPrint(1, "current_path_now=%s\n", cur1);

U8 redo_path_direct[256];
RedoLogPathFor("C:/Home/P36Repo.hgs", "feature", redo_path_direct);
CommPrint(1, "redo_path_direct=%s\n", redo_path_direct);

U8 redo_path_via_current[256];
RedoLogPath("C:/Home/P36Repo.hgs", redo_path_via_current);
CommPrint(1, "redo_path_via_current=%s\n", redo_path_via_current);

I64 sz;
U8 *buf = FileRead(redo_path_direct, &sz);
CommPrint(1, "redolog_feature_exists=%d size=%d\n", buf!=NULL, sz);

U8 oplog_path_direct[256];
OpLogPathFor("C:/Home/P36Repo.hgs", "feature", oplog_path_direct);
I64 osz;
U8 *obuf = FileRead(oplog_path_direct, &osz);
CommPrint(1, "oplog_feature_exists=%d size=%d\n", obuf!=NULL, osz);

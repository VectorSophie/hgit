// diagnostic 3: call OpLogAppend directly (bypassing Offer.HC/Hgit
// dispatch entirely) while current path is "feature", to isolate
// whether the bug is in OpLogAppend/OpLogPathFor themselves or in how
// Offer.HC calls them.

Hgit("path go \"C:/Home/DiagRepo.hgs\" feature");
U8 cur[64];
CurrentPathGet("C:/Home/DiagRepo.hgs", cur);
CommPrint(1, "diag3_current=%s\n", cur);

U8 p1[64], p2[64];
I64 i;
for (i=0;i<64;i++) { p1[i]=0; p2[i]=i+1; }

OpLogAppend("C:/Home/DiagRepo.hgs", p1, p2, 12345);

U8 oplog_path_x[256];
OpLogPath("C:/Home/DiagRepo.hgs", oplog_path_x);
I64 osz;
U8 *obuf = FileRead(oplog_path_x, &osz);
CommPrint(1, "diag3_oplog_path=%s exists=%d size=%d\n", oplog_path_x, obuf!=NULL, osz);

// also test OpLogPathFor / OpLogAppendTo directly, bypassing even
// OpLogAppend's own current-path resolution.
U8 direct_path[256];
OpLogPathFor("C:/Home/DiagRepo.hgs", "feature", direct_path);
CommPrint(1, "diag3_direct_path=%s\n", direct_path);
OpLogAppendTo(direct_path, p1, p2, 99999);
I64 dsz;
U8 *dbuf = FileRead(direct_path, &dsz);
CommPrint(1, "diag3_direct_exists=%d size=%d\n", dbuf!=NULL, dsz);

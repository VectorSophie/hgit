// diagnostic 2: fresh isolated repro with prints interspersed around
// the exact undo call, to see the redolog write happen (or not) live.

Hgit("init \"C:/Home/DiagRepo.hgs\"");
U8 fad[3]; fad[0]='o';fad[1]='n';fad[2]='e';
FileWrite("C:/Home/DiagFileA.txt", fad, 3);
Hgit("offer \"C:/Home/DiagRepo.hgs\" \"C:/Home/DiagFileA*\" root");

Hgit("path new \"C:/Home/DiagRepo.hgs\" feature");
Hgit("path go \"C:/Home/DiagRepo.hgs\" feature");

U8 curX[64];
CurrentPathGet("C:/Home/DiagRepo.hgs", curX);
CommPrint(1, "diag_current_before_offer=%s\n", curX);

U8 fad2[3]; fad2[0]='t';fad2[1]='w';fad2[2]='o';
FileWrite("C:/Home/DiagFileA.txt", fad2, 3);
Hgit("offer \"C:/Home/DiagRepo.hgs\" \"C:/Home/DiagFileA*\" second");

U8 oplog_path_x[256];
OpLogPath("C:/Home/DiagRepo.hgs", oplog_path_x);
I64 osz;
U8 *obuf = FileRead(oplog_path_x, &osz);
CommPrint(1, "diag_oplog_path=%s exists=%d size=%d\n", oplog_path_x, obuf!=NULL, osz);

U8 curY[64];
CurrentPathGet("C:/Home/DiagRepo.hgs", curY);
CommPrint(1, "diag_current_before_undo=%s\n", curY);

Bool undo_ok_x = OpLogUndo("C:/Home/DiagRepo.hgs");
CommPrint(1, "diag_undo_ok=%d\n", undo_ok_x);

U8 redo_path_x[256];
RedoLogPath("C:/Home/DiagRepo.hgs", redo_path_x);
I64 rsz;
U8 *rbuf = FileRead(redo_path_x, &rsz);
CommPrint(1, "diag_redo_path=%s exists=%d size=%d\n", redo_path_x, rbuf!=NULL, rsz);

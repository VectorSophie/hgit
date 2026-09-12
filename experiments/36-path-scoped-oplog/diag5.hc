// diagnostic 5: same repo, two sibling filenames, one known-working
// shape (.head.feature) and one failing shape (.oplog.feature) -
// isolate whether it's about the string "oplog" specifically, the
// total path length, or something else.

U8 buf136[136];
I64 i;
for (i=0;i<136;i++) buf136[i] = i;

FileWrite("C:/Home/DiagRepo.hgs.head.feature2", buf136, 64);
I64 sz1;
U8 *r1 = FileRead("C:/Home/DiagRepo.hgs.head.feature2", &sz1);
CommPrint(1, "diag5_head_feature2_exists=%d size=%d\n", r1!=NULL, sz1);

FileWrite("C:/Home/DiagRepo.hgs.oplog.feature2", buf136, 136);
I64 sz2;
U8 *r2 = FileRead("C:/Home/DiagRepo.hgs.oplog.feature2", &sz2);
CommPrint(1, "diag5_oplog_feature2_exists=%d size=%d\n", r2!=NULL, sz2);

// shorter variant, in case length/segment-count is the limit.
FileWrite("C:/Home/DiagRepo.hgs.oplogX", buf136, 136);
I64 sz3;
U8 *r3 = FileRead("C:/Home/DiagRepo.hgs.oplogX", &sz3);
CommPrint(1, "diag5_oplogX_exists=%d size=%d\n", r3!=NULL, sz3);

// exact same "oplog.feature" shape and length but shorter repo name.
FileWrite("C:/Home/D.hgs.oplog.feature", buf136, 136);
I64 sz4;
U8 *r4 = FileRead("C:/Home/D.hgs.oplog.feature", &sz4);
CommPrint(1, "diag5_shortname_exists=%d size=%d\n", r4!=NULL, sz4);

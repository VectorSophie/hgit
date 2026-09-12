// diagnostic 4: minimal isolation - does a plain FileWrite to this
// exact literal path work at all, bypassing every helper function?

U8 buf136[136];
I64 i;
for (i=0;i<136;i++) buf136[i] = i;

FileWrite("C:/Home/DiagRepo.hgs.oplog.feature", buf136, 136);

I64 sz;
U8 *rb = FileRead("C:/Home/DiagRepo.hgs.oplog.feature", &sz);
CommPrint(1, "diag4_literal_write_exists=%d size=%d\n", rb!=NULL, sz);

// also try writing to a path built char-by-char the same way
// OpLogPathFor does, to rule out a subtle string-building bug.
U8 built[256];
U8 *rp = "C:/Home/DiagRepo.hgs";
I64 k = 0;
while (rp[k]) { built[k] = rp[k]; k++; }
built[k++]='.'; built[k++]='o'; built[k++]='p';
built[k++]='l'; built[k++]='o'; built[k++]='g';
built[k++]='.'; built[k++]='f'; built[k++]='e';
built[k++]='a'; built[k++]='t'; built[k++]='u';
built[k++]='r'; built[k++]='e';
built[k] = 0;
CommPrint(1, "diag4_built=%s (len=%d)\n", built, k);

FileWrite(built, buf136, 136);
I64 sz2;
U8 *rb2 = FileRead(built, &sz2);
CommPrint(1, "diag4_built_write_exists=%d size=%d\n", rb2!=NULL, sz2);

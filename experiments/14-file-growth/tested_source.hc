U8 small[16];
I64 i;
for (i=0;i<16;i++) small[i]=i;
FileWrite("C:/Home/GrowTest.dat", small, 16);

I64 s1;
U8 *r1 = FileRead("C:/Home/GrowTest.dat", &s1);
CommPrint(1,"after first write: size=%d first_byte=%d last_byte=%d\n", s1, r1[0], r1[15]);

// now write a LARGER buffer to the SAME path
U8 big[64];
for (i=0;i<64;i++) big[i]=100+i;
FileWrite("C:/Home/GrowTest.dat", big, 64);

I64 s2;
U8 *r2 = FileRead("C:/Home/GrowTest.dat", &s2);
CommPrint(1,"after second (larger) write: size=%d first_byte=%d last_byte=%d\n", s2, r2[0], r2[63]);

if (s2==64 && r2[0]==100 && r2[63]==163)
  CommPrint(1,"PASS filewrite_grows_existing_file\n");
else
  CommPrint(1,"FAIL filewrite_grows_existing_file\n");

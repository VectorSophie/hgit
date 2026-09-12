U8 big[64];
I64 i;
for (i=0;i<64;i++) big[i]=i;
FileWrite("C:/Home/ShrinkTest.dat", big, 64);
I64 s1;
U8 *r1 = FileRead("C:/Home/ShrinkTest.dat", &s1);
CommPrint(1, "after big write: size=%d last=%d\n", s1, r1[63]);

U8 small[8];
for (i=0;i<8;i++) small[i]=100+i;
FileWrite("C:/Home/ShrinkTest.dat", small, 8);
I64 s2;
U8 *r2 = FileRead("C:/Home/ShrinkTest.dat", &s2);
CommPrint(1, "after small write: size=%d first=%d\n", s2, r2[0]);

if (s1==64 && r1[63]==63 && s2==8 && r2[0]==100)
  CommPrint(1, "PASS filewrite_shrinks\n");
else
  CommPrint(1, "FAIL filewrite_shrinks\n");

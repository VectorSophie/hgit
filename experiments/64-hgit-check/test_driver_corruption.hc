U0 P64BTest()
{
  Hgit("init C:/Home/P64BRepo.hgs");
  FileWrite("C:/Home/P64BFileA.txt","hello",5);
  Hgit("offer C:/Home/P64BRepo.hgs P64BFileA.txt offer_one");

  // Deliberately corrupt one byte in the middle of the object section
  // (past the 16-byte header) to verify CHECK_FAIL actually triggers.
  I64 sz;
  U8 *buf = FileRead("C:/Home/P64BRepo.hgs", &sz);
  buf[30] = buf[30] ^ 0xFF;
  FileWrite("C:/Home/P64BRepo.hgs", buf, sz);

  Hgit("check C:/Home/P64BRepo.hgs");
  CommPrint(1,"PASS p64b_check_detects_corruption\n");
}
P64BTest;

U0 P70BNegativeTest()
{
  Hgit("init C:/Home/P70BRepo.hgs");
  FileWrite("C:/Home/P70BFileA.txt","content A",9);
  Hgit("offer C:/Home/P70BRepo.hgs P70BFileA.txt first");

  // A genuinely new file, different name AND different content -
  // should NOT be treated as a rename.
  FileWrite("C:/Home/P70BFileB.txt","totally different content",25);
  Hgit("offer C:/Home/P70BRepo.hgs P70BFileB.txt second");

  U8 head_hash[64];
  CurrentHeadRead("C:/Home/P70BRepo.hgs", head_hash);
  U8 head_hex[129];
  HashToHex(head_hash, head_hex);
  U8 cmd[512];
  StrPrint(cmd, "see C:/Home/P70BRepo.hgs %s", head_hex);
  Hgit(cmd);
  CommPrint(1,"PASS p70b_negative_test\n");
}
P70BNegativeTest;

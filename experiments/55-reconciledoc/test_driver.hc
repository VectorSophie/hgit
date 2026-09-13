U0 P55BTest()
{
  Hgit("init C:/Home/P55BRepo.hgs");
  FileWrite("C:/Home/P55BFileA.txt","hello v1",8);
  Hgit("offer C:/Home/P55BRepo.hgs P55BFileA.txt offer_one");
  FileWrite("C:/Home/P55BFileA.txt","hello v2",8);
  U8 head_hash[64];
  CurrentHeadRead("C:/Home/P55BRepo.hgs", head_hash);
  U8 head_hex[129];
  HashToHex(head_hash, head_hex);
  U8 cmd[512];
  StrPrint(cmd, "correct C:/Home/P55BRepo.hgs %s 0000000000000000 P55BFileA.txt correcting_offer_one", head_hex);
  Hgit(cmd);
  U8 head2_hash[64];
  CurrentHeadRead("C:/Home/P55BRepo.hgs", head2_hash);
  U8 head2_hex[129];
  HashToHex(head2_hash, head2_hex);
  StrPrint(cmd, "reconciledoc C:/Home/P55BRepo.hgs %s C:/Home/P55BReconcile.DD", head2_hex);
  Hgit(cmd);
  CommPrint(1,"PASS reconciledoc_e2e\n");
}
P55BTest;

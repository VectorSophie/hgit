U0 P69RefTest()
{
  Hgit("init C:/Home/P69Repo.hgs");
  FileWrite("C:/Home/P69FileA.txt","v1",2);
  Hgit("offer C:/Home/P69Repo.hgs P69FileA.txt offer_one");
  FileWrite("C:/Home/P69FileA.txt","v2",2);
  Hgit("offer C:/Home/P69Repo.hgs P69FileA.txt offer_two");

  U8 head_hash[64];
  CurrentHeadRead("C:/Home/P69Repo.hgs", head_hash);
  U8 head_hex[129];
  HashToHex(head_hash, head_hex);
  U8 cmd[512];
  StrPrint(cmd, "correct C:/Home/P69Repo.hgs %s 0000000000000000 P69FileA.txt correcting_offer", head_hex);
  Hgit(cmd);

  Hgit("check C:/Home/P69Repo.hgs");
  CommPrint(1,"PASS p69_reftest_clean\n");
}
P69RefTest;

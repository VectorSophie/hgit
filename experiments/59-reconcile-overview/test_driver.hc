U0 P59Test()
{
  Hgit("init C:/Home/P59Repo.hgs");
  FileWrite("C:/Home/P59FileA.txt","v1",2);
  Hgit("offer C:/Home/P59Repo.hgs P59FileA.txt plain_offer_one");
  FileWrite("C:/Home/P59FileA.txt","v2",2);
  Hgit("offer C:/Home/P59Repo.hgs P59FileA.txt plain_offer_two");

  U8 head_hash[64];
  CurrentHeadRead("C:/Home/P59Repo.hgs", head_hash);
  U8 head_hex[129];
  HashToHex(head_hash, head_hex);
  U8 cmd[512];
  StrPrint(cmd, "correct C:/Home/P59Repo.hgs %s 0000000000000000 P59FileA.txt correcting_offer_two", head_hex);
  Hgit(cmd);

  FileWrite("C:/Home/P59FileA.txt","v3",2);
  Hgit("offer C:/Home/P59Repo.hgs P59FileA.txt plain_offer_three");

  StrPrint(cmd, "reconcileoverview C:/Home/P59Repo.hgs C:/Home/P59Overview.DD");
  Hgit(cmd);
  CommPrint(1,"PASS p59_reconcile_overview\n");
}
P59Test;

U0 P58Test()
{
  Hgit("init C:/Home/P58Repo.hgs");
  FileWrite("C:/Home/P58FileA.txt","hello v1",8);
  Hgit("offer C:/Home/P58Repo.hgs P58FileA.txt offer_one");
  FileWrite("C:/Home/P58FileA.txt","hello v2",8);
  U8 head_hash[64];
  CurrentHeadRead("C:/Home/P58Repo.hgs", head_hash);
  U8 head_hex[129];
  HashToHex(head_hash, head_hex);
  U8 cmd[512];
  StrPrint(cmd, "correct C:/Home/P58Repo.hgs %s 0000000000000000 P58FileA.txt correcting_offer_one", head_hex);
  Hgit(cmd);
  U8 head2_hash[64];
  CurrentHeadRead("C:/Home/P58Repo.hgs", head2_hash);
  U8 head2_hex[129];
  HashToHex(head2_hash, head2_hex);
  StrPrint(cmd, "reconciledoc C:/Home/P58Repo.hgs %s C:/Home/P58Reconcile.DD", head2_hex);
  Hgit(cmd);
  CommPrint(1,"PASS p58_tree_reconciledoc_e2e\n");
}
P58Test;

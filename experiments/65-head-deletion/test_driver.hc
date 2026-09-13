U0 P65Test()
{
  Hgit("init C:/Home/P65Repo.hgs");
  FileWrite("C:/Home/P65FileA.txt","v1",2);
  Hgit("offer C:/Home/P65Repo.hgs P65FileA.txt offer_one");
  FileWrite("C:/Home/P65FileA.txt","v2",2);
  Hgit("offer C:/Home/P65Repo.hgs P65FileA.txt offer_two");
  Hgit("undo C:/Home/P65Repo.hgs");
  Hgit("redo C:/Home/P65Repo.hgs");
  Hgit("path new C:/Home/P65Repo.hgs feature");
  Hgit("path go C:/Home/P65Repo.hgs feature");
  Hgit("history C:/Home/P65Repo.hgs");
  Hgit("status C:/Home/P65Repo.hgs P65FileA.txt C:/Home/");
  Hgit("check C:/Home/P65Repo.hgs");
  Hgit("historydoc C:/Home/P65Repo.hgs C:/Home/P65History.DD");

  U8 head_hash[64];
  CurrentHeadRead("C:/Home/P65Repo.hgs", head_hash);
  U8 head_hex[129];
  HashToHex(head_hash, head_hex);
  Hgit("path go C:/Home/P65Repo.hgs main");
  U8 cmd[512];
  StrPrint(cmd, "see C:/Home/P65Repo.hgs %s", head_hex);
  Hgit(cmd);

  CommPrint(1,"PASS p65_head_deletion_regression\n");
}
P65Test;

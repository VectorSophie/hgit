U0 P62Test()
{
  Hgit("init C:/Home/P62Repo.hgs");
  FileWrite("C:/Home/P62FileA.txt","v0",2);
  Hgit("offer C:/Home/P62Repo.hgs P62FileA.txt root_offer");

  I64 i;
  U8 head_hex[129];
  U8 cmd[512];
  for (i=0; i<25; i++) {
    U8 head_hash[64];
    CurrentHeadRead("C:/Home/P62Repo.hgs", head_hash);
    HashToHex(head_hash, head_hex);
    StrPrint(cmd, "correct C:/Home/P62Repo.hgs %s 0000000000000000 P62FileA.txt correction_%d_with_extra_padding_text_here", head_hex, i);
    Hgit(cmd);
  }
  CommPrint(1,"GREW_REPO_DONE\n");

  U8 head_hash2[64];
  CurrentHeadRead("C:/Home/P62Repo.hgs", head_hash2);
  U8 head_hex2[129];
  HashToHex(head_hash2, head_hex2);
  StrPrint(cmd, "see C:/Home/P62Repo.hgs %s", head_hex2);
  Hgit(cmd);

  Hgit("history C:/Home/P62Repo.hgs");

  Hgit("status C:/Home/P62Repo.hgs P62FileA.txt C:/Home/");

  Hgit("historydoc C:/Home/P62Repo.hgs C:/Home/P62History.DD");

  Hgit("reconcileoverview C:/Home/P62Repo.hgs C:/Home/P62Overview.DD");

  CommPrint(1,"PASS p62_all_commands_at_scale\n");
}
P62Test;

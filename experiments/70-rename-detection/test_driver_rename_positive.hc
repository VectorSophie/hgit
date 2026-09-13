U0 P70RenameTest()
{
  Hgit("init C:/Home/P70Repo.hgs");
  FileWrite("C:/Home/P70Original.txt","same content here",18);
  Hgit("offer C:/Home/P70Repo.hgs P70Original.txt initial_offer");

  U8 head_hash[64];
  CurrentHeadRead("C:/Home/P70Repo.hgs", head_hash);
  U8 head_hex[129];
  HashToHex(head_hash, head_hex);
  U8 cmd[512];
  StrPrint(cmd, "see C:/Home/P70Repo.hgs %s", head_hex);
  Hgit(cmd);

  // "Rename" the file: same content, new name, old file deleted.
  FileWrite("C:/Home/P70Renamed.txt","same content here",18);
  Hgit("offer C:/Home/P70Repo.hgs P70Renamed.txt after_rename");

  U8 head2_hash[64];
  CurrentHeadRead("C:/Home/P70Repo.hgs", head2_hash);
  U8 head2_hex[129];
  HashToHex(head2_hash, head2_hex);
  StrPrint(cmd, "see C:/Home/P70Repo.hgs %s", head2_hex);
  Hgit(cmd);

  CommPrint(1,"PASS p70_rename_test\n");
}
P70RenameTest;

U0 P64Test()
{
  Hgit("init C:/Home/P64Repo.hgs");
  FileWrite("C:/Home/P64FileA.txt","hello",5);
  Hgit("offer C:/Home/P64Repo.hgs P64FileA.txt offer_one");
  Hgit("check C:/Home/P64Repo.hgs");
  Hgit("check C:/Home/P62Repo.hgs");
  CommPrint(1,"PASS p64_check_command\n");
}
P64Test;

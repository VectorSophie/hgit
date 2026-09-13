U0 P66Test()
{
  Hgit("init C:/Home/P66Repo.hgs");
  I64 i;
  U8 cmd[512];
  for (i=0; i<150; i++) {
    I64 msz;
    U8 *mbuf = FileRead("C:/Home/P66Repo.hgs.m", &msz);
    if (i % 10 == 0) CommPrint(1, "BEFORE_OFFER i=%d meta_size=%d\n", i, msz);
    FileWrite("C:/Home/P66FileA.txt", "v", 1);
    StrPrint(cmd, "offer C:/Home/P66Repo.hgs P66FileA.txt offer_number_%d", i);
    Hgit(cmd);
  }
  CommPrint(1,"PASS p66_meta_bisection_done\n");
}
P66Test;

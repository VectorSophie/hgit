U0 P67CStatus()
{
  Hgit("init C:/Home/P67CRepo.hgs");
  FileWrite("C:/Home/P67CSmall.txt", "hi", 2);
  Hgit("offer C:/Home/P67CRepo.hgs P67CSmall.txt small_offer");

  U8 bigbuf[700];
  I64 i;
  for (i=0; i<600; i++) bigbuf[i] = 'X';
  FileWrite("C:/Home/P67CBig.txt", bigbuf, 600);
  Hgit("status C:/Home/P67CRepo.hgs P67CBig.txt C:/Home/");
  CommPrint(1,"PASS p67c_status_large_file\n");
}
P67CStatus;

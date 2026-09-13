U0 P56Test()
{
  U8 bigbuf[700];
  I64 i;
  for (i=0; i<600; i++) bigbuf[i] = 'A' + (i%26);
  FileWrite("C:/Home/P56Big.txt", bigbuf, 600);
  Hgit("init C:/Home/P56Repo.hgs");
  CommPrint(1,"P56_ABOUT_TO_OFFER\n");
  Hgit("offer C:/Home/P56Repo.hgs P56Big.txt big_file_offer");
  CommPrint(1,"PASS p56_big_file_offer\n");
}
P56Test;

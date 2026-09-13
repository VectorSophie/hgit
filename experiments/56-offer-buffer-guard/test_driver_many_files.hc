U0 P56BTest()
{
  I64 fi;
  U8 name[64];
  for (fi=0; fi<40; fi++) {
    StrPrint(name, "C:/Home/P56F%03d.txt", fi);
    FileWrite(name, "x", 1);
  }
  Hgit("init C:/Home/P56BRepo.hgs");
  CommPrint(1,"P56B_ABOUT_TO_OFFER\n");
  Hgit("offer C:/Home/P56BRepo.hgs P56F* many_small_files");
  CommPrint(1,"PASS p56b_many_small_files\n");
}
P56BTest;

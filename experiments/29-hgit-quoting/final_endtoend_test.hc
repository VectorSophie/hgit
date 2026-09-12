Hgit("init \"C:/Home/RealQuotedRepo.hgs\"");
I64 rsize;
U8 *rbuf = FileRead("C:/Home/RealQuotedRepo.hgs", &rsize);
CommPrint(1, "real_quoted_repo_created=%d size=%d\n", rbuf!=NULL, rsize);
Hgit("status C:/Home/OfferTestRepo.hgs C:/Home/OfferFile* C:/Home/");

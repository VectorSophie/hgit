U0 P66BVerify()
{
  I64 msz;
  U8 *mbuf = FileRead("C:/Home/P66Repo.hgs.m", &msz);
  CommPrint(1, "FINAL_META_SIZE=%d\n", msz);

  I64 opcount = MetaOpLogCount("C:/Home/P66Repo.hgs", "main");
  CommPrint(1, "OPLOG_COUNT=%d (expect 150)\n", opcount);

  U8 head_hash[64];
  Bool ok = CurrentHeadRead("C:/Home/P66Repo.hgs", head_hash);
  CommPrint(1, "HEAD_READ_OK=%d\n", ok);
  U8 head_hex[129];
  HashToHex(head_hash, head_hex);
  U8 cmd[512];
  StrPrint(cmd, "see C:/Home/P66Repo.hgs %s", head_hex);
  Hgit(cmd);
  CommPrint(1,"PASS p66b_verify_done\n");
}
P66BVerify;

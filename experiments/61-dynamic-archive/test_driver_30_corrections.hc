U0 P61Test()
{
  Hgit("init C:/Home/P61Repo.hgs");
  FileWrite("C:/Home/P61FileA.txt","v0",2);
  Hgit("offer C:/Home/P61Repo.hgs P61FileA.txt root_offer");

  I64 i;
  U8 head_hex[129];
  U8 cmd[512];
  for (i=0; i<30; i++) {
    I64 rsz;
    U8 *rbuf = FileRead("C:/Home/P61Repo.hgs", &rsz);
    CommPrint(1, "BEFORE_CORRECT i=%d repo_size=%d\n", i, rsz);

    U8 head_hash[64];
    CurrentHeadRead("C:/Home/P61Repo.hgs", head_hash);
    HashToHex(head_hash, head_hex);
    StrPrint(cmd, "correct C:/Home/P61Repo.hgs %s 0000000000000000 P61FileA.txt correction_number_%d_with_a_reasonably_long_message_to_use_up_buffer_space", head_hex, i);
    Hgit(cmd);
    CommPrint(1, "AFTER_CORRECT i=%d\n", i);
  }
  CommPrint(1,"PASS p61_no_ceiling_test\n");
}
P61Test;

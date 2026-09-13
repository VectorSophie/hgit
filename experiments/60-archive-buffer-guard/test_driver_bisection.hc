U0 P60BTest()
{
  Hgit("init C:/Home/P60BRepo.hgs");
  FileWrite("C:/Home/P60BFileA.txt","v0",2);
  Hgit("offer C:/Home/P60BRepo.hgs P60BFileA.txt root_offer");

  I64 i;
  U8 head_hex[129];
  U8 cmd[512];
  for (i=0; i<25; i++) {
    I64 rsz;
    U8 *rbuf = FileRead("C:/Home/P60BRepo.hgs", &rsz);
    CommPrint(1, "BEFORE_CORRECT i=%d repo_size=%d\n", i, rsz);

    U8 head_hash[64];
    CurrentHeadRead("C:/Home/P60BRepo.hgs", head_hash);
    HashToHex(head_hash, head_hex);
    StrPrint(cmd, "correct C:/Home/P60BRepo.hgs %s 0000000000000000 P60BFileA.txt correction_number_%d_with_a_reasonably_long_message_to_use_up_buffer_space", head_hex, i);
    Hgit(cmd);
    CommPrint(1, "AFTER_CORRECT i=%d\n", i);
  }
  CommPrint(1,"PASS p60b_bisection_done\n");
}
P60BTest;

U0 P60CTest()
{
  Hgit("init C:/Home/P60CRepo.hgs");
  FileWrite("C:/Home/P60CFileA.txt","v0",2);
  Hgit("offer C:/Home/P60CRepo.hgs P60CFileA.txt root_offer");

  I64 i;
  U8 head_hex[129];
  U8 cmd[512];
  for (i=0; i<16; i++) {
    I64 rsz;
    U8 *rbuf = FileRead("C:/Home/P60CRepo.hgs", &rsz);
    CommPrint(1, "BEFORE_CORRECT i=%d repo_size=%d\n", i, rsz);

    U8 head_hash[64];
    CurrentHeadRead("C:/Home/P60CRepo.hgs", head_hash);
    HashToHex(head_hash, head_hex);
    StrPrint(cmd, "correct C:/Home/P60CRepo.hgs %s 0000000000000000 P60CFileA.txt correction_number_%d_with_a_reasonably_long_message_to_use_up_buffer_space", head_hex, i);
    Hgit(cmd);
    CommPrint(1, "AFTER_CORRECT i=%d\n", i);
  }
  CommPrint(1,"PASS p60c_fresh_bisection_done\n");
}
P60CTest;

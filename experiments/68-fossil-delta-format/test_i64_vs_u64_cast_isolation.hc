U0 P68NAllCastTest()
{
  U8 buf[4];
  buf[0]=0x41; buf[1]=0x42; buf[2]=0x43; buf[3]=0x44;
  I64 pos = 0;
  // My FossilChecksum's exact shape: cast ALL FOUR terms explicitly.
  I64 word = (buf[pos](I64) << 24) | (buf[pos+1](I64) << 16) |
             (buf[pos+2](I64) << 8) | buf[pos+3](I64);
  CommPrint(1, "all_cast_word=%d (expect 1094861636)\n", word);

  // Now cast only 3 of them (last one uncast, like Canon's own style but reversed):
  I64 word2 = (buf[pos](I64) << 24) | (buf[pos+1](I64) << 16) |
              (buf[pos+2](I64) << 8) | buf[pos+3];
  CommPrint(1, "three_cast_word=%d (expect 1094861636)\n", word2);

  CommPrint(1,"PASS p68n_alltest\n");
}
P68NAllCastTest;

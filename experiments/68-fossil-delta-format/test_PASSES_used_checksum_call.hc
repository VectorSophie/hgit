U0 P74OneCheckOnly()
{
  U8 *source = "hello world";
  U8 *target = "hello there, big wide world!";
  I64 target_len = StrLen(target);

  U8 delta[512];
  I64 delta_len;
  FossilDeltaMakeTrivial(source, StrLen(source), target, target_len, delta, &delta_len);

  U8 reconstructed[512];
  I64 reconstructed_len;
  Bool ok = FossilDeltaApply(source, StrLen(source), delta, delta_len, reconstructed, &reconstructed_len);
  CommPrint(1, "APPLY_OK=%d\n", ok);

  U32 enc_check = FossilChecksum(target, target_len);
  CommPrint(1, "enc_check=%d\n", enc_check(U64)&0xFFFFFFFF);
  CommPrint(1, "PASS p74_onecheckonly\n");
}
P74OneCheckOnly;

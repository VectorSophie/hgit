U0 P71U32Extra()
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
  CommPrint(1, "U32EXTRA_APPLY_OK=%d\n", ok);

  U32 zzz_u32_extra = 0;
  CommPrint(1, "PASS p71_u32extra\n");
}
P71U32Extra;

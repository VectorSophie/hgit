U0 P75UsedVar()
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
  CommPrint(1, "USEDVAR_APPLY_OK=%d\n", ok);

  I64 zzz_used = 0;
  CommPrint(1, "zzz_used=%d\n", zzz_used);
  CommPrint(1, "PASS p75_usedvar\n");
}
P75UsedVar;

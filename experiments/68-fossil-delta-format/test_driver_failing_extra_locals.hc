U0 P68SBisect()
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
  CommPrint(1, "BISECT_APPLY_OK=%d\n", ok);

  // Just add extra locals, no new logic, see if that alone breaks it.
  Bool match = TRUE;
  I64 i = 0;
  CommPrint(1, "PASS p68s_bisect\n");
}
P68SBisect;

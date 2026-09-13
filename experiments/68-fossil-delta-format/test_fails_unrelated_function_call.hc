U0 P76StrLenCall()
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
  CommPrint(1, "STRLENCALL_APPLY_OK=%d\n", ok);

  I64 zzz_strlen_result = StrLen(target);
  CommPrint(1, "zzz_strlen_result=%d\n", zzz_strlen_result);
  CommPrint(1, "PASS p76_strlencall\n");
}
P76StrLenCall;

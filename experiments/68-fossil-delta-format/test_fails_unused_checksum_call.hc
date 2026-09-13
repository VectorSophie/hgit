U0 P72ExtraCall()
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
  CommPrint(1, "EXTRACALL_APPLY_OK=%d\n", ok);

  U32 dummy_call_result = FossilChecksum(target, target_len);
  CommPrint(1, "PASS p72_extracall\n");
}
P72ExtraCall;

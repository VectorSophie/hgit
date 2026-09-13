// Probe 77c: isolate FossilChecksum ALONE (no delta encode/decode at
// all) - does calling it directly, on the exact same fixed string,
// give a different result depending on whether the CALLING function
// has extra unrelated locals declared after the call?
U0 P77cChecksumFailing()
{
  U8 *target = "hello there, big wide world!";
  I64 target_len = StrLen(target);
  U32 sum = FossilChecksum(target, target_len);
  CommPrint(1, "CHECKSUM_FAILING_SHAPE=%d\n", sum);

  // Same extra locals as the known-failing caller shape.
  Bool match = TRUE;
  I64 i = 0;
  CommPrint(1, "PASS p77c_failing\n");
}
P77cChecksumFailing;

U0 P77cChecksumMinimal()
{
  U8 *target = "hello there, big wide world!";
  I64 target_len = StrLen(target);
  U32 sum = FossilChecksum(target, target_len);
  CommPrint(1, "CHECKSUM_MINIMAL_SHAPE=%d\n", sum);
  CommPrint(1, "PASS p77c_minimal\n");
}
P77cChecksumMinimal;

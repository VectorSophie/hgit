// Probe 80: does ANY two-level call nesting (test driver -> thin
// wrapper -> FossilChecksum) reproduce the bug, or does it need
// FossilDeltaMakeTrivial's own specific body/locals?
U32 P80ThinWrapper(U8 *data, I64 len)
{
  return FossilChecksum(data, len);
}

U0 P80ThinWrapperTest()
{
  U8 *target = "hello there, big wide world!";
  I64 target_len = StrLen(target);
  U32 sum = P80ThinWrapper(target, target_len);
  CommPrint(1, "THINWRAP_SUM=%d\n", sum);

  // Same extra locals as the known-failing shape.
  Bool match = TRUE;
  I64 i = 0;
  CommPrint(1, "PASS p80_thinwrapper\n");
}
P80ThinWrapperTest;

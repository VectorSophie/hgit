// Probe 77: does moving delta/reconstructed off the stack (MAlloc
// instead of U8[512]) change the caller-shape-sensitivity bug?
// Same "extra locals" trigger as test_driver_failing_extra_locals.hc,
// but delta/reconstructed are heap-allocated this time.
U0 P77HeapBufsTest()
{
  U8 *source = "hello world";
  U8 *target = "hello there, big wide world!";
  I64 target_len = StrLen(target);

  U8 *delta = MAlloc(512);
  I64 delta_len;
  FossilDeltaMakeTrivial(source, StrLen(source), target, target_len, delta, &delta_len);

  U8 *reconstructed = MAlloc(512);
  I64 reconstructed_len;
  Bool ok = FossilDeltaApply(source, StrLen(source), delta, delta_len, reconstructed, &reconstructed_len);
  CommPrint(1, "HEAPBUF_APPLY_OK=%d\n", ok);

  // Same extra locals as the known-failing stack-buffer reproduction.
  Bool match = TRUE;
  I64 i = 0;
  CommPrint(1, "PASS p77_heapbufs\n");
  Free(delta);
  Free(reconstructed);
}
P77HeapBufsTest;

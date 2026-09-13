// Probe 77b: does printing FossilDeltaApply's return value directly
// (no intermediate `Bool ok` local) change the caller-shape-sensitivity
// bug? Same extra-locals trigger, heap buffers (ruled out stack
// overlap already), but the call's result is never stored in a named
// local of its own.
U0 P77bInlineResultTest()
{
  U8 *source = "hello world";
  U8 *target = "hello there, big wide world!";
  I64 target_len = StrLen(target);

  U8 *delta = MAlloc(512);
  I64 delta_len;
  FossilDeltaMakeTrivial(source, StrLen(source), target, target_len, delta, &delta_len);

  U8 *reconstructed = MAlloc(512);
  I64 reconstructed_len;
  CommPrint(1, "INLINE_APPLY_OK=%d\n",
            FossilDeltaApply(source, StrLen(source), delta, delta_len, reconstructed, &reconstructed_len));

  Bool match = TRUE;
  I64 i = 0;
  CommPrint(1, "PASS p77b_inline\n");
  Free(delta);
  Free(reconstructed);
}
P77bInlineResultTest;

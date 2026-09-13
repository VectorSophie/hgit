// Probe 80b: absolute minimal, no-nesting, no-extra-locals check of
// FossilChecksum against the mathematically correct value for this
// exact 28-byte string (computed independently in Python: 1432286299).
U0 P80bGroundTruth()
{
  U8 *target = "hello there, big wide world!";
  I64 target_len = StrLen(target);
  CommPrint(1, "GT_LEN=%d\n", target_len);
  U32 sum = FossilChecksum(target, target_len);
  CommPrint(1, "GT_SUM=%d EXPECTED=1432286299\n", sum);
}
P80bGroundTruth;

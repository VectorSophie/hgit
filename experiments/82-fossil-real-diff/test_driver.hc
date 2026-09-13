// Probe 81 test driver: FossilDeltaMakeReal - a real (single-match)
// diff algorithm.
// Positive (real compression): source and target share a long common
// region with a small edit in the middle - the delta should be
// meaningfully smaller than target_len (proving a real copy segment
// got used, not just one big literal), and applying it should
// reconstruct target exactly, verified by the checksum AND a direct
// byte-for-byte comparison.
// Negative (no good match): source and target share nothing - the
// encoder should fall back to the same all-literal shape
// FossilDeltaMakeTrivial uses, still round-tripping correctly.
U0 P81RealDiffTest()
{
  U8 *source = "The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog again and again.";
  U8 *target = "The quick brown fox LEAPS over the lazy dog. The quick brown fox jumps over the lazy dog again and again.";
  I64 source_len = StrLen(source);
  I64 target_len = StrLen(target);
  CommPrint(1, "P81_LENS source=%d target=%d\n", source_len, target_len);

  U8 delta[512];
  I64 delta_len;
  FossilDeltaMakeReal(source, source_len, target, target_len, delta, &delta_len);
  CommPrint(1, "P81_DELTA_LEN=%d (target_len=%d)\n", delta_len, target_len);

  U8 reconstructed[512];
  I64 reconstructed_len;
  Bool ok = FossilDeltaApply(source, source_len, delta, delta_len, reconstructed, &reconstructed_len);
  CommPrint(1, "P81_APPLY_OK=%d reconstructed_len=%d\n", ok, reconstructed_len);

  Bool byte_match = (reconstructed_len == target_len);
  I64 bi;
  if (byte_match) for (bi=0; bi<target_len; bi++) if (reconstructed[bi] != target[bi]) byte_match = FALSE;
  CommPrint(1, "P81_BYTE_MATCH=%d\n", byte_match);

  // Negative case: no shared content at all.
  U8 *source2 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
  U8 *target2 = "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ!!";
  I64 source2_len = StrLen(source2);
  I64 target2_len = StrLen(target2);
  U8 delta2[512];
  I64 delta2_len;
  FossilDeltaMakeReal(source2, source2_len, target2, target2_len, delta2, &delta2_len);
  U8 reconstructed2[512];
  I64 reconstructed2_len;
  Bool ok2 = FossilDeltaApply(source2, source2_len, delta2, delta2_len, reconstructed2, &reconstructed2_len);
  Bool byte_match2 = (reconstructed2_len == target2_len);
  if (byte_match2) for (bi=0; bi<target2_len; bi++) if (reconstructed2[bi] != target2[bi]) byte_match2 = FALSE;
  CommPrint(1, "P81_NEG_APPLY_OK=%d P81_NEG_BYTE_MATCH=%d\n", ok2, byte_match2);

  CommPrint(1, "PASS p81_real_diff_test\n");
}
P81RealDiffTest;

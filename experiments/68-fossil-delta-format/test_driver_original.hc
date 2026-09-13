U0 P68BTest()
{
  U8 *source = "hello world";
  U8 *target = "hello there, big wide world!";
  I64 target_len = StrLen(target);

  U8 delta[512];
  I64 delta_len;
  FossilDeltaMakeTrivial(source, StrLen(source), target, target_len, delta, &delta_len);
  CommPrint(1, "DELTA_LEN=%d\n", delta_len);
  CommPrint(1, "DELTA_BYTES=");
  I64 di;
  for (di=0; di<delta_len; di++) CommPrint(1, "%c", delta[di]);
  CommPrint(1, "\n");

  U8 reconstructed[512];
  I64 reconstructed_len;
  Bool ok = FossilDeltaApply(source, StrLen(source), delta, delta_len, reconstructed, &reconstructed_len);
  CommPrint(1, "APPLY_OK=%d reconstructed_len=%d (expect %d)\n", ok, reconstructed_len, target_len);

  Bool match = TRUE;
  I64 i;
  if (reconstructed_len == target_len) {
    for (i=0; i<target_len; i++) if (reconstructed[i] != target[i]) match = FALSE;
  } else match = FALSE;
  CommPrint(1, "CONTENT_MATCH=%d\n", match);

  U8 corrupt_delta[512];
  for (i=0; i<delta_len; i++) corrupt_delta[i] = delta[i];
  I64 j;
  for (j=0; j<delta_len; j++) if (corrupt_delta[j]==':') break;
  corrupt_delta[j+3] = corrupt_delta[j+3] ^ 0xFF;

  U8 reconstructed2[512];
  I64 reconstructed2_len;
  Bool ok2 = FossilDeltaApply(source, StrLen(source), corrupt_delta, delta_len, reconstructed2, &reconstructed2_len);
  CommPrint(1, "CORRUPT_APPLY_OK=%d (expect 0 - checksum should catch it)\n", ok2);

  CommPrint(1,"PASS p68b_fossil_delta_roundtrip\n");
}
P68BTest;

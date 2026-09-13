U0 P69NameCollisionTest()
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
  CommPrint(1, "NAMECOLLISION_APPLY_OK=%d\n", ok);

  // Same TWO extra locals as the failing bisect test, but with names
  // that don't collide with anything used inside Fossil.HC itself.
  Bool zzz_match_unique = TRUE;
  I64 zzz_index_unique = 0;
  CommPrint(1, "PASS p69_namecollision\n");
}
P69NameCollisionTest;

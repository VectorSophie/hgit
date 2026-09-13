// Probe 80e: sanity-check Canon.HC's GetU32LE against a known value,
// given the new (U64)-cast-garbage-composition finding in Fossil.HC.
// GetU32LE's own byte pattern differs (only the last byte gets an
// explicit (U64) cast) - check whether it's actually affected too.
U0 P80eGetU32LECheck()
{
  U8 buf[4];
  buf[0] = 0x11;
  buf[1] = 0x22;
  buf[2] = 0x33;
  buf[3] = 0x44;
  U32 v = GetU32LE(buf, 0);
  CommPrint(1, "GETU32LE=%d EXPECTED=%d\n", v, 0x44332211);

  // Same known-failing-shape extra locals, to check caller-shape
  // sensitivity here too.
  Bool match = TRUE;
  I64 i = 0;
  U32 v2 = GetU32LE(buf, 0);
  CommPrint(1, "GETU32LE_SHAPED=%d EXPECTED=%d\n", v2, 0x44332211);
}
P80eGetU32LECheck;

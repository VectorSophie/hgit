// Hex.HC — hex string <-> raw hash bytes conversion.
//
// Every hgit-core/hgit-cli function so far takes a hash as raw 64
// bytes (the same convention throughout, e.g. Commit.HC's
// CommitParentHash, Index.HC's IndexLookup). Nothing needed to convert
// to/from a human-typeable hex string until `hgit see <offering>`
// needed to accept one at the actual cmd line. Verified
// (experiments/25-hex-hash/): round-tripped a real commit hash through
// hex and back losslessly, and confirmed invalid hex is rejected
// rather than silently accepted as zero/garbage.

U8 HexDigit(U8 c)
{
  if (c>='0' && c<='9') return c-'0';
  if (c>='a' && c<='f') return c-'a'+10;
  if (c>='A' && c<='F') return c-'A'+10;
  return 0xFF; // sentinel for invalid - caller must check for this
}

// hex must be exactly 128 characters (no NUL check here - caller's
// job). Returns FALSE without touching hash_out fully if any character
// isn't a valid hex digit - don't trust hash_out on a FALSE return.
Bool HexToHash(U8 *hex, U8 *hash_out)
{
  I64 i;
  for (i=0; i<64; i++) {
    U8 hi = HexDigit(hex[i*2]);
    U8 lo = HexDigit(hex[i*2+1]);
    if (hi==0xFF || lo==0xFF) return FALSE;
    hash_out[i] = (hi<<4)|lo;
  }
  return TRUE;
}

// Writes 128 lowercase hex chars + NUL (129 bytes total) into hex_out.
U0 HashToHex(U8 *hash, U8 *hex_out)
{
  U8 *digits = "0123456789abcdef";
  I64 i;
  for (i=0; i<64; i++) {
    hex_out[i*2]   = digits[hash[i]>>4];
    hex_out[i*2+1] = digits[hash[i]&0xF];
  }
  hex_out[128] = 0;
}

// Writes 16 lowercase hex chars + NUL (17 bytes total) into hex_out -
// same convention as HashToHex, but for a U64 (e.g. ADR 0004's entity
// IDs), which otherwise print as a negative number under a plain
// signed %d when the high bit is set (a real, hit-in-practice
// annoyance, not hypothetical - see experiments/49-entity-id/'s own
// README). Hex round-trips cleanly regardless of sign.
U0 U64ToHex(U64 v, U8 *hex_out)
{
  U8 *digits = "0123456789abcdef";
  I64 i;
  for (i=0; i<16; i++) {
    I64 shift = (15-i)*4;
    hex_out[i] = digits[(v >> shift) & 0xF];
  }
  hex_out[16] = 0;
}

// hex must be exactly 16 characters. Returns FALSE (out untouched) if
// any character isn't a valid hex digit.
Bool HexToU64(U8 *hex, U64 *out)
{
  U64 v = 0;
  I64 i;
  for (i=0; i<16; i++) {
    U8 d = HexDigit(hex[i]);
    if (d == 0xFF) return FALSE;
    v = (v << 4) | d;
  }
  *out = v;
  return TRUE;
}

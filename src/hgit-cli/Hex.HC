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

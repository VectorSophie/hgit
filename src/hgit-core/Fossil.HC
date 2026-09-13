// Fossil.HC — a minimal, byte-exact prototype of Fossil's delta
// format (docs/research/04-vcs-comparison.md), per that doc's own
// recommendation: "prototype Fossil's delta format specifically
// before inventing a new one."
//
// Every byte-level detail here is taken from Fossil's own real source
// (`src/delta.c`, via fossil-scm.org's own doc/source browser), not
// from a paraphrased summary - two earlier web summaries disagreed
// with each other on the alphabet's exact character order and the
// digit-write order, so the actual `putInt` C source was fetched
// directly to settle it. Confirmed:
//   - Alphabet (64 chars): "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~"
//     (underscore right after 'Z', before lowercase - NOT after 'z'
//     as one earlier summary claimed).
//   - Integers are variable-width base-64: 6 bits/char, MOST
//     significant 6-bit group written FIRST (standard positional
//     numeral order, same as decimal) - one earlier summary claimed
//     least-significant-first, which was wrong.
//   - Checksum: the payload treated as 32-bit big-endian words,
//     summed with natural U32 (mod 2^32) wraparound; 1-3 trailing
//     bytes are treated as if zero-padded at the low end (e.g. one
//     trailing byte contributes `byte<<24`).
//
// A real, previously-undocumented HolyC quirk found and fixed while
// verifying this (experiments/68-fossil-delta-format/), distinct from
// (and easy to confuse with) Canon.HC's own documented U32-return-
// value quirk: postfix-casting a raw byte read directly to `(I64)`
// produces GARBAGE - not the zero-extended byte value - while casting
// the exact same read to `(U64)` works correctly, even when the
// result is then used in an I64 context. Confirmed by direct,
// systematic isolation (experiments/68-fossil-delta-format/README.md
// has the full bisection): `buf[i](I64)` alone, assigned to a fresh
// I64 local, printed a huge garbage number; `buf[i](U64)` in the
// exact same position printed the correct byte value every time.
// Canon.HC's own working code (`GetU32LE`) already avoided this by
// convention - it only ever casts to `(U64)`, never `(I64)` - but
// its own comment doesn't call this out as the reason, so this file
// re-derives and documents it explicitly. Standing rule adopted here:
// cast a raw byte/array read to `(U64)`, never `(I64)`, even if the
// result will immediately be used as I64 - the resulting U64 value
// composes safely into I64 arithmetic/comparisons once it's clean.
//
// Depends on nothing but kernel string ops - self-contained.

// Encodes `v` as a variable-width base-64 integer, appending to
// buf/*len. Matches Fossil's own putInt() exactly: 0 is the single
// digit '0'; otherwise the most-significant 6-bit group is written
// first.
U0 FossilPutInt(I64 v, U8 *buf, I64 *len)
{
  U8 *digits = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~";
  if (v == 0) { buf[(*len)++] = '0'; return; }
  U8 tmp[8];
  I64 tcount = 0;
  while (v > 0) {
    tmp[tcount++] = digits[v & 0x3F];
    v >>= 6;
  }
  I64 ti;
  for (ti=tcount-1; ti>=0; ti--) buf[(*len)++] = tmp[ti];
}

// Returns the 0-63 alphabet index of `c`, or -1 if `c` isn't one of
// the 64 digit characters (i.e. it's a delimiter - '\n'/'@'/','/':'/
// ';' - the caller's cue to stop reading digits).
I64 FossilDigitValue(U8 c)
{
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'A' && c <= 'Z') return c - 'A' + 10;
  if (c == '_') return 36;
  if (c >= 'a' && c <= 'z') return c - 'a' + 37;
  if (c == '~') return 63;
  return -1;
}

// Reads a base-64 integer starting at buf[pos], stopping at the first
// non-digit character. Writes the decoded value to *value_out and
// returns the number of digit characters consumed (so the caller can
// advance pos itself and then handle the delimiter). `buf[pos+n]` is
// a plain U8 passed straight to FossilDigitValue (no cast needed - the
// function parameter is U8), so this function isn't itself exposed to
// the (I64)-cast-on-a-byte-read quirk described in the file header.
I64 FossilGetInt(U8 *buf, I64 pos, I64 *value_out)
{
  I64 v = 0;
  I64 n = 0;
  while (TRUE) {
    I64 d = FossilDigitValue(buf[pos+n]);
    if (d < 0) break;
    v = (v << 6) | d;
    n++;
  }
  *value_out = v;
  return n;
}

// Fossil's own checksum: treat `data` (len bytes) as 32-bit
// big-endian words and sum them with natural U32 (mod 2^32)
// wraparound; 1-3 trailing bytes are zero-padded at the low end
// (matches delta.c's own trailing-byte handling, confirmed from
// source rather than assumed). Every raw byte read is cast to
// `(U64)`, never `(I64)` - see the file header's quirk note - then
// composed into a U64 accumulator (Canon.HC's own GetU32LE
// convention), masked to 32 bits before returning.
U32 FossilChecksum(U8 *data, I64 len)
{
  U64 sum = 0;
  I64 pos = 0;
  while (pos + 4 <= len) {
    U64 word = (data[pos](U64) << 24) | (data[pos+1](U64) << 16) |
               (data[pos+2](U64) << 8) | data[pos+3](U64);
    sum += word;
    pos += 4;
  }
  I64 remaining = len - pos;
  if (remaining > 0) {
    U64 tail_word = 0;
    if (remaining >= 1) tail_word |= data[pos](U64) << 24;
    if (remaining >= 2) tail_word |= data[pos+1](U64) << 16;
    if (remaining >= 3) tail_word |= data[pos+2](U64) << 8;
    sum += tail_word;
  }
  return sum & 0xFFFFFFFF;
}

// Builds the simplest possible valid Fossil-format delta: a header
// (target length), one literal segment holding the ENTIRE target (no
// copy segments - this probe proves the format's mechanics, not a
// real diff algorithm), and a trailer (checksum). `source`/
// `source_len` are unused by this trivial encoder (a real diff
// algorithm would use them to find copy ranges) but kept in the
// signature so callers don't need to change when a real encoder
// replaces this one.
U0 FossilDeltaMakeTrivial(U8 *source, I64 source_len, U8 *target, I64 target_len,
                            U8 *delta_out, I64 *delta_len_out)
{
  I64 len = 0;
  FossilPutInt(target_len, delta_out, &len);
  delta_out[len++] = '\n';

  FossilPutInt(target_len, delta_out, &len);
  delta_out[len++] = ':';
  I64 i;
  for (i=0; i<target_len; i++) delta_out[len++] = target[i];

  // `sum` is a U32 function-return value (Canon.HC's own separately
  // documented risk case - a function declared to return a
  // narrower-than-64-bit type doesn't reliably truncate for the
  // caller) - cast to (U64) then masked, not trusted as already clean
  // and not cast directly to (I64).
  U32 sum = FossilChecksum(target, target_len);
  FossilPutInt((sum(U64) & 0xFFFFFFFF), delta_out, &len);
  delta_out[len++] = ';';

  *delta_len_out = len;
}

// Parses and applies a Fossil-format delta against `source` (only
// used for real copy segments - none exist yet, see above), writing
// the reconstructed target into `target_out` and its length into
// *target_len_out. Returns FALSE (nothing trustworthy written) if the
// delta is malformed or the trailer checksum doesn't match the
// reconstructed target - the same "verify, don't just trust" pattern
// this project's own `hgit check`/`ArchiveVerify` already use.
Bool FossilDeltaApply(U8 *source, I64 source_len, U8 *delta, I64 delta_len,
                       U8 *target_out, I64 *target_len_out)
{
  I64 pos = 0;
  I64 declared_target_len;
  I64 n = FossilGetInt(delta, pos, &declared_target_len);
  if (n == 0) return FALSE;
  pos += n;
  if (delta[pos] != '\n') return FALSE;
  pos += 1;

  // The loop terminates once `tlen` reaches the header's own declared
  // target length - NOT by scanning for a ';' delimiter. An earlier
  // version used `delta[pos] != ';'` as the "more segments?" check,
  // which is genuinely ambiguous: the trailer's own checksum digits
  // are never ';' either (only the character after all of them is),
  // so it misread the checksum as a bogus extra segment's length and
  // overran both `delta` and `target_out` - a real, reproduced VM
  // reset, not just a logic error (experiments/68-fossil-delta-format/).
  I64 tlen = 0;
  while (tlen < declared_target_len) {
    I64 seg_len;
    I64 an = FossilGetInt(delta, pos, &seg_len);
    if (an == 0) return FALSE;
    pos += an;
    U8 op = delta[pos];
    pos += 1;
    if (op == ':') {
      I64 li;
      for (li=0; li<seg_len; li++) target_out[tlen++] = delta[pos+li];
      pos += seg_len;
    } else if (op == '@') {
      // Copy segment: seg_len bytes from offset (read next int) in
      // source. Not produced by FossilDeltaMakeTrivial yet, but
      // parsed here so this function is ready for a real diff
      // encoder without changing its own contract.
      I64 srcoff;
      I64 on = FossilGetInt(delta, pos, &srcoff);
      if (on == 0) return FALSE;
      pos += on;
      if (delta[pos] != ',') return FALSE;
      pos += 1;
      I64 ci;
      for (ci=0; ci<seg_len; ci++) target_out[tlen++] = source[srcoff+ci];
    } else {
      return FALSE; // unknown segment op - malformed delta
    }
  }

  // Trailer is <checksum-digits>';' - the checksum integer comes
  // FIRST, then the ';' terminator. An earlier version checked for
  // ';' before reading the checksum, which is backwards (`delta[pos]`
  // right after the segment loop is the checksum's own first digit,
  // never ';' itself) and always failed here.
  I64 declared_checksum;
  I64 cn = FossilGetInt(delta, pos, &declared_checksum);
  if (cn == 0) return FALSE;
  pos += cn;
  if (pos >= delta_len || delta[pos] != ';') return FALSE;
  pos += 1;

  if (tlen != declared_target_len) return FALSE;
  // real_checksum is a function's own U32 return value - cast to
  // (U64) then masked, matching FossilDeltaMakeTrivial's own encode
  // side, not cast directly to (I64).
  U32 real_checksum = FossilChecksum(target_out, tlen);
  if ((real_checksum(U64) & 0xFFFFFFFF) != declared_checksum) return FALSE;

  *target_len_out = tlen;
  return TRUE;
}

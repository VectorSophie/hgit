// Probe 80c: replicate FossilChecksum's exact byte-read-and-shift
// arithmetic INLINE in the test function (no call to FossilChecksum
// at all) - isolates whether the bug is in the arithmetic pattern
// itself (would reproduce here too) or specific to how FossilChecksum
// as a separate function gets compiled.
U0 P80cInlineArith()
{
  U8 *data = "hello there, big wide world!";
  I64 len = StrLen(data);
  CommPrint(1, "IA_LEN=%d\n", len);

  U64 sum = 0;
  I64 pos = 0;
  while (pos + 4 <= len) {
    U64 word = (data[pos](U64) << 24) | (data[pos+1](U64) << 16) |
               (data[pos+2](U64) << 8) | data[pos+3](U64);
    CommPrint(1, "IA_WORD pos=%d word=%d\n", pos, word & 0xFFFFFFFF);
    sum += word;
    pos += 4;
  }
  CommPrint(1, "IA_SUM=%d EXPECTED=1432286299\n", sum & 0xFFFFFFFF);
}
P80cInlineArith;

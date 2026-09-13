// Probe 80d: does explicitly masking each byte with & 0xFF after the
// (U64) cast, before shifting, fix the checksum? Hypothesis: the
// (U64) cast doesn't reliably zero-extend ALL upper bits - a subtler
// variant of the documented (I64)-cast-garbage quirk that a
// single-byte-print test wouldn't have caught, but shifting left by
// 24 and OR-ing several such values together would expose.
U0 P80dMaskedArith()
{
  U8 *data = "hello there, big wide world!";
  I64 len = StrLen(data);
  CommPrint(1, "MA_LEN=%d\n", len);

  U64 sum = 0;
  I64 pos = 0;
  while (pos + 4 <= len) {
    U64 word = ((data[pos](U64) & 0xFF) << 24) | ((data[pos+1](U64) & 0xFF) << 16) |
               ((data[pos+2](U64) & 0xFF) << 8) | (data[pos+3](U64) & 0xFF);
    CommPrint(1, "MA_WORD pos=%d word=%d\n", pos, word & 0xFFFFFFFF);
    sum += word;
    pos += 4;
  }
  CommPrint(1, "MA_SUM=%d EXPECTED=1432286299\n", sum & 0xFFFFFFFF);
}
P80dMaskedArith;

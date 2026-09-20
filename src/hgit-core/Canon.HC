// --- v1.8.9: optional on-screen output -------------------------------
// Every hgit command reports through CommPrint, which TempleOS's own
// Comm.HC sends ONLY to a serial port - fine for the automated test
// harness (it reads the serial log), but a person typing at the QEMU
// window saw nothing at all. This redefinition (same signature as
// Comm.HC's, same serial behavior) additionally echoes to the screen
// when `hgit_screen_out` is set. Default OFF so the test/dev harness
// is unchanged; `Hgit("interactive");` turns it on (and AutoComplete
// off) for a person at the console.
I64 hgit_screen_out = 0;

// PutS interprets DolDoc `$` commands, so a literal `$` is doubled first.
U0 HgitScreenPut(U8 *s)
{
  U8 *o = MAlloc(StrLen(s)*2 + 2);
  I64 i, j = 0;
  for (i=0; s[i]; i++) {
    o[j++] = s[i];
    if (s[i] == '$') o[j++] = '$';
  }
  o[j] = 0;
  PutS(o);
  Free(o);
}

U0 CommPrint(I64 port, U8 *fmt, ...)
{
  U8 *buf = StrPrintJoin(NULL, fmt, argc, argv);
  CommPutS(port, buf);
  if (hgit_screen_out) HgitScreenPut(buf);
  Free(buf);
}

// FileRead prints a red "File not found" error on the screen when the
// file is missing - and hgit deliberately probes for missing files (a
// new repo has no metadata file yet, `init` checks the path is free).
// Every hgit read goes through this instead: NULL, silently, if absent.
U8 *HgitFileRead(U8 *name, I64 *size)
{
  if (!FileFind(name)) return NULL;
  return FileRead(name, size);
}

// Canon.HC — canonical little-endian integer encode/decode for hgit's
// on-disk formats. This is the first piece of hgit-core: everything
// persisted (object headers, index entries, archive metadata) goes
// through these, never a raw struct memcpy.
//
// Why not just write the struct bytes directly: HolyC has no declared
// struct packing/alignment guarantee documented yet (open question,
// doc 01), and native byte order should never leak into a portable
// repository format regardless. Fixed-width, explicit-byte-order
// encode/decode sidesteps both concerns at the cost of a few more lines.
//
// IMPORTANT HolyC quirk, confirmed by testing (see
// experiments/03-canonical-encoding/): a function declared to return
// U32 (or any width narrower than 64 bits) does NOT get its result
// truncated to that width automatically. Accumulating shifted bytes
// into a wider (U64) local and explicitly masking with `& 0xFFFFFFFF`
// before returning is required, or garbage high bits leak into the
// caller (verified: printing the "raw" unmasked result showed correct
// low 32 bits with ~20 bits of leftover garbage above them). Every
// GetU32LE-shaped function in this file masks explicitly for this
// reason — don't remove the mask as "redundant."
//
// Second HolyC quirk, confirmed the same way: there is no C-style
// prefix typecast `(U32)x`. HolyC uses a POSTFIX typecast: `x(U32)`.
// See holyc-parser's corpus entry
// tests/corpus/passing/079-expr-expr-postfix-typecast.hc in
// experiments/templeos-devkit for the authoritative example this was
// checked against.

U0 PutU32LE(U8 *buf, I64 off, U32 v)
{
  buf[off+0] = v & 0xFF;
  buf[off+1] = (v >> 8)  & 0xFF;
  buf[off+2] = (v >> 16) & 0xFF;
  buf[off+3] = (v >> 24) & 0xFF;
}

U32 GetU32LE(U8 *buf, I64 off)
{
  U64 v = buf[off] | (buf[off+1] << 8) | (buf[off+2] << 16)
        | (buf[off+3](U64) << 24);
  return v & 0xFFFFFFFF;
}

U0 PutU64LE(U8 *buf, I64 off, U64 v)
{
  I64 i;
  for (i = 0; i < 8; i++) buf[off+i] = (v >> (i*8)) & 0xFF;
}

U64 GetU64LE(U8 *buf, I64 off)
{
  U64 v = 0;
  I64 i;
  for (i = 0; i < 8; i++) v |= buf[off+i](U64) << (i*8);
  return v;
}

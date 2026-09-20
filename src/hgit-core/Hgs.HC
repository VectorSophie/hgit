// Hgs.HC — .HGS archive file header, per FORMAT.md.
//
// A .HGS file is: [16-byte header][object records, see Archive.HC].
// Verified end-to-end on real TempleOS (write, FileWrite to disk,
// FileRead back, header parsed, every object hash re-verified) — see
// experiments/06-hgs-format/.
//
// Depends on Canon.HC and Archive.HC (for HgsPut's record shape and
// ArchiveVerify for checking the object section). Load both first.

// Header layout (16 bytes total, all multi-byte fields little-endian):
//   [0..3]  magic: the ASCII bytes 'H' 'G' 'S' '0'
//   [4..5]  U16 format_version
//   [6..7]  U16 reserved (must be 0; readers should ignore, not reject,
//           a nonzero value here for now - no meaning assigned yet)
//   [8..15] U64 object_count
U0 HgsWriteHeader(U8 *buf, U16 version, U64 obj_count)
{
  buf[0]='H'; buf[1]='G'; buf[2]='S'; buf[3]='0';
  buf[4] = version & 0xFF;
  buf[5] = (version >> 8) & 0xFF;
  buf[6] = 0;
  buf[7] = 0;
  PutU64LE(buf, 8, obj_count);
}

// Returns FALSE (and leaves *version_out/*obj_count_out unset) if the
// magic bytes don't match - callers must check this before trusting the
// rest of the buffer as a .HGS file.
// v1.8.7: a repository written by a NEWER hgit (format_version above what
// this build understands) is rejected instead of being half-read - older
// versions (1..HGS_MAX_SUPPORTED_VERSION) still read fine, every bump so
// far having been additive (FORMAT.md's "Versioning policy"). The offending
// version is left in `hgs_unsupported_version` so a caller can say why.
#define HGS_MAX_SUPPORTED_VERSION 4
I64 hgs_unsupported_version = 0;

Bool HgsReadHeader(U8 *buf, U16 *version_out, U64 *obj_count_out)
{
  hgs_unsupported_version = 0;
  if (buf[0]!='H' || buf[1]!='G' || buf[2]!='S' || buf[3]!='0') return FALSE;
  *version_out = buf[4] | (buf[5] << 8);
  *obj_count_out = GetU64LE(buf, 8);
  if (*version_out > HGS_MAX_SUPPORTED_VERSION) {
    hgs_unsupported_version = *version_out;
    return FALSE;
  }
  return TRUE;
}

// Parameterized object-append (writes into archive_buf/len rather than
// Archive.HC's ArchivePut's fixed globals - this is the first tested
// instance of the parameterized version Archive.HC's own comments flag
// as "future work, not yet verified." It is verified now.) Same record
// shape as ArchivePut: [U64 length][data][64-byte BLAKE2b hash].
U0 HgsPut(U8 *archive_buf, I64 *len, U8 *data, I64 dlen)
{
  U8 h[64];
  I64 i;
  B2Hash512Any(data, dlen, h);
  PutU64LE(archive_buf, *len, dlen);
  *len += 8;
  for (i=0; i<dlen; i++) archive_buf[*len+i] = data[i];
  *len += dlen;
  for (i=0; i<64; i++) archive_buf[*len+i] = h[i];
  *len += 64;
}

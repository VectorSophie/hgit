// Object.HC — typed objects on top of the .HGS record format.
//
// Per ADR 0001/0003: the base .HGS record ([length][data][hash], see
// Archive.HC/Hgs.HC) is an undifferentiated byte blob. This file adds
// hgit's actual object types (blob/tree/commit-equivalent) by
// prepending a single type-tag byte to the content BEFORE hashing and
// storing it — so the type participates in the content address, the
// same way Git's "blob <size>\0" header does. Verified
// (experiments/07-object-typing/): identical bytes stored as two
// different types hash differently, exactly as intended.
//
// Depends on Hgs.HC (HgsPut) and, transitively, Canon.HC/Blake2b.HC.

#define OBJ_BLOB   1
#define OBJ_TREE   2
#define OBJ_COMMIT 3
#define OBJ_ATTRS  4 // ADR 0015: a commit's own (entity_id -> mode) list, see Attrs.HC
#define OBJ_CONFLICT 5 // ADR 0016: one merge conflict's persistent base/ours/theirs evidence, see Conflict.HC

// Tags `data` with `type` and appends it as one .HGS record. HgsPut
// underneath hashes via B2Hash512Any, so there's no BLAKE2b block-size
// cap. This function's own scratch buffer used to be a fixed
// `tagged[4096]` stack array (dlen+1 <= 4096) - a real, shared
// per-object-content ceiling every caller (Offer.HC's own blob/tree
// content, Commit.HC's commit encoding) inherited silently. Probe 105
// (experiments/105-objectput-dynamic-tag/) found it's the actual root
// cause behind `Offer.HC`'s own separate `fsize+1 > 512` file-size
// skip (that guard exists BELOW this one and would still trip first
// today - see that probe's own "what this does not do" - but this is
// the real, shared, lower-level limit any fix at that layer would
// still be blocked by). `MAlloc`'d at exactly `dlen+1`, freed after
// the one `HgsPut` call that needs it - same "no guessed cap" pattern
// ADR 0007 already established for `Offer.HC`'s own `archive` buffer.
// Verified up to a real 10,000-byte object round-tripping correctly
// through `ArchiveVerify` (`experiments/105-objectput-dynamic-tag/`),
// well past the old 4095-byte ceiling.
U0 ObjectPut(U8 *archive_buf, I64 *len, U8 type, U8 *data, I64 dlen)
{
  U8 *tagged = MAlloc(dlen+1);
  I64 i;
  tagged[0] = type;
  for (i=0; i<dlen; i++) tagged[1+i] = data[i];
  HgsPut(archive_buf, len, tagged, dlen+1);
  Free(tagged);
}

// 1.9 (ADR 0019 section 1): same call shape as ObjectPut, but appends
// only if no record with this object's hash is already in the buffer -
// neither one loaded from disk nor one appended earlier by this same
// command. `archive_buf` must be a whole .HGS buffer (records from byte
// 16, `*len` the whole length), which is how every writer builds it. The
// tagged hash is computed once and handed to HgsPutHashed; the scan
// compares stored hashes a U64 at a time (HashEq64) and stops at a torn
// tail (RecordEnd). Skipping never reorders what is appended.
// ponytail: O(records) scan per put; a hash-ordered index if offer's
// per-put cost ever shows up next to BLAKE2b in the on-platform numbers.
U0 ObjectPutOnce(U8 *archive_buf, I64 *len, U8 type, U8 *data, I64 dlen)
{
  U8 *tagged = MAlloc(dlen+1);
  U8 h[64];
  I64 i, pos = 16, end;
  Bool found = FALSE;
  tagged[0] = type;
  for (i=0; i<dlen; i++) tagged[1+i] = data[i];
  B2Hash512Any(tagged, dlen+1, h);
  while (!found && pos < *len) {
    end = RecordEnd(archive_buf, pos, *len);
    if (end < 0) break;
    if (HashEq64(archive_buf + end - 64, h)) found = TRUE;
    pos = end;
  }
  if (!found) HgsPutHashed(archive_buf, len, tagged, dlen+1, h);
  Free(tagged);
}

// Reads the type tag of the object record whose length field starts at
// `offset` within archive_buf - i.e. offset is the same value ObjectPut
// returned via *len *before* that call (the record's start position).
U8 ObjectPeekType(U8 *archive_buf, I64 offset)
{
  I64 pos = offset + 8; // skip the 8-byte length field
  return archive_buf[pos];
}

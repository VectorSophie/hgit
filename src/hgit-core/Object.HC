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

// Tags `data` with `type` and appends it as one .HGS record. HgsPut
// underneath hashes via B2Hash512Any, so there's no BLAKE2b block-size
// cap; this function's own `tagged[4096]` scratch buffer is the only
// remaining limit (dlen+1 <= 4096), verified up to a 146-byte tree
// object in experiments/10-tree-object/. Bump further (or switch to
// MAlloc) if a real object ever needs more - not yet exercised past
// this size.
U0 ObjectPut(U8 *archive_buf, I64 *len, U8 type, U8 *data, I64 dlen)
{
  U8 tagged[4096];
  I64 i;
  tagged[0] = type;
  for (i=0; i<dlen; i++) tagged[1+i] = data[i];
  HgsPut(archive_buf, len, tagged, dlen+1);
}

// Reads the type tag of the object record whose length field starts at
// `offset` within archive_buf - i.e. offset is the same value ObjectPut
// returned via *len *before* that call (the record's start position).
U8 ObjectPeekType(U8 *archive_buf, I64 offset)
{
  I64 pos = offset + 8; // skip the 8-byte length field
  return archive_buf[pos];
}

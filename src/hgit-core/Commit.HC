// Commit.HC — commit object content: a tree reference, zero or more
// parent references, a timestamp, a message, and (per ADR 0005) an
// optional typed relation to an earlier commit. This is what goes in
// the `data`/`dlen` passed to ObjectPut with type=OBJ_COMMIT - the
// content design ADR 0001/FORMAT.md deferred alongside tree content.
// Verified end-to-end (root commit with 0 parents, child commit with 1
// parent referencing the root, both referencing the same tree) in
// experiments/11-commit-object/; the relation fields verified in
// experiments/50-relation-vocabulary/.
//
// Content format:
//   64 bytes  tree_hash
//   U8        parent_count
//   repeated parent_count times: 64 bytes parent_hash
//   U64       timestamp LE (seconds; epoch/meaning not yet decided -
//             just an opaque monotonic-ish number so far)
//   U32       message_len LE
//   message_len bytes of message (no encoding assumed - opaque bytes)
//   U8        relation_tag (0=none/plain continuation, 1=CONTINUES
//             explicit, 2=CORRECTS, 3=REVERTS, 4=RECONCILES)
//   if relation_tag != 0: 64 bytes relation_target_hash (the prior
//             commit this relation names - not necessarily the parent;
//             a correction can name a commit further back)
//
// The relation fields are placed AFTER the message deliberately: every
// accessor that reads UP TO the message (CommitTimestamp/
// CommitMessageLen/CommitMessage) keeps its existing offset math
// unchanged. Anything reading the relation fields recomputes from
// CommitMessageLen instead of assuming a fixed offset.
//
// Stable entity identity (ADR 0004, Tree.HC's per-entry entity_id) is
// a separate concern from this file - this ADR (0005) does NOT yet
// scope a relation to a specific entity within a commit, only to
// another commit as a whole. See ADR 0005's own "what this slice does
// not do."
//
// Depends on Canon.HC (PutU64LE/GetU64LE/PutU32LE/GetU32LE).

#define REL_NONE      0
#define REL_CONTINUES 1
#define REL_CORRECTS  2
#define REL_REVERTS   3
#define REL_RECONCILES 4

// `relation_tag`/`relation_target` may be REL_NONE/NULL for an
// ordinary commit with no explicit relation (the common case - costs
// exactly one byte).
U0 CommitEncode(U8 *buf, I64 *len, U8 *tree_hash, U8 *parent_hashes,
                U8 parent_count, U64 timestamp, U8 *message, I64 message_len,
                U8 relation_tag, U8 *relation_target)
{
  I64 i, j;
  for (i=0; i<64; i++) buf[*len+i] = tree_hash[i];
  *len += 64;
  buf[*len] = parent_count; *len += 1;
  for (i=0; i<parent_count; i++) {
    for (j=0; j<64; j++) buf[*len+j] = parent_hashes[i*64+j];
    *len += 64;
  }
  PutU64LE(buf, *len, timestamp); *len += 8;
  PutU32LE(buf, *len, message_len); *len += 4;
  for (i=0; i<message_len; i++) buf[*len+i] = message[i];
  *len += message_len;

  buf[*len] = relation_tag; *len += 1;
  if (relation_tag != REL_NONE) {
    for (i=0; i<64; i++) buf[*len+i] = relation_target[i];
    *len += 64;
  }
}

// Accessors - all take a pointer to the start of commit content (i.e.
// the object's data with the OBJ_COMMIT type tag byte already
// stripped), matching the convention Tree.HC's TreeFindEntry uses.
U8 *CommitTreeHash(U8 *buf) { return buf; }
U8 CommitParentCount(U8 *buf) { return buf[64]; }
U8 *CommitParentHash(U8 *buf, I64 idx) { return buf + 65 + idx*64; }

U64 CommitTimestamp(U8 *buf)
{
  I64 pos = 65 + CommitParentCount(buf)*64;
  return GetU64LE(buf, pos);
}

U32 CommitMessageLen(U8 *buf)
{
  I64 pos = 65 + CommitParentCount(buf)*64 + 8;
  return GetU32LE(buf, pos);
}

U8 *CommitMessage(U8 *buf)
{
  I64 pos = 65 + CommitParentCount(buf)*64 + 8 + 4;
  return buf + pos;
}

// Byte offset (relative to `buf`) of the relation_tag field - shared
// by both relation accessors below, so the "recompute, don't assume a
// fixed offset" rule from this file's own header comment lives in
// exactly one place.
I64 CommitRelationOffset(U8 *buf)
{
  I64 pos = 65 + CommitParentCount(buf)*64 + 8 + 4 + CommitMessageLen(buf);
  return pos;
}

U8 CommitRelationTag(U8 *buf)
{
  return buf[CommitRelationOffset(buf)];
}

// Only valid to call if CommitRelationTag(buf) != REL_NONE - returns a
// pointer to the 64-byte target hash.
U8 *CommitRelationTarget(U8 *buf)
{
  return buf + CommitRelationOffset(buf) + 1;
}

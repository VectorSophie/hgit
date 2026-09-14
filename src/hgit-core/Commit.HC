// Commit.HC — commit object content: a tree reference, zero or more
// parent references, a timestamp, a message, and (per ADR 0005/0006)
// an optional typed relation to an earlier commit, optionally scoped
// to a specific tracked entity. This is what goes in the `data`/`dlen`
// passed to ObjectPut with type=OBJ_COMMIT - the content design ADR
// 0001/FORMAT.md deferred alongside tree content. Verified end-to-end
// (root commit with 0 parents, child commit with 1 parent referencing
// the root, both referencing the same tree) in
// experiments/11-commit-object/; the relation fields verified in
// experiments/50-relation-vocabulary/; entity-scoping in
// experiments/53-entity-scoped-relations/.
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
//   if relation_tag != 0:
//     64 bytes relation_target_hash (the prior commit this relation
//               names - not necessarily the parent; a correction can
//               name a commit further back)
//     U64      relation_entity_id (0 = not entity-scoped, the relation
//               applies to the whole commit - ADR 0005's original
//               behavior; any other value names a specific entity ID
//               from ADR 0004's tree entries. 0 as "unscoped" is a
//               practical sentinel, not formally collision-proof - a
//               real GenerateEntityId() landing on exactly 0 is
//               vanishingly unlikely, same honest caveat OpLog.HC's
//               own all-zero prev_head sentinel already carries.)
//   U8        has_attrs (ADR 0015 - 0 = no non-default file mode
//             exists anywhere in this commit's own tree, the common
//             case, costs exactly one byte)
//   if has_attrs != 0:
//     64 bytes attrs_hash (a real OBJ_ATTRS object - Attrs.HC - listing
//               every entity ID in this commit whose effective mode is
//               non-default, i.e. binary and/or executable)
//
// The relation fields are placed AFTER the message deliberately, and
// has_attrs AFTER the relation fields, for the same reason: every
// accessor that reads UP TO the message (CommitTimestamp/
// CommitMessageLen/CommitMessage) keeps its existing offset math
// unchanged, and everything past it recomputes its own start offset
// from what came before rather than assuming a fixed position. A
// commit written before ADR 0015 simply has no room for has_attrs at
// all - detected by a real bounds check against the record's own
// content length (CommitHasAttrs), not a version branch; reading an
// ADR-0015-aware field back out of an older commit correctly reports
// "no attrs" rather than reading garbage.
//
// Depends on Canon.HC (PutU64LE/GetU64LE/PutU32LE/GetU32LE).

#define REL_NONE      0
#define REL_CONTINUES 1
#define REL_CORRECTS  2
#define REL_REVERTS   3
#define REL_RECONCILES 4

// `relation_tag`/`relation_target` may be REL_NONE/NULL for an
// ordinary commit with no explicit relation (the common case - costs
// exactly one byte). `relation_entity_id` is ignored when
// relation_tag is REL_NONE; pass 0 for "not entity-scoped" otherwise.
//
// ADR 0015 (docs/adr/0015-file-attributes-and-modes.md): `has_attrs`/
// `attrs_hash` are a real, separate optional field placed AFTER the
// relation fields, same "recompute from CommitMessageLen, don't
// assume a fixed offset" convention this file's own header comment
// already established for the relation fields themselves - has_attrs
// may be FALSE/NULL for a commit where every tracked file is plain
// text and non-executable (the common case, costs exactly one byte).
U0 CommitEncode(U8 *buf, I64 *len, U8 *tree_hash, U8 *parent_hashes,
                U8 parent_count, U64 timestamp, U8 *message, I64 message_len,
                U8 relation_tag, U8 *relation_target, U64 relation_entity_id,
                Bool has_attrs, U8 *attrs_hash)
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
    PutU64LE(buf, *len, relation_entity_id); *len += 8;
  }

  buf[*len] = has_attrs; *len += 1;
  if (has_attrs) {
    for (i=0; i<64; i++) buf[*len+i] = attrs_hash[i];
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

// Only valid to call if CommitRelationTag(buf) != REL_NONE - returns
// the entity ID this relation is scoped to (0 = not entity-scoped,
// applies to the whole commit - see this file's own header comment on
// why 0 is a safe sentinel).
U64 CommitRelationEntityId(U8 *buf)
{
  return GetU64LE(buf, CommitRelationOffset(buf) + 1 + 64);
}

// ADR 0015: byte offset where the `has_attrs` field would be, if
// present - right after the relation section (present or not).
I64 CommitAttrsOffset(U8 *buf)
{
  I64 pos = CommitRelationOffset(buf) + 1;
  if (buf[CommitRelationOffset(buf)] != REL_NONE) pos += 64 + 8;
  return pos;
}

// `content_len` is the commit object's own real content length (the
// .HGS record's length minus the one OBJ_COMMIT type-tag byte - the
// same value every real caller already computes as `rec_len - 1` when
// reading a commit from the archive). A commit written before ADR
// 0015 (or one where has_attrs was simply never set) has no attrs
// field at all - detected here with a real bounds check, not a
// version branch: if there isn't room for the has_attrs byte itself,
// there is no attrs field, full stop.
Bool CommitHasAttrs(U8 *buf, I64 content_len)
{
  I64 pos = CommitAttrsOffset(buf);
  if (pos >= content_len) return FALSE;
  return buf[pos] != 0;
}

// Only valid to call if CommitHasAttrs(buf, content_len) is TRUE.
U8 *CommitAttrsHash(U8 *buf)
{
  return buf + CommitAttrsOffset(buf) + 1;
}

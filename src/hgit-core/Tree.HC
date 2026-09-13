// Tree.HC — tree object content: an entry list mapping name -> child
// object (type + hash), plus (per ADR 0004) a stable per-entry entity
// ID. This is what goes in the `data`/`dlen` passed to ObjectPut with
// type=OBJ_TREE. Verified end-to-end (encode, store via ObjectPut,
// FileWrite, FileRead, decode, look up both entries by name) in
// experiments/10-tree-object/; the entity ID field added in
// experiments/49-entity-id/.
//
// Content format:
//   U32 entry_count
//   repeated entry_count times:
//     U8 name_len
//     name_len bytes of name (flat, single-level - no path separators
//     or nesting handled here; a name is just an arbitrary byte string)
//     U8 child_type   (OBJ_BLOB or OBJ_TREE, see Object.HC)
//     64 bytes child_hash (BLAKE2b-512 content address of the child)
//     8 bytes entity_id (U64, LE) — a stable identifier for "this
//       tracked name," independent of content. Per ADR 0004: generated
//       fresh (two RandU32 reads) the first time a name appears in any
//       tree this repo has built, and copied forward unchanged into
//       every later tree that still has an entry for that name -
//       Offer.HC is what actually does the carrying-forward, by
//       looking up the previous tree before building the new one.
//       Deliberately minimal: same name = same identity; an actual
//       rename (name change) is NOT detected and gets a fresh ID, see
//       ADR 0004's "What this slice does not do."
//
// Depends on Canon.HC (PutU32LE/GetU32LE/PutU64LE/GetU64LE) and
// Object.HC's OBJ_* tags.

// Combines two RandU32 reads into a random 64-bit entity ID. RandU32
// confirmed real and usable on real TempleOS in experiments/48-rand-for-identity/
// (both from primary source usage - a real filesystem serial number -
// and empirically: three successive reads returned distinct values).
U64 GenerateEntityId()
{
  U32 a = RandU32;
  U32 b = RandU32;
  return (a(U64) << 32) | b(U64);
}

// Appends one entry to a tree-content buffer being built. Caller is
// responsible for writing the U32 entry_count prefix themselves (not
// done here, since it isn't known until all entries are appended) -
// see experiments/10-tree-object/'s test driver for the pattern.
U0 TreeEncodeEntry(U8 *buf, I64 *len, U8 *name, I64 name_len,
                    U8 child_type, U8 *child_hash, U64 entity_id)
{
  I64 i;
  buf[*len] = name_len; *len += 1;
  for (i=0; i<name_len; i++) buf[*len+i] = name[i];
  *len += name_len;
  buf[*len] = child_type; *len += 1;
  for (i=0; i<64; i++) buf[*len+i] = child_hash[i];
  *len += 64;
  PutU64LE(buf, *len, entity_id); *len += 8;
}

// Finds the entry named `name` (name_len bytes) inside a decoded tree
// content buffer (tree_buf points at the U32 entry_count, i.e. the
// object's content with the OBJ_TREE type tag byte already stripped)
// and copies its type into *type_out, hash into hash_out (64 bytes),
// and entity ID into *entity_id_out. Returns FALSE if not found.
// Linear scan - fine for tiny trees, not yet a real index (same
// caveat as Archive.HC's ArchiveVerify).
Bool TreeFindEntry(U8 *tree_buf, I64 tree_len, U8 *name, I64 name_len,
                    U8 *type_out, U8 *hash_out, U64 *entity_id_out)
{
  U32 count = GetU32LE(tree_buf, 0);
  I64 pos = 4;
  U32 e;
  for (e=0; e<count; e++) {
    U8 this_name_len = tree_buf[pos]; pos += 1;
    Bool same = (this_name_len == name_len);
    I64 i;
    if (same) for (i=0; i<name_len; i++) if (tree_buf[pos+i]!=name[i]) same=FALSE;
    U8 this_type = tree_buf[pos+this_name_len];
    U8 *this_hash = tree_buf + pos + this_name_len + 1;
    U64 this_entity_id = GetU64LE(tree_buf, pos+this_name_len+1+64);
    if (same) {
      *type_out = this_type;
      for (i=0; i<64; i++) hash_out[i] = this_hash[i];
      *entity_id_out = this_entity_id;
      return TRUE;
    }
    pos += this_name_len + 1 + 64 + 8;
  }
  return FALSE;
}

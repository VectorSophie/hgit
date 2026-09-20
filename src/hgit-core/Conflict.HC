// Conflict.HC — `OBJ_CONFLICT` object content: one conflict's full,
// persistent evidence. Design decided in
// `docs/adr/0016-conflict-as-repository-data.md` - read that first,
// this file only implements what it already decided.
//
// Same real split this project already uses everywhere: this file is
// the OBJECT content format (like `Attrs.HC` is to `OBJ_ATTRS`), while
// the mutable in-progress-merge bookkeeping that REFERENCES these
// objects lives in `Meta.HC` (like `OBJ_ATTRS`'s own `has_attrs`/
// `attrs_hash` commit fields live in `Commit.HC`).
//
// `present`/`type`/`mode`/`hash` are three PARALLEL arrays throughout
// this file, index 0=base, 1=ours, 2=theirs - the same flat-array
// convention Merge.HC's own conflict_names list already uses, not a
// new struct/class introduced just for this.
//
// Depends on Canon.HC (GetU64LE/PutU64LE), Object.HC (OBJ_CONFLICT).

#define CONFLICT_KIND_CONTENT 0x01
#define CONFLICT_KIND_MODE    0x02
#define CONFLICT_KIND_TYPE    0x04 // a real kind mismatch - OBJ_TREE
                                   // on one side, OBJ_BLOB on another

// Content shape (see ADR 0016 for the full rationale):
//   U8  conflict_kind
//   U64 entity_id           (0 if no single shared identity applies)
//   U8  path_len
//   path_len bytes of path
//   for i in 0,1,2 (base, ours, theirs):
//     U8 present
//     if present: U8 type; U8 mode; 64 bytes hash
U0 ConflictEncode(U8 *buf, I64 *len, U8 conflict_kind, U64 entity_id,
                  U8 *path, I64 path_len,
                  Bool *present, U8 *type, U8 *mode, U8 *hash)
{
  I64 pos = *len;
  buf[pos] = conflict_kind; pos += 1;
  PutU64LE(buf, pos, entity_id); pos += 8;
  buf[pos] = path_len; pos += 1;
  I64 pci;
  for (pci=0; pci<path_len; pci++) buf[pos+pci] = path[pci];
  pos += path_len;

  I64 side;
  for (side=0; side<3; side++) {
    if (present[side]) {
      buf[pos] = 1; pos += 1;
      buf[pos] = type[side]; pos += 1;
      buf[pos] = mode[side]; pos += 1;
      I64 hi;
      for (hi=0; hi<64; hi++) buf[pos+hi] = hash[side*64+hi];
      pos += 64;
    } else {
      buf[pos] = 0; pos += 1;
    }
  }
  *len = pos;
}

// Decodes one OBJ_CONFLICT object's content (already stripped of its
// leading type tag byte, same convention every other object reader in
// this project uses) back into its real fields. `path_out` must be at
// least 256 bytes (same real path-length ceiling every other command
// already uses). `hash_out` must be 192 bytes (3*64).
U0 ConflictDecode(U8 *buf, U8 *conflict_kind_out, U64 *entity_id_out,
                  U8 *path_out, I64 *path_len_out,
                  Bool *present_out, U8 *type_out, U8 *mode_out, U8 *hash_out)
{
  I64 pos = 0;
  *conflict_kind_out = buf[pos]; pos += 1;
  *entity_id_out = GetU64LE(buf, pos); pos += 8;
  U8 path_len = buf[pos]; pos += 1;
  I64 pci;
  for (pci=0; pci<path_len; pci++) path_out[pci] = buf[pos+pci];
  path_out[path_len] = 0;
  pos += path_len;
  *path_len_out = path_len;

  I64 side;
  for (side=0; side<3; side++) {
    U8 present = buf[pos]; pos += 1;
    if (present) {
      present_out[side] = TRUE;
      type_out[side] = buf[pos]; pos += 1;
      mode_out[side] = buf[pos]; pos += 1;
      I64 hi;
      for (hi=0; hi<64; hi++) hash_out[side*64+hi] = buf[pos+hi];
      pos += 64;
    } else {
      present_out[side] = FALSE;
      type_out[side] = 0;
      mode_out[side] = 0;
    }
  }
}

// v1.8.7 (adversarial hardening): true only if `buf` (an OBJ_CONFLICT
// object's content, `len` bytes) is exactly the shape ConflictEncode
// writes - every length/present field in range, no trailing bytes.
// ConflictDecode trusts its input, so callers that can meet a corrupt or
// hostile archive check this first.
Bool ConflictContentValid(U8 *buf, I64 len)
{
  if (len < 10) return FALSE;
  I64 pos = 10 + buf[9];
  I64 side;
  for (side=0; side<3; side++) {
    if (pos >= len) return FALSE;
    U8 present = buf[pos]; pos += 1;
    if (present > 1) return FALSE;
    if (present) {
      pos += 66;
      if (pos > len) return FALSE;
    }
  }
  return pos == len;
}

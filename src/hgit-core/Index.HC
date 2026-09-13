// Index.HC — hash -> offset lookup over a .HGS object section.
//
// The last piece ADR 0001/FORMAT.md flagged as missing: until this,
// nothing could answer "where is the object with this hash" - every
// probe that needed an object's location tracked its offset by hand
// (e.g. `tree_off = alen` right after the ObjectPut call that created
// it). That's fragile: experiments/12-index/ hit a real crash (a
// General Protection fault inside TreeFindEntry) caused by exactly this
// kind of hand-computed offset being wrong by a few bytes after adding
// a header. The fix wasn't patching the arithmetic - it was building
// this and using IndexLookup instead of hand-tracking offsets at all.
//
// IndexBuild does one linear scan (same pattern/cost as
// Archive.HC's ArchiveVerify) and records each record's *stored* hash
// (not recomputed) plus its start offset. IndexLookup is still a linear
// scan over the result - no hash table yet, see "Not yet done" in
// experiments/12-index/README.md. Even without O(1) lookup, this is a
// real capability gain: nothing could look up "the object with this
// hash" at all before this file existed.
//
// Depends on Canon.HC (GetU64LE).

// Scans an archive's object section (NOT including the 16-byte .HGS
// header - pass archive_buf+16 / total_len-16 for a real .HGS file, see
// Hgs.HC), filling out_hashes (count*64 bytes) and out_offsets (count
// I64s, each the byte offset - relative to archive_buf - of that
// record's length field, i.e. the same offset ObjectPut's callers used
// to track by hand).
U0 IndexBuild(U8 *archive_buf, I64 total_len, U8 *out_hashes,
              I64 *out_offsets, I64 *out_count)
{
  I64 pos = 0, n = 0;
  while (pos < total_len) {
    I64 rec_start = pos;
    U64 len = GetU64LE(archive_buf, pos); pos += 8;
    pos += len;
    U8 *stored_hash = archive_buf + pos;
    I64 i;
    for (i=0; i<64; i++) out_hashes[n*64+i] = stored_hash[i];
    out_offsets[n] = rec_start;
    pos += 64;
    n++;
  }
  *out_count = n;
}

// Linear search - fine at hgit's current tiny scale, a real bottleneck
// once corpora grow (see "Not yet done"). Returns the record's offset
// (same convention as IndexBuild's out_offsets) via *offset_out, or
// FALSE if target_hash isn't present.
Bool IndexLookup(U8 *index_hashes, I64 *index_offsets, I64 count,
                  U8 *target_hash, I64 *offset_out)
{
  I64 i, j;
  for (i=0; i<count; i++) {
    Bool same = TRUE;
    for (j=0; j<64; j++) if (index_hashes[i*64+j] != target_hash[j]) same = FALSE;
    if (same) { *offset_out = index_offsets[i]; return TRUE; }
  }
  return FALSE;
}

// Same scan as IndexLookup, but returns the array position (0..count-1)
// instead of the byte offset - for a caller (Check.HC's dangling-object
// walk, experiments/72-check-dangling-objects/) that needs to mark a
// per-object "visited" flag in a parallel array indexed the same way
// IndexBuild filled index_hashes/index_offsets, not the raw byte offset
// IndexLookup returns.
Bool IndexLookupPos(U8 *index_hashes, I64 count, U8 *target_hash, I64 *pos_out)
{
  I64 i, j;
  for (i=0; i<count; i++) {
    Bool same = TRUE;
    for (j=0; j<64; j++) if (index_hashes[i*64+j] != target_hash[j]) same = FALSE;
    if (same) { *pos_out = i; return TRUE; }
  }
  return FALSE;
}

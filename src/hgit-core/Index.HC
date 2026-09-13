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
// (not recomputed) plus its start offset. IndexLookup is a linear
// scan over the result - every real command still uses this path.
// A real O(1)-expected hash table (IndexBuildHashTable/
// IndexLookupHashTable, probe 104) exists below but isn't wired into
// any call site yet - no evidence at hgit's current real scale (low
// hundreds of objects per repo) that the linear scan is a practical
// bottleneck, same "verify standalone before adopting" stance ADR
// 0008 took for Fossil.HC.
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

// A real hash table, per doc 06's own long-standing "Not yet done"
// item ("a real hash table for the index"). NOT yet wired into any
// call site (Offer.HC/History.HC/Status.HC/See.HC/ReconcileDoc.HC's
// own six IndexLookup callers all still use the linear scan above) -
// same "build and verify standalone before adopting" pattern this
// project already used for Fossil.HC (ADR 0008): no real evidence yet
// that hgit's current real scale (low hundreds of objects per repo,
// per ADR 0013's own note) makes the linear scan a practical
// bottleneck. Open addressing with linear probing, hashed on the
// first 8 bytes of the (already near-uniform, BLAKE2b-derived) stored
// hash - no need for a stronger mix, since collisions just cost one
// extra probe step either way.
//
// Caller picks table_size (IndexHashTableSize below suggests one) and
// MAllocs `table` itself - this file doesn't own that memory, matching
// every other dynamic buffer in this codebase since ADR 0007.
I64 IndexHashTableSize(I64 count)
{
  // Odd and comfortably larger than count halves real-world clustering
  // for open addressing without needing count to be prime.
  return count*2 + 1;
}

U0 IndexBuildHashTable(U8 *index_hashes, I64 count, I64 *table, I64 table_size)
{
  I64 i, slot;
  for (i=0; i<table_size; i++) table[i] = -1;
  for (i=0; i<count; i++) {
    U64 h = GetU64LE(index_hashes + i*64, 0);
    slot = h % table_size;
    while (table[slot] != -1) slot = (slot+1) % table_size;
    table[slot] = i;
  }
}

// Same contract as IndexLookup (byte offset out), but O(1) expected
// instead of O(count) - reads index_offsets[table[slot]] once a
// matching stored hash is confirmed, same as the linear version does.
Bool IndexLookupHashTable(U8 *index_hashes, I64 *index_offsets, I64 *table,
                           I64 table_size, U8 *target_hash, I64 *offset_out)
{
  U64 h = GetU64LE(target_hash, 0);
  I64 slot = h % table_size;
  I64 tries = 0, idx, j;
  Bool same;
  while (table[slot] != -1 && tries < table_size) {
    idx = table[slot];
    same = TRUE;
    for (j=0; j<64; j++) if (index_hashes[idx*64+j] != target_hash[j]) same = FALSE;
    if (same) { *offset_out = index_offsets[idx]; return TRUE; }
    slot = (slot+1) % table_size;
    tries++;
  }
  return FALSE;
}

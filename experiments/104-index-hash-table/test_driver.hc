// Probe 104 test driver: verifies Index.HC's new real hash table
// (IndexBuildHashTable/IndexLookupHashTable) against the existing
// linear-scan IndexLookup, over a real repo's real object index -
// not a synthetic array, the actual bytes IndexBuild produces from a
// real .HGS archive after 25 real offers (varying content, so each
// offer creates a genuinely distinct blob object, not a dedup-hit).
U0 P104IndexHashTableTest()
{
  Del("C:/Home/P104Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P104Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P104Repo.hgs");

  I64 i;
  U8 cmd[512];
  U8 content[64];
  for (i=0; i<25; i++) {
    StrPrint(content, "content number %d", i);
    FileWrite("C:/Home/P104FileA.txt", content, StrLen(content));
    StrPrint(cmd, "offer C:/Home/P104Repo.hgs P104FileA.txt offer_%d", i);
    Hgit(cmd);
  }

  I64 rsize;
  U8 *rbuf = FileRead("C:/Home/P104Repo.hgs", &rsize);
  U16 rver;
  U64 rcount;
  HgsReadHeader(rbuf, &rver, &rcount);

  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  CommPrint(1, "P104_OBJECT_COUNT=%d\n", idx_count);

  I64 table_size = IndexHashTableSize(idx_count);
  I64 *table = MAlloc(table_size*8);
  IndexBuildHashTable(idx_hashes, idx_count, table, table_size);

  // Every real stored hash must resolve to the SAME offset both ways.
  I64 mismatches = 0;
  I64 off_linear, off_table;
  Bool found_linear, found_table;
  for (i=0; i<idx_count; i++) {
    found_linear = IndexLookup(idx_hashes, idx_offsets, idx_count,
                                idx_hashes+i*64, &off_linear);
    found_table = IndexLookupHashTable(idx_hashes, idx_offsets, table,
                                        table_size, idx_hashes+i*64, &off_table);
    if (!found_linear || !found_table || off_linear != off_table) mismatches++;
  }
  CommPrint(1, "P104_REAL_HASH_MISMATCHES=%d\n", mismatches);

  // Two fabricated, definitely-absent hashes - both lookups must agree
  // "not found", not just "not crash".
  U8 fake_zero[64];
  U8 fake_ff[64];
  I64 j, dummy;
  for (j=0; j<64; j++) { fake_zero[j] = 0; fake_ff[j] = 0xFF; }
  Bool z_linear = IndexLookup(idx_hashes, idx_offsets, idx_count, fake_zero, &dummy);
  Bool z_table  = IndexLookupHashTable(idx_hashes, idx_offsets, table, table_size, fake_zero, &dummy);
  Bool f_linear = IndexLookup(idx_hashes, idx_offsets, idx_count, fake_ff, &dummy);
  Bool f_table  = IndexLookupHashTable(idx_hashes, idx_offsets, table, table_size, fake_ff, &dummy);
  CommPrint(1, "P104_ABSENT_ZERO_AGREE=%d\n", z_linear==FALSE && z_table==FALSE);
  CommPrint(1, "P104_ABSENT_FF_AGREE=%d\n", f_linear==FALSE && f_table==FALSE);

  if (mismatches==0 && !z_linear && !z_table && !f_linear && !f_table) {
    CommPrint(1, "PASS p104_index_hash_table_equivalence\n");
  } else {
    CommPrint(1, "FAIL p104_index_hash_table_equivalence\n");
  }
}
P104IndexHashTableTest;

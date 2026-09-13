// probe 49 — ADR 0004's stable entity ID: same file name keeps the
// same entity ID across offers (even though its content, and thus its
// blob hash, changes); a NEW name gets a fresh ID. Verified by reading
// the real tree content back via IndexLookup + manual tree-entry
// parsing (matching See.HC's own pattern), not by trusting internal
// state.

Hgit("init \"C:/Home/P49Repo.hgs\"");

U8 fa[3]; fa[0]='o';fa[1]='n';fa[2]='e';
FileWrite("C:/Home/P49FileA.txt", fa, 3);
Hgit("offer \"C:/Home/P49Repo.hgs\" \"C:/Home/P49FileA*\" first offer");

// Read commit 1's tree, extract FileA's entity_id.
I64 rsize;
U8 *rbuf = FileRead("C:/Home/P49Repo.hgs", &rsize);
U16 rver;
U64 rcount;
HgsReadHeader(rbuf, &rver, &rcount);
U8 idx_hashes[64*64];
I64 idx_offsets[64];
I64 idx_count;
IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

U8 head1[64];
MetaReadHead("C:/Home/P49Repo.hgs", "main", head1);
I64 c1_off_rel;
IndexLookup(idx_hashes, idx_offsets, idx_count, head1, &c1_off_rel);
I64 c1_off = 16 + c1_off_rel;
U8 *c1_content = rbuf + c1_off + 9;
U8 *tree1_hash = CommitTreeHash(c1_content);
I64 t1_off_rel;
IndexLookup(idx_hashes, idx_offsets, idx_count, tree1_hash, &t1_off_rel);
I64 t1_off = 16 + t1_off_rel;
U64 t1_len = GetU64LE(rbuf, t1_off);
U8 *tree1_content = rbuf + t1_off + 9;
I64 tree1_content_len = t1_len - 1;

U8 *fname = "P49FileA.txt";
I64 fname_len = StrLen(fname);

U8 t1_type;
U8 t1_hash[64];
U64 id1;
Bool found1 = TreeFindEntry(tree1_content, tree1_content_len, fname, fname_len,
                             &t1_type, t1_hash, &id1);
CommPrint(1, "found1=%d id1=%d\n", found1, id1);

// second offer, same file NAME, different content -> same entity_id
// expected, different blob hash.
U8 fa2[3]; fa2[0]='t';fa2[1]='w';fa2[2]='o';
FileWrite("C:/Home/P49FileA.txt", fa2, 3);
Hgit("offer \"C:/Home/P49Repo.hgs\" \"C:/Home/P49FileA*\" second offer");

I64 rsize2;
U8 *rbuf2 = FileRead("C:/Home/P49Repo.hgs", &rsize2);
IndexBuild(rbuf2+16, rsize2-16, idx_hashes, idx_offsets, &idx_count);
U8 head2[64];
MetaReadHead("C:/Home/P49Repo.hgs", "main", head2);
I64 c2_off_rel;
IndexLookup(idx_hashes, idx_offsets, idx_count, head2, &c2_off_rel);
I64 c2_off = 16 + c2_off_rel;
U8 *c2_content = rbuf2 + c2_off + 9;
U8 *tree2_hash = CommitTreeHash(c2_content);
I64 t2_off_rel;
IndexLookup(idx_hashes, idx_offsets, idx_count, tree2_hash, &t2_off_rel);
I64 t2_off = 16 + t2_off_rel;
U64 t2_len = GetU64LE(rbuf2, t2_off);
U8 *tree2_content = rbuf2 + t2_off + 9;
I64 tree2_content_len = t2_len - 1;

U8 t2_type;
U8 t2_hash[64];
U64 id2;
Bool found2 = TreeFindEntry(tree2_content, tree2_content_len, fname, fname_len,
                             &t2_type, t2_hash, &id2);
CommPrint(1, "found2=%d id2=%d\n", found2, id2);
Bool id_same_across_offers = (id1 == id2);
Bool blob_hash_differs = FALSE;
I64 k;
for (k=0;k<64;k++) if (t1_hash[k]!=t2_hash[k]) blob_hash_differs=TRUE;
CommPrint(1, "id_same_across_offers=%d blob_hash_differs=%d\n",
          id_same_across_offers, blob_hash_differs);

// a brand-new file name in the SAME offer must get a DIFFERENT
// (fresh) entity ID, not the same one FileA got.
FileWrite("C:/Home/P49FileB.txt", fa2, 3);
Hgit("offer \"C:/Home/P49Repo.hgs\" \"C:/Home/P49File*\" third offer, new file");

I64 rsize3;
U8 *rbuf3 = FileRead("C:/Home/P49Repo.hgs", &rsize3);
IndexBuild(rbuf3+16, rsize3-16, idx_hashes, idx_offsets, &idx_count);
U8 head3[64];
MetaReadHead("C:/Home/P49Repo.hgs", "main", head3);
I64 c3_off_rel;
IndexLookup(idx_hashes, idx_offsets, idx_count, head3, &c3_off_rel);
I64 c3_off = 16 + c3_off_rel;
U8 *c3_content = rbuf3 + c3_off + 9;
U8 *tree3_hash = CommitTreeHash(c3_content);
I64 t3_off_rel;
IndexLookup(idx_hashes, idx_offsets, idx_count, tree3_hash, &t3_off_rel);
I64 t3_off = 16 + t3_off_rel;
U64 t3_len = GetU64LE(rbuf3, t3_off);
U8 *tree3_content = rbuf3 + t3_off + 9;
I64 tree3_content_len = t3_len - 1;

U8 *fnameB = "P49FileB.txt";
U8 tB_type;
U8 tB_hash[64];
U64 idB;
Bool foundB = TreeFindEntry(tree3_content, tree3_content_len, fnameB, StrLen(fnameB),
                             &tB_type, tB_hash, &idB);
CommPrint(1, "foundB=%d idB=%d\n", foundB, idB);

U8 tA3_type;
U8 tA3_hash[64];
U64 idA3;
Bool foundA3 = TreeFindEntry(tree3_content, tree3_content_len, fname, fname_len,
                              &tA3_type, tA3_hash, &idA3);
Bool fileA_id_still_same = (idA3 == id1);
CommPrint(1, "foundA3=%d fileA_id_still_same=%d\n", foundA3, fileA_id_still_same);

Bool idB_is_different = (idB != id1) && (idB != 0);
CommPrint(1, "idB_is_different=%d\n", idB_is_different);

if (found1 && found2 && id_same_across_offers && blob_hash_differs &&
    foundB && foundA3 && fileA_id_still_same && idB_is_different)
  CommPrint(1, "PASS entity_id\n");
else
  CommPrint(1, "FAIL entity_id\n");

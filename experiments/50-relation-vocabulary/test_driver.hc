// probe 50 — ADR 0005's typed relation vocabulary: CommitEncode's new
// relation_tag/relation_target fields round-trip correctly, and a
// real `hgit offer` (REL_NONE, the common case) still has correct
// message/timestamp accessors - a regression check that the new
// trailing fields didn't disturb the existing ones.

// --- Part 1: a real offer still decodes correctly (regression) ---
Hgit("init \"C:/Home/P50Repo.hgs\"");
U8 fa[3]; fa[0]='o';fa[1]='n';fa[2]='e';
FileWrite("C:/Home/P50FileA.txt", fa, 3);
Hgit("offer \"C:/Home/P50Repo.hgs\" \"C:/Home/P50FileA*\" ordinary offer");

I64 rsize;
U8 *rbuf = FileRead("C:/Home/P50Repo.hgs", &rsize);
U16 rver;
U64 rcount;
HgsReadHeader(rbuf, &rver, &rcount);
U8 idx_hashes[64*64];
I64 idx_offsets[64];
I64 idx_count;
IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);
U8 head1[64];
MetaReadHead("C:/Home/P50Repo.hgs", "main", head1);
I64 c1_off_rel;
IndexLookup(idx_hashes, idx_offsets, idx_count, head1, &c1_off_rel);
I64 c1_off = 16 + c1_off_rel;
U8 *c1_content = rbuf + c1_off + 9;

U32 mlen1 = CommitMessageLen(c1_content);
U8 *msg1 = CommitMessage(c1_content);
CommPrint(1, "mlen1=%d msg1=", mlen1);
I64 mi;
for (mi=0; mi<mlen1; mi++) CommPrint(1, "%c", msg1[mi]);
CommPrint(1, "\n");
U8 rel_tag1 = CommitRelationTag(c1_content);
CommPrint(1, "rel_tag1=%d (expect 0, REL_NONE)\n", rel_tag1);

// --- Part 2: direct CommitEncode/decode round-trip with a real
// relation (CORRECTS), not yet wired through any CLI command per ADR
// 0005's own scope - tests the storage layer directly.
U8 tree_hash_fake[64], parent_hash_fake[64], correction_target[64];
I64 k;
for (k=0;k<64;k++) { tree_hash_fake[k]=k+1; parent_hash_fake[k]=k+50; correction_target[k]=k+100; }

U8 *msg2 = "fixes the off-by-one from three commits ago";
I64 msg2_len = StrLen(msg2);

U8 commit_buf[512];
I64 clen = 0;
CommitEncode(commit_buf, &clen, tree_hash_fake, parent_hash_fake, 1, 999888,
             msg2, msg2_len, REL_CORRECTS, correction_target);

U32 mlen2 = CommitMessageLen(commit_buf);
U8 *msg2_read = CommitMessage(commit_buf);
CommPrint(1, "mlen2=%d msg2_matches=", mlen2);
Bool msg2_matches = (mlen2 == msg2_len);
if (msg2_matches) for (k=0;k<msg2_len;k++) if (msg2_read[k]!=msg2[k]) msg2_matches=FALSE;
CommPrint(1, "%d\n", msg2_matches);

U8 rel_tag2 = CommitRelationTag(commit_buf);
U8 *rel_target2 = CommitRelationTarget(commit_buf);
Bool target_matches = TRUE;
for (k=0;k<64;k++) if (rel_target2[k]!=correction_target[k]) target_matches=FALSE;
CommPrint(1, "rel_tag2=%d (expect %d, REL_CORRECTS) target_matches=%d\n",
          rel_tag2, REL_CORRECTS, target_matches);

// timestamp/parent accessors still correct too, with a relation present.
U64 ts2 = CommitTimestamp(commit_buf);
U8 pcount2 = CommitParentCount(commit_buf);
CommPrint(1, "ts2=%d (expect 999888) pcount2=%d (expect 1)\n", ts2, pcount2);

if (rel_tag1 == REL_NONE && msg2_matches && rel_tag2 == REL_CORRECTS &&
    target_matches && ts2 == 999888 && pcount2 == 1)
  CommPrint(1, "PASS relation_vocabulary\n");
else
  CommPrint(1, "FAIL relation_vocabulary\n");

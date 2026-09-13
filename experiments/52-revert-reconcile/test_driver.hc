// probe 52 — `hgit revert`/`hgit reconcile`, independently through the
// real Hgit(cmdline) dispatcher. Probe 51 verified `correct`; revert
// and reconcile share the exact same HgitOfferRelatedCmd code path
// (only the REL_* tag differs), but per this project's own standing
// rule ("never claim a test passed without actually running it") that
// similarity is not a substitute for actually pushing and checking
// them - this probe closes that honestly-flagged gap.

Hgit("init \"C:/Home/P52Repo.hgs\"");
U8 fa[3]; fa[0]='o';fa[1]='n';fa[2]='e';
FileWrite("C:/Home/P52FileA.txt", fa, 3);
Hgit("offer \"C:/Home/P52Repo.hgs\" \"C:/Home/P52FileA*\" first offer");

U8 head1[64];
MetaReadHead("C:/Home/P52Repo.hgs", "main", head1);
U8 head1_hex[129];
HashToHex(head1, head1_hex);

// --- hgit revert ---
U8 fa2[3]; fa2[0]='t';fa2[1]='w';fa2[2]='o';
FileWrite("C:/Home/P52FileA.txt", fa2, 3);
U8 revert_cmd[300];
U8 *rprefix = "revert \"C:/Home/P52Repo.hgs\" ";
I64 p = 0;
while (rprefix[p]) { revert_cmd[p] = rprefix[p]; p++; }
I64 h = 0;
while (head1_hex[h]) { revert_cmd[p++] = head1_hex[h]; h++; }
U8 *rsuffix = " \"C:/Home/P52FileA*\" reverts the first offer";
I64 si = 0;
while (rsuffix[si]) { revert_cmd[p++] = rsuffix[si]; si++; }
revert_cmd[p] = 0;
Hgit(revert_cmd);

U8 head2[64];
MetaReadHead("C:/Home/P52Repo.hgs", "main", head2);
I64 rsize;
U8 *rbuf = FileRead("C:/Home/P52Repo.hgs", &rsize);
U16 rver;
U64 rcount;
HgsReadHeader(rbuf, &rver, &rcount);
U8 idx_hashes[64*64];
I64 idx_offsets[64];
I64 idx_count;
IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);
I64 c2_off_rel;
IndexLookup(idx_hashes, idx_offsets, idx_count, head2, &c2_off_rel);
I64 c2_off = 16 + c2_off_rel;
U8 *c2_content = rbuf + c2_off + 9;
U8 revert_tag = CommitRelationTag(c2_content);
U8 *revert_target = CommitRelationTarget(c2_content);
Bool revert_target_ok = TRUE;
I64 k;
for (k=0;k<64;k++) if (revert_target[k]!=head1[k]) revert_target_ok=FALSE;
CommPrint(1, "revert_tag=%d (expect %d, REL_REVERTS) revert_target_ok=%d\n",
          revert_tag, REL_REVERTS, revert_target_ok);

// --- hgit reconcile ---
U8 head2_hex[129];
HashToHex(head2, head2_hex);
U8 fa3[5]; fa3[0]='t';fa3[1]='h';fa3[2]='r';fa3[3]='e';fa3[4]='e';
FileWrite("C:/Home/P52FileA.txt", fa3, 5);
U8 reconcile_cmd[300];
U8 *cprefix = "reconcile \"C:/Home/P52Repo.hgs\" ";
p = 0;
while (cprefix[p]) { reconcile_cmd[p] = cprefix[p]; p++; }
h = 0;
while (head2_hex[h]) { reconcile_cmd[p++] = head2_hex[h]; h++; }
U8 *csuffix = " \"C:/Home/P52FileA*\" reconciles the two lines";
si = 0;
while (csuffix[si]) { reconcile_cmd[p++] = csuffix[si]; si++; }
reconcile_cmd[p] = 0;
Hgit(reconcile_cmd);

U8 head3[64];
MetaReadHead("C:/Home/P52Repo.hgs", "main", head3);
I64 rsize2;
U8 *rbuf2 = FileRead("C:/Home/P52Repo.hgs", &rsize2);
IndexBuild(rbuf2+16, rsize2-16, idx_hashes, idx_offsets, &idx_count);
I64 c3_off_rel;
IndexLookup(idx_hashes, idx_offsets, idx_count, head3, &c3_off_rel);
I64 c3_off = 16 + c3_off_rel;
U8 *c3_content = rbuf2 + c3_off + 9;
U8 reconcile_tag = CommitRelationTag(c3_content);
U8 *reconcile_target = CommitRelationTarget(c3_content);
Bool reconcile_target_ok = TRUE;
for (k=0;k<64;k++) if (reconcile_target[k]!=head2[k]) reconcile_target_ok=FALSE;
CommPrint(1, "reconcile_tag=%d (expect %d, REL_RECONCILES) reconcile_target_ok=%d\n",
          reconcile_tag, REL_RECONCILES, reconcile_target_ok);

if (revert_tag == REL_REVERTS && revert_target_ok &&
    reconcile_tag == REL_RECONCILES && reconcile_target_ok)
  CommPrint(1, "PASS revert_reconcile\n");
else
  CommPrint(1, "FAIL revert_reconcile\n");

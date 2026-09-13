// probe 51 — hgit correct/revert/reconcile: a real CLI command surface
// for ADR 0005's relation vocabulary, through the actual Hgit(cmdline)
// dispatcher (not direct CommitEncode calls, as probe 50 tested).

Hgit("init \"C:/Home/P51Repo.hgs\"");
U8 fa[3]; fa[0]='o';fa[1]='n';fa[2]='e';
FileWrite("C:/Home/P51FileA.txt", fa, 3);
Hgit("offer \"C:/Home/P51Repo.hgs\" \"C:/Home/P51FileA*\" first offer, has a bug");

U8 head1[64];
MetaReadHead("C:/Home/P51Repo.hgs", "main", head1);
U8 head1_hex[129];
HashToHex(head1, head1_hex);
CommPrint(1, "head1_hex=%s\n", head1_hex);

// a real `hgit correct`, naming head1 as the commit being fixed.
U8 fa2[3]; fa2[0]='t';fa2[1]='w';fa2[2]='o';
FileWrite("C:/Home/P51FileA.txt", fa2, 3);
U8 cmd_buf[300];
U8 *prefix = "correct \"C:/Home/P51Repo.hgs\" ";
I64 p = 0;
while (prefix[p]) { cmd_buf[p] = prefix[p]; p++; }
I64 h = 0;
while (head1_hex[h]) { cmd_buf[p++] = head1_hex[h]; h++; }
U8 *suffix = " \"C:/Home/P51FileA*\" fixes the bug from the previous commit";
I64 si = 0;
while (suffix[si]) { cmd_buf[p++] = suffix[si]; si++; }
cmd_buf[p] = 0;
Hgit(cmd_buf);

U8 head2[64];
MetaReadHead("C:/Home/P51Repo.hgs", "main", head2);

// verify the new commit really does carry REL_CORRECTS naming head1,
// by reading it back directly (not trusting internal state).
I64 rsize;
U8 *rbuf = FileRead("C:/Home/P51Repo.hgs", &rsize);
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

U8 rel_tag = CommitRelationTag(c2_content);
U8 *rel_target = CommitRelationTarget(c2_content);
Bool target_matches_head1 = TRUE;
I64 k;
for (k=0;k<64;k++) if (rel_target[k]!=head1[k]) target_matches_head1=FALSE;
CommPrint(1, "rel_tag=%d (expect %d, REL_CORRECTS) target_matches_head1=%d\n",
          rel_tag, REL_CORRECTS, target_matches_head1);

U32 mlen = CommitMessageLen(c2_content);
U8 *msg = CommitMessage(c2_content);
CommPrint(1, "msg=");
I64 mi;
for (mi=0; mi<mlen; mi++) CommPrint(1, "%c", msg[mi]);
CommPrint(1, "\n");

// `hgit see` on the new commit should show the relation too.
U8 see_cmd[200];
U8 *see_prefix = "see \"C:/Home/P51Repo.hgs\" ";
I64 sp = 0;
while (see_prefix[sp]) { see_cmd[sp] = see_prefix[sp]; sp++; }
U8 head2_hex[129];
HashToHex(head2, head2_hex);
I64 h2 = 0;
while (head2_hex[h2]) { see_cmd[sp++] = head2_hex[h2]; h2++; }
see_cmd[sp] = 0;
Hgit(see_cmd);

if (rel_tag == REL_CORRECTS && target_matches_head1)
  CommPrint(1, "PASS relation_commands\n");
else
  CommPrint(1, "FAIL relation_commands\n");

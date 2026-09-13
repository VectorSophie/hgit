// probe 53 — ADR 0006: entity-scoped relations. A real `hgit correct`
// naming a real entity ID (read from the actual tree, not invented)
// carries that ID through correctly; the "unscoped" (all-zero) case
// still works too, matching ADR 0005's original whole-commit behavior.

Hgit("init \"C:/Home/P53Repo.hgs\"");
U8 fa[3]; fa[0]='o';fa[1]='n';fa[2]='e';
FileWrite("C:/Home/P53FileA.txt", fa, 3);
Hgit("offer \"C:/Home/P53Repo.hgs\" \"C:/Home/P53FileA*\" first offer");

// read the real entity ID for FileA straight from the tree, the same
// way a user would via `hgit see`'s own output.
I64 rsize;
U8 *rbuf = FileRead("C:/Home/P53Repo.hgs", &rsize);
U16 rver;
U64 rcount;
HgsReadHeader(rbuf, &rver, &rcount);
U8 idx_hashes[64*64];
I64 idx_offsets[64];
I64 idx_count;
IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);
U8 head1[64];
MetaReadHead("C:/Home/P53Repo.hgs", "main", head1);
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

U8 *fname = "P53FileA.txt";
U8 t1_type;
U8 t1_hash[64];
U64 real_entity_id;
Bool found1 = TreeFindEntry(tree1_content, tree1_content_len, fname, StrLen(fname),
                             &t1_type, t1_hash, &real_entity_id);
CommPrint(1, "found1=%d\n", found1);
U8 real_entity_hex[17];
U64ToHex(real_entity_id, real_entity_hex);
CommPrint(1, "real_entity_hex=%s\n", real_entity_hex);

U8 head1_hex[129];
HashToHex(head1, head1_hex);

// --- a real `hgit correct`, entity-scoped to FileA's real ID ---
U8 fa2[3]; fa2[0]='t';fa2[1]='w';fa2[2]='o';
FileWrite("C:/Home/P53FileA.txt", fa2, 3);
U8 cmd_buf[350];
I64 p = 0;
U8 *prefix = "correct \"C:/Home/P53Repo.hgs\" ";
while (prefix[p]) { cmd_buf[p] = prefix[p]; p++; }
I64 h = 0;
while (head1_hex[h]) { cmd_buf[p++] = head1_hex[h]; h++; }
cmd_buf[p++] = ' ';
I64 e = 0;
while (real_entity_hex[e]) { cmd_buf[p++] = real_entity_hex[e]; e++; }
U8 *suffix = " \"C:/Home/P53FileA*\" fixes just this one file";
I64 si = 0;
while (suffix[si]) { cmd_buf[p++] = suffix[si]; si++; }
cmd_buf[p] = 0;
Hgit(cmd_buf);

U8 head2[64];
MetaReadHead("C:/Home/P53Repo.hgs", "main", head2);
I64 rsize2;
U8 *rbuf2 = FileRead("C:/Home/P53Repo.hgs", &rsize2);
IndexBuild(rbuf2+16, rsize2-16, idx_hashes, idx_offsets, &idx_count);
I64 c2_off_rel;
IndexLookup(idx_hashes, idx_offsets, idx_count, head2, &c2_off_rel);
I64 c2_off = 16 + c2_off_rel;
U8 *c2_content = rbuf2 + c2_off + 9;

U8 rel_tag2 = CommitRelationTag(c2_content);
U64 rel_entity2 = CommitRelationEntityId(c2_content);
Bool entity_matches = (rel_entity2 == real_entity_id);
CommPrint(1, "rel_tag2=%d (expect %d) entity_matches=%d\n",
          rel_tag2, REL_CORRECTS, entity_matches);

// --- a real `hgit correct`, NOT entity-scoped (all-zero sentinel) ---
U8 fa3[5]; fa3[0]='t';fa3[1]='h';fa3[2]='r';fa3[3]='e';fa3[4]='e';
FileWrite("C:/Home/P53FileA.txt", fa3, 5);
U8 head2_hex[129];
HashToHex(head2, head2_hex);
U8 cmd_buf2[350];
p = 0;
while (prefix[p]) { cmd_buf2[p] = prefix[p]; p++; }
h = 0;
while (head2_hex[h]) { cmd_buf2[p++] = head2_hex[h]; h++; }
cmd_buf2[p++] = ' ';
U8 *zero_entity = "0000000000000000";
I64 z = 0;
while (zero_entity[z]) { cmd_buf2[p++] = zero_entity[z]; z++; }
U8 *suffix2 = " \"C:/Home/P53FileA*\" corrects the whole commit, unscoped";
si = 0;
while (suffix2[si]) { cmd_buf2[p++] = suffix2[si]; si++; }
cmd_buf2[p] = 0;
Hgit(cmd_buf2);

U8 head3[64];
MetaReadHead("C:/Home/P53Repo.hgs", "main", head3);
I64 rsize3;
U8 *rbuf3 = FileRead("C:/Home/P53Repo.hgs", &rsize3);
IndexBuild(rbuf3+16, rsize3-16, idx_hashes, idx_offsets, &idx_count);
I64 c3_off_rel;
IndexLookup(idx_hashes, idx_offsets, idx_count, head3, &c3_off_rel);
I64 c3_off = 16 + c3_off_rel;
U8 *c3_content = rbuf3 + c3_off + 9;
U8 rel_tag3 = CommitRelationTag(c3_content);
U64 rel_entity3 = CommitRelationEntityId(c3_content);
CommPrint(1, "rel_tag3=%d (expect %d) rel_entity3=%d (expect 0, unscoped)\n",
          rel_tag3, REL_CORRECTS, rel_entity3);

if (found1 && rel_tag2 == REL_CORRECTS && entity_matches &&
    rel_tag3 == REL_CORRECTS && rel_entity3 == 0)
  CommPrint(1, "PASS entity_scoped_relations\n");
else
  CommPrint(1, "FAIL entity_scoped_relations\n");

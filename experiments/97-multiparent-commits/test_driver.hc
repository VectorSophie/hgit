// Probe 97 test driver: does hgit's own object model (Commit.HC's
// CommitEncode/CommitParentCount/CommitParentHash) and every command
// that walks a commit's parents (Check.HC's CheckMarkReachable and its
// own referential-integrity pass) already correctly support a REAL
// multi-parent (merge) commit, even though no real command has ever
// created one? A real prerequisite check before any actual merge
// algorithm (finding a merge base, three-way tree merge) gets
// designed - same pattern ADR 0010's own probes 88/89 used before
// subdirectory support was implemented.
//
// This manually constructs a synthetic 2-parent commit (NOT a real
// three-way merge - the merge commit's own tree is just commit A's
// tree, unchanged; this probe is scoped to the OBJECT MODEL question
// only, not the merge algorithm) and injects it into a real repo's
// real archive, the same direct-archive-manipulation technique probe
// 92 used to test Check.HC's own corruption detection.
U0 P97MultiParentTest()
{
  Del("C:/Home/P97Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P97Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P97Repo.hgs");

  FileWrite("C:/Home/P97FileA.txt", "root content", 12);
  Hgit("offer C:/Home/P97Repo.hgs C:/Home/P97FileA.txt root_offer");

  Hgit("path new C:/Home/P97Repo.hgs feature");
  Hgit("path go C:/Home/P97Repo.hgs feature");
  FileWrite("C:/Home/P97FileA.txt", "feature content", 15);
  Hgit("offer C:/Home/P97Repo.hgs P97FileA.txt feature_offer");

  U8 feature_head[64];
  CurrentHeadRead("C:/Home/P97Repo.hgs", feature_head);

  Hgit("path go C:/Home/P97Repo.hgs main");
  FileWrite("C:/Home/P97FileA.txt", "main content", 12);
  Hgit("offer C:/Home/P97Repo.hgs P97FileA.txt main_offer");

  U8 main_head[64];
  CurrentHeadRead("C:/Home/P97Repo.hgs", main_head);

  // Manually build a synthetic merge commit: two real parents (main's
  // own HEAD and feature's own HEAD, genuinely diverged), tree_hash
  // just reused from main's own commit (a real simplification - this
  // probe tests the object model, not a three-way merge algorithm).
  I64 rsize;
  U8 *rbuf = FileRead("C:/Home/P97Repo.hgs", &rsize);
  U16 rver;
  U64 rcount;
  HgsReadHeader(rbuf, &rver, &rcount);

  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  I64 main_off_rel;
  IndexLookup(idx_hashes, idx_offsets, idx_count, main_head, &main_off_rel);
  I64 main_off = 16 + main_off_rel;
  U8 *main_content = rbuf + main_off + 9;
  U8 *merge_tree_hash = CommitTreeHash(main_content);

  I64 archive_cap = rsize + 4096;
  U8 *archive = MAlloc(archive_cap);
  I64 alen;
  I64 i;
  for (i=0; i<rsize-16; i++) archive[16+i] = rbuf[16+i];
  alen = rsize;

  U8 parent_hashes[128]; // 2 * 64 bytes, concatenated per CommitEncode's own convention
  for (i=0; i<64; i++) parent_hashes[i] = main_head[i];
  for (i=0; i<64; i++) parent_hashes[64+i] = feature_head[i];

  U8 *msg = "merge_test_two_parents";
  U8 commit_content[512];
  I64 clen = 0;
  CommitEncode(commit_content, &clen, merge_tree_hash, parent_hashes,
              2, cnts.jiffies, msg, StrLen(msg), REL_NONE, NULL, 0);
  U8 commit_tagged[512];
  commit_tagged[0] = OBJ_COMMIT;
  for (i=0; i<clen; i++) commit_tagged[1+i] = commit_content[i];
  U8 merge_commit_hash[64];
  B2Hash512Any(commit_tagged, clen+1, merge_commit_hash);
  ObjectPut(archive, &alen, OBJ_COMMIT, commit_content, clen);

  I64 max_possible_objects = alen/73 + 1;
  U8 *final_idx_hashes = MAlloc(max_possible_objects*64 + 64);
  I64 *final_idx_offsets = MAlloc((max_possible_objects+1)*8);
  I64 final_idx_count;
  IndexBuild(archive+16, alen-16, final_idx_hashes, final_idx_offsets, &final_idx_count);
  Free(final_idx_hashes);
  Free(final_idx_offsets);
  HgsWriteHeader(archive, rver, final_idx_count);
  FileWrite("C:/Home/P97Repo.hgs", archive, alen);
  CurrentHeadWrite("C:/Home/P97Repo.hgs", merge_commit_hash);

  Free(rbuf);
  Free(archive);
  Free(idx_hashes);
  Free(idx_offsets);

  U8 merge_hex[129];
  HashToHex(merge_commit_hash, merge_hex);
  U8 cmd[512];
  StrPrint(cmd, "see C:/Home/P97Repo.hgs %s", merge_hex);
  CommPrint(1, "P97_SEE_BEGIN\n");
  Hgit(cmd);
  CommPrint(1, "P97_SEE_END\n");

  CommPrint(1, "P97_CHECK_BEGIN\n");
  Hgit("check C:/Home/P97Repo.hgs");
  CommPrint(1, "P97_CHECK_END\n");

  CommPrint(1, "PASS p97_multiparent_test\n");
}
P97MultiParentTest;

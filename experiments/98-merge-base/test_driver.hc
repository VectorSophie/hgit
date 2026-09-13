// Probe 98 test driver: FindMergeBase - the next real, standalone
// primitive a real `hgit merge` command needs, verified before any
// real command wires it in (same pattern ADR 0010's own probes 90/91
// established).
U0 P98MergeBaseTest()
{
  Del("C:/Home/P98Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P98Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P98Repo.hgs");

  FileWrite("C:/Home/P98FileA.txt", "root content", 12);
  Hgit("offer C:/Home/P98Repo.hgs P98FileA.txt root_offer");

  U8 root_head[64];
  CurrentHeadRead("C:/Home/P98Repo.hgs", root_head);

  Hgit("path new C:/Home/P98Repo.hgs feature");
  Hgit("path go C:/Home/P98Repo.hgs feature");
  FileWrite("C:/Home/P98FileA.txt", "feature content", 15);
  Hgit("offer C:/Home/P98Repo.hgs P98FileA.txt feature_offer");

  U8 feature_head[64];
  CurrentHeadRead("C:/Home/P98Repo.hgs", feature_head);

  Hgit("path go C:/Home/P98Repo.hgs main");
  FileWrite("C:/Home/P98FileA.txt", "main content one", 17);
  Hgit("offer C:/Home/P98Repo.hgs P98FileA.txt main_offer_one");
  FileWrite("C:/Home/P98FileA.txt", "main content two", 17);
  Hgit("offer C:/Home/P98Repo.hgs P98FileA.txt main_offer_two");

  U8 main_head[64];
  CurrentHeadRead("C:/Home/P98Repo.hgs", main_head);

  // Real check: main has advanced two commits past the fork, feature
  // has advanced one - the real merge base should be root_head
  // regardless of that asymmetry.
  I64 rsize;
  U8 *rbuf = FileRead("C:/Home/P98Repo.hgs", &rsize);
  U16 rver;
  U64 rcount;
  HgsReadHeader(rbuf, &rver, &rcount);
  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  U8 found_base[64];
  Bool found = FindMergeBase(rbuf, idx_hashes, idx_offsets, idx_count,
                             main_head, feature_head, found_base);

  U8 root_hex[129], found_hex[129];
  HashToHex(root_head, root_hex);
  HashToHex(found_base, found_hex);
  CommPrint(1, "P98_MERGEBASE_FOUND=%d\n", found);
  CommPrint(1, "P98_ROOT_HEX=%s\n", root_hex);
  CommPrint(1, "P98_FOUND_HEX=%s\n", found_hex);

  Bool matches = TRUE;
  I64 i;
  for (i=0; i<64; i++) if (root_head[i] != found_base[i]) matches = FALSE;
  CommPrint(1, "P98_MATCHES_ROOT=%d\n", matches);

  // Also check the trivial case: a commit's own merge-base with
  // itself is itself.
  U8 self_base[64];
  Bool self_found = FindMergeBase(rbuf, idx_hashes, idx_offsets, idx_count,
                                  main_head, main_head, self_base);
  Bool self_matches = TRUE;
  for (i=0; i<64; i++) if (main_head[i] != self_base[i]) self_matches = FALSE;
  CommPrint(1, "P98_SELF_FOUND=%d\n", self_found);
  CommPrint(1, "P98_SELF_MATCHES=%d\n", self_matches);

  Free(rbuf);
  Free(idx_hashes);
  Free(idx_offsets);

  CommPrint(1, "PASS p98_merge_base_test\n");
}
P98MergeBaseTest;

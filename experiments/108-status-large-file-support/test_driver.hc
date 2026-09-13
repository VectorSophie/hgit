// Probe 108 test driver: `hgit status` (flat) and `hgit statustree`
// (recursive) can now classify a file well over the old 511-byte cap
// as NEW/MODIFIED/UNCHANGED instead of reporting
// STATUS_TOO_LARGE_TO_CHECK and nothing else.
U0 P108StatusLargeFileTest()
{
  Del("C:/Home/P108Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P108Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P108Repo.hgs");

  I64 big_len = 5000;
  U8 *big = MAlloc(big_len);
  I64 i;
  for (i=0; i<big_len; i++) big[i] = (i*17 + 1) & 0xFF;
  FileWrite("C:/Home/P108Big.txt", big, big_len);
  Hgit("offer C:/Home/P108Repo.hgs P108Big.txt first_offer");

  // Unchanged: same content, same repo.
  CommPrint(1, "P108_STATUS_UNCHANGED_BEGIN\n");
  Hgit("status C:/Home/P108Repo.hgs P108*.txt C:/Home/");
  CommPrint(1, "P108_STATUS_UNCHANGED_END\n");

  // Modified: real edit to the same large file.
  for (i=0; i<big_len; i++) big[i] = (i*17 + 9) & 0xFF;
  FileWrite("C:/Home/P108Big.txt", big, big_len);
  CommPrint(1, "P108_STATUS_MODIFIED_BEGIN\n");
  Hgit("status C:/Home/P108Repo.hgs P108*.txt C:/Home/");
  CommPrint(1, "P108_STATUS_MODIFIED_END\n");

  // Commit the edit, then add a genuinely new large file - exercises
  // the new_contents-too-large-to-buffer path (fuzzy skipped, still
  // reported as real NEW).
  Hgit("offer C:/Home/P108Repo.hgs P108Big.txt second_offer");
  U8 *big2 = MAlloc(big_len);
  for (i=0; i<big_len; i++) big2[i] = (i*23 + 4) & 0xFF; // unrelated content
  FileWrite("C:/Home/P108Big2.txt", big2, big_len);
  CommPrint(1, "P108_STATUS_NEW_BEGIN\n");
  Hgit("status C:/Home/P108Repo.hgs P108*.txt C:/Home/");
  CommPrint(1, "P108_STATUS_NEW_END\n");

  // Same scenario, nested inside a subdirectory, via offertree/statustree.
  Del("C:/Home/P108TreeRepo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P108TreeRepo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P108TreeRepo.hgs");
  DirMk("C:/Home/P108TreeRoot");
  DirMk("C:/Home/P108TreeRoot/SubA");
  FileWrite("C:/Home/P108TreeRoot/SubA/big.txt", big, big_len);
  Hgit("offertree C:/Home/P108TreeRepo.hgs C:/Home/P108TreeRoot/ first_offer");

  for (i=0; i<big_len; i++) big[i] = (i*17 + 20) & 0xFF; // real edit
  FileWrite("C:/Home/P108TreeRoot/SubA/big.txt", big, big_len);
  CommPrint(1, "P108_STATUSTREE_MODIFIED_BEGIN\n");
  Hgit("statustree C:/Home/P108TreeRepo.hgs C:/Home/P108TreeRoot/");
  CommPrint(1, "P108_STATUSTREE_MODIFIED_END\n");

  CommPrint(1, "PASS p108_status_large_file_support\n");
}
P108StatusLargeFileTest;

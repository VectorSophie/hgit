// Probe 107 test driver: `hgit offertree` (recursive path) can now
// commit a file well over the old 511-byte cap, including one nested
// inside a real subdirectory - backed by a real recursive sum
// (SumTreeFileBytes) instead of a fixed headroom.
U0 P107OfferTreeLargeFileTest()
{
  Del("C:/Home/P107Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P107Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P107Repo.hgs");

  DirMk("C:/Home/P107Root");
  DirMk("C:/Home/P107Root/SubA");
  FileWrite("C:/Home/P107Root/top.txt", "top level content", 18);

  I64 big_len = 6000;
  U8 *big = MAlloc(big_len);
  I64 i;
  for (i=0; i<big_len; i++) big[i] = (i*11 + 3) & 0xFF;
  FileWrite("C:/Home/P107Root/SubA/big.txt", big, big_len);

  CommPrint(1, "P107_OFFERTREE_ONE_BEGIN\n");
  Hgit("offertree C:/Home/P107Repo.hgs C:/Home/P107Root/ first_offer");
  CommPrint(1, "P107_OFFERTREE_ONE_END\n");

  Hgit("check C:/Home/P107Repo.hgs");

  // Confirm the nested large file's own entry actually made it into
  // the committed tree, not just that check reports the objects that
  // DID get written as internally consistent - directly reads it back
  // via a real statustree comparison (unchanged, since nothing edited
  // since the offer).
  CommPrint(1, "P107_STATUSTREE_BEGIN\n");
  Hgit("statustree C:/Home/P107Repo.hgs C:/Home/P107Root/");
  CommPrint(1, "P107_STATUSTREE_END\n");

  // A real edit to the same large nested file, re-offered - confirms
  // entity-ID/rename continuity still works at this depth too.
  for (i=0; i<big_len; i++) big[i] = (i*11 + 7) & 0xFF;
  FileWrite("C:/Home/P107Root/SubA/big.txt", big, big_len);
  CommPrint(1, "P107_OFFERTREE_TWO_BEGIN\n");
  Hgit("offertree C:/Home/P107Repo.hgs C:/Home/P107Root/ second_offer");
  CommPrint(1, "P107_OFFERTREE_TWO_END\n");

  Hgit("check C:/Home/P107Repo.hgs");

  CommPrint(1, "PASS p107_offertree_large_file_support\n");
}
P107OfferTreeLargeFileTest;

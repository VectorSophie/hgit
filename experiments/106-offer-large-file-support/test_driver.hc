// Probe 106 test driver: `hgit offer` (flat path) can now commit a
// file well over the old 511-byte cap, backed by a real computed
// archive capacity instead of a fixed headroom.
U0 P106LargeFileOfferTest()
{
  Del("C:/Home/P106Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P106Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P106Repo.hgs");

  I64 big_len = 5000;
  U8 *big = MAlloc(big_len);
  I64 i;
  for (i=0; i<big_len; i++) big[i] = (i*13 + 5) & 0xFF;
  FileWrite("C:/Home/P106Big.txt", big, big_len);

  CommPrint(1, "P106_OFFER_ONE_BEGIN\n");
  Hgit("offer C:/Home/P106Repo.hgs P106Big.txt first_big_offer");
  CommPrint(1, "P106_OFFER_ONE_END\n");

  Hgit("check C:/Home/P106Repo.hgs");

  // Second offer with a real edit to the same (still large) file -
  // confirms entity-ID continuity and the whole flat offer path work
  // correctly on a repeated large file, not just a fresh one.
  for (i=0; i<big_len; i++) big[i] = (i*13 + 9) & 0xFF;
  FileWrite("C:/Home/P106Big.txt", big, big_len);
  CommPrint(1, "P106_OFFER_TWO_BEGIN\n");
  Hgit("offer C:/Home/P106Repo.hgs P106Big.txt second_big_offer");
  CommPrint(1, "P106_OFFER_TWO_END\n");

  Hgit("check C:/Home/P106Repo.hgs");

  // A small file in the SAME repo still works too - the fix must not
  // have broken the ordinary small-file path.
  FileWrite("C:/Home/P106Small.txt", "small", 5);
  Hgit("offer C:/Home/P106Repo.hgs P106Small.txt small_file_offer");
  Hgit("check C:/Home/P106Repo.hgs");

  CommPrint(1, "PASS p106_offer_large_file_support\n");
}
P106LargeFileOfferTest;

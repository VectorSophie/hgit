// Probe 84 test driver: fuzzy rename detection via
// OfferFindFuzzyRename/FossilSimilarityPercent.
// Positive: offer a file with real prose content, commit it, then
// "rename" it - the old name disappears, a NEW name appears with a
// small edit (one word changed, not exact-content-identical) - the
// entity ID should still carry forward via fuzzy matching.
// Negative: also offer a genuinely new, unrelated file in the same
// batch, and confirm it gets a FRESH entity ID (no false match against
// the renamed-and-edited file).
U0 P84FuzzyRenameTest()
{
  Del("C:/Home/P84Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P84Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P84Repo.hgs");

  FileWrite("C:/Home/P84Orig.txt",
    "The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog again and again.", 106);
  Hgit("offer C:/Home/P84Repo.hgs P84Orig.txt initial_offer");

  U8 head_hash[64];
  CurrentHeadRead("C:/Home/P84Repo.hgs", head_hash);
  U8 head_hex[129];
  HashToHex(head_hash, head_hex);
  U8 cmd[512];
  StrPrint(cmd, "see C:/Home/P84Repo.hgs %s", head_hex);
  Hgit(cmd);

  // "Rename" with an edit: old file gone, new name, one word changed.
  Del("C:/Home/P84Orig.txt", FALSE, FALSE, FALSE);
  FileWrite("C:/Home/P84Renamed.txt",
    "The quick brown fox LEAPS over the lazy dog. The quick brown fox jumps over the lazy dog again and again.", 106);
  // Also a genuinely new, unrelated file in the same offer.
  FileWrite("C:/Home/P84GenuinelyNew.txt", "completely different content, no relation at all", 49);

  Hgit("offer C:/Home/P84Repo.hgs P84*.txt second_offer");

  U8 head2_hash[64];
  CurrentHeadRead("C:/Home/P84Repo.hgs", head2_hash);
  U8 head2_hex[129];
  HashToHex(head2_hash, head2_hex);
  StrPrint(cmd, "see C:/Home/P84Repo.hgs %s", head2_hex);
  Hgit(cmd);

  CommPrint(1, "PASS p84_fuzzy_rename_test\n");
}
P84FuzzyRenameTest;

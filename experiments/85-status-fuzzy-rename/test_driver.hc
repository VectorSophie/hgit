// Probe 85 test driver: hgit status's own fuzzy rename surfacing.
// Offer three files, then out-of-band: rename one WITH an edit (not
// byte-identical), delete a second for real, create a third
// genuinely-new file - all in the SAME status check, so a false
// positive against the unrelated NEW/DELETED files would be a real,
// meaningful failure, not just an easy pass.
U0 P85StatusFuzzyTest()
{
  Del("C:/Home/P85Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P85Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P85Repo.hgs");

  FileWrite("C:/Home/P85Orig.txt",
    "The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog again and again.", 106);
  FileWrite("C:/Home/P85Stays.txt", "never touched", 13);
  FileWrite("C:/Home/P85WillDelete.txt", "going away for real, for real", 30);

  Hgit("offer C:/Home/P85Repo.hgs P85*.txt initial_three");

  // Out-of-band rename WITH an edit (one word changed - not exact
  // content), a real delete, and a genuinely new unrelated file.
  Del("C:/Home/P85Orig.txt", FALSE, FALSE, FALSE);
  FileWrite("C:/Home/P85Renamed.txt",
    "The quick brown fox LEAPS over the lazy dog. The quick brown fox jumps over the lazy dog again and again.", 106);
  Del("C:/Home/P85WillDelete.txt", FALSE, FALSE, FALSE);
  FileWrite("C:/Home/P85GenuinelyNew.txt", "brand new content, no relation to anything else here", 53);

  CommPrint(1, "P85_STATUS_BEGIN\n");
  Hgit("status C:/Home/P85Repo.hgs C:/Home/P85*.txt C:/Home/");
  CommPrint(1, "P85_STATUS_END_MARKER\n");

  CommPrint(1, "PASS p85_status_fuzzy_test\n");
}
P85StatusFuzzyTest;

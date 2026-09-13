// tests/full-regression.hc — one canonical, comprehensive pass over
// hgit's entire command surface, on a single fresh repo. Consolidates
// what's otherwise scattered across ~86 probe-specific experiments/
// directories into one real, re-runnable suite. See tests/README.md.
U0 HgitFullRegressionTest()
{
  // Full cleanup, not just the repo itself - every working-directory
  // file this test creates, so re-running it in the same session
  // (this project's own persistent QEMU disk) starts genuinely fresh
  // rather than matching leftover files from a previous run via the
  // same TF*.txt find_mask (a real mistake made once while writing
  // this very test - see tests/README.md).
  Del("C:/Home/TFullRepo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/TFullRepo.hgs.m", FALSE, FALSE, FALSE);
  Del("C:/Home/TFullExported.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/TFullExported.hgs.m", FALSE, FALSE, FALSE);
  Del("C:/Home/TFStays.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/TFToModify.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/TFToDelete.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/TFOrig.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/TFRenamed.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/TFGenuinelyNew.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/TFFeatureFile.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/TFullHistory.DD", FALSE, FALSE, FALSE);
  Del("C:/Home/TFullReconcile.DD", FALSE, FALSE, FALSE);
  Del("C:/Home/TFullOverview.DD", FALSE, FALSE, FALSE);
  Del("C:/Home/TFullGraph.DD", FALSE, FALSE, FALSE);
  CommPrint(1, "TFULL_BEGIN\n");

  // --- init ---
  Hgit("init C:/Home/TFullRepo.hgs");

  // --- offer (root commit) ---
  FileWrite("C:/Home/TFStays.txt", "never touched", 13);
  FileWrite("C:/Home/TFToModify.txt", "version one", 11);
  FileWrite("C:/Home/TFToDelete.txt", "going away", 10);
  FileWrite("C:/Home/TFOrig.txt",
    "The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog again.", 97);
  Hgit("offer C:/Home/TFullRepo.hgs TF*.txt first_offer");

  U8 root_hash[64];
  CurrentHeadRead("C:/Home/TFullRepo.hgs", root_hash);
  U8 root_hex[129];
  HashToHex(root_hash, root_hex);

  // --- offer (second commit: modify, delete, exact rename, fuzzy
  // rename via a second file, new file) ---
  FileWrite("C:/Home/TFToModify.txt", "version two", 11);
  Del("C:/Home/TFToDelete.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/TFOrig.txt", FALSE, FALSE, FALSE);
  FileWrite("C:/Home/TFRenamed.txt",
    "The quick brown fox LEAPS over the lazy dog. The quick brown fox jumps over the lazy dog again.", 97);
  FileWrite("C:/Home/TFGenuinelyNew.txt", "brand new content, unrelated", 28);

  // --- status: exact/fuzzy rename, new, modified, deleted, unchanged -
  // BEFORE committing these changes, comparing the live directory
  // against the FIRST commit's own tree.
  CommPrint(1, "TFULL_STATUS_BEGIN\n");
  Hgit("status C:/Home/TFullRepo.hgs C:/Home/TF*.txt C:/Home/");
  CommPrint(1, "TFULL_STATUS_END_MARKER\n");

  Hgit("offer C:/Home/TFullRepo.hgs TF*.txt second_offer");

  U8 head2_hash[64];
  CurrentHeadRead("C:/Home/TFullRepo.hgs", head2_hash);
  U8 head2_hex[129];
  HashToHex(head2_hash, head2_hex);

  // --- history ---
  CommPrint(1, "TFULL_HISTORY_BEGIN\n");
  Hgit("history C:/Home/TFullRepo.hgs");
  CommPrint(1, "TFULL_HISTORY_END_MARKER\n");

  // --- see ---
  U8 see_cmd[512];
  StrPrint(see_cmd, "see C:/Home/TFullRepo.hgs %s", head2_hex);
  CommPrint(1, "TFULL_SEE_BEGIN\n");
  Hgit(see_cmd);
  CommPrint(1, "TFULL_SEE_END_MARKER\n");

  // --- diff (second commit vs first, and root commit vs nothing) ---
  U8 diff_cmd[512];
  StrPrint(diff_cmd, "diff C:/Home/TFullRepo.hgs %s", head2_hex);
  CommPrint(1, "TFULL_DIFF_BEGIN\n");
  Hgit(diff_cmd);
  CommPrint(1, "TFULL_DIFF_END_MARKER\n");

  // --- check: hash integrity, referential integrity, dangling ---
  CommPrint(1, "TFULL_CHECK_BEGIN\n");
  Hgit("check C:/Home/TFullRepo.hgs");
  CommPrint(1, "TFULL_CHECK_END_MARKER\n");

  // --- undo / redo ---
  Hgit("undo C:/Home/TFullRepo.hgs");
  CommPrint(1, "TFULL_CHECK_AFTER_UNDO_BEGIN\n");
  Hgit("check C:/Home/TFullRepo.hgs"); // second commit's objects now dangling
  CommPrint(1, "TFULL_CHECK_AFTER_UNDO_END_MARKER\n");
  Hgit("redo C:/Home/TFullRepo.hgs");

  // --- operation history / restore ---
  CommPrint(1, "TFULL_OPHISTORY_BEGIN\n");
  Hgit("operation history C:/Home/TFullRepo.hgs");
  CommPrint(1, "TFULL_OPHISTORY_END_MARKER\n");

  // --- named paths ---
  Hgit("path new C:/Home/TFullRepo.hgs feature");
  Hgit("path go C:/Home/TFullRepo.hgs feature");
  FileWrite("C:/Home/TFFeatureFile.txt", "feature branch content", 23);
  Hgit("offer C:/Home/TFullRepo.hgs TF*.txt feature_offer");
  CommPrint(1, "TFULL_PATHLIST_BEGIN\n");
  Hgit("path list C:/Home/TFullRepo.hgs");
  CommPrint(1, "TFULL_PATHLIST_END_MARKER\n");
  Hgit("path go C:/Home/TFullRepo.hgs main");

  // --- correct / revert / reconcile (typed relations) ---
  U8 rel_cmd[512];
  StrPrint(rel_cmd, "correct C:/Home/TFullRepo.hgs %s 0000000000000000 TFToModify.txt correcting_offer", head2_hex);
  Hgit(rel_cmd);
  U8 correct_hash[64];
  CurrentHeadRead("C:/Home/TFullRepo.hgs", correct_hash);
  U8 correct_hex[129];
  HashToHex(correct_hash, correct_hex);
  CommPrint(1, "TFULL_SEE_CORRECT_BEGIN\n");
  StrPrint(see_cmd, "see C:/Home/TFullRepo.hgs %s", correct_hex);
  Hgit(see_cmd);
  CommPrint(1, "TFULL_SEE_CORRECT_END_MARKER\n");

  // --- DolDoc views: historydoc, reconciledoc, reconcileoverview, graph ---
  Hgit("historydoc C:/Home/TFullRepo.hgs C:/Home/TFullHistory.DD");
  StrPrint(rel_cmd, "reconciledoc C:/Home/TFullRepo.hgs %s C:/Home/TFullReconcile.DD", correct_hex);
  Hgit(rel_cmd);
  Hgit("reconcileoverview C:/Home/TFullRepo.hgs C:/Home/TFullOverview.DD");
  Hgit("graph C:/Home/TFullRepo.hgs C:/Home/TFullGraph.DD");

  // --- export / import ---
  Del("C:/Home/TFullExported.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/TFullExported.hgs.m", FALSE, FALSE, FALSE);
  Hgit("export C:/Home/TFullRepo.hgs C:/Home/TFullExported.hgs");
  CommPrint(1, "TFULL_CHECK_EXPORTED_BEGIN\n");
  Hgit("check C:/Home/TFullExported.hgs");
  CommPrint(1, "TFULL_CHECK_EXPORTED_END_MARKER\n");

  // --- discoverability ---
  Hgit("version");
  Hgit("logo");

  CommPrint(1, "TFULL_END\n");
}
HgitFullRegressionTest;

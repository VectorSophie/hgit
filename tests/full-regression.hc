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
  Del("C:/Home/TFullImported.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/TFullImported.hgs.m", FALSE, FALSE, FALSE);
  Del("C:/Home/TFullTreeRepo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/TFullTreeRepo.hgs.m", FALSE, FALSE, FALSE);
  Del("C:/Home/TFTreeRoot/top.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/TFTreeRoot/SubA/inner.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/TFullMergeRepo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/TFullMergeRepo.hgs.m", FALSE, FALSE, FALSE);
  Del("C:/Home/TFMergeFileA.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/TFMergeFileB.txt", FALSE, FALSE, FALSE);
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

  // import is the same real HgitCopyRepo underneath export (just the
  // opposite naming direction) - still a real, separate, user-facing
  // command this suite hadn't exercised under its own name before.
  Hgit("import C:/Home/TFullExported.hgs C:/Home/TFullImported.hgs");
  CommPrint(1, "TFULL_CHECK_IMPORTED_BEGIN\n");
  Hgit("check C:/Home/TFullImported.hgs");
  CommPrint(1, "TFULL_CHECK_IMPORTED_END_MARKER\n");

  // --- offertree / statustree / correcttree (ADR 0010's subdirectory
  // support, exercised together on a real nested directory) ---
  Hgit("init C:/Home/TFullTreeRepo.hgs");
  DirMk("C:/Home/TFTreeRoot");
  DirMk("C:/Home/TFTreeRoot/SubA");
  FileWrite("C:/Home/TFTreeRoot/top.txt", "tree top v1", 11);
  FileWrite("C:/Home/TFTreeRoot/SubA/inner.txt", "tree inner v1", 13);
  Hgit("offertree C:/Home/TFullTreeRepo.hgs C:/Home/TFTreeRoot/ tree_first_offer");

  CommPrint(1, "TFULL_STATUSTREE_BEGIN\n");
  FileWrite("C:/Home/TFTreeRoot/SubA/inner.txt", "tree inner v2 CHANGED", 21);
  Hgit("statustree C:/Home/TFullTreeRepo.hgs C:/Home/TFTreeRoot/");
  CommPrint(1, "TFULL_STATUSTREE_END_MARKER\n");

  Hgit("offertree C:/Home/TFullTreeRepo.hgs C:/Home/TFTreeRoot/ tree_second_offer");
  U8 tree_head2[64];
  CurrentHeadRead("C:/Home/TFullTreeRepo.hgs", tree_head2);
  U8 tree_head2_hex[129];
  HashToHex(tree_head2, tree_head2_hex);

  U8 tree_rel_cmd[512];
  // Relate this offer back to the second tree commit (the real,
  // just-made HEAD) - the same real shape probe 96 already verified.
  StrPrint(tree_rel_cmd, "correcttree C:/Home/TFullTreeRepo.hgs %s 0000000000000000 C:/Home/TFTreeRoot/ tree_correcting_offer", tree_head2_hex);
  Hgit(tree_rel_cmd);
  CommPrint(1, "TFULL_CHECK_TREE_BEGIN\n");
  Hgit("check C:/Home/TFullTreeRepo.hgs");
  CommPrint(1, "TFULL_CHECK_TREE_END_MARKER\n");

  // --- merge (ADR 0011: a real non-conflicting merge, then a real
  // fast-forward) ---
  Hgit("init C:/Home/TFullMergeRepo.hgs");
  FileWrite("C:/Home/TFMergeFileA.txt", "merge fileA root", 17);
  FileWrite("C:/Home/TFMergeFileB.txt", "merge fileB root", 17);
  Hgit("offer C:/Home/TFullMergeRepo.hgs TFMergeFile*.txt merge_root_offer");

  Hgit("path new C:/Home/TFullMergeRepo.hgs merge_feature");
  Hgit("path go C:/Home/TFullMergeRepo.hgs merge_feature");
  FileWrite("C:/Home/TFMergeFileB.txt", "merge fileB EDITED by feature", 30);
  Hgit("offer C:/Home/TFullMergeRepo.hgs TFMergeFile*.txt merge_feature_edit_b");

  // No working-copy checkout step exists (probe 99's own documented
  // lesson) - restore fileB back to root before main's own offer, so
  // main's own commit genuinely represents "left fileB alone".
  Hgit("path go C:/Home/TFullMergeRepo.hgs main");
  FileWrite("C:/Home/TFMergeFileB.txt", "merge fileB root", 17);
  FileWrite("C:/Home/TFMergeFileA.txt", "merge fileA EDITED by main", 27);
  Hgit("offer C:/Home/TFullMergeRepo.hgs TFMergeFile*.txt merge_main_edit_a");

  CommPrint(1, "TFULL_MERGE_BEGIN\n");
  Hgit("merge C:/Home/TFullMergeRepo.hgs merge_feature");
  CommPrint(1, "TFULL_MERGE_END_MARKER\n");
  CommPrint(1, "TFULL_CHECK_MERGED_BEGIN\n");
  Hgit("check C:/Home/TFullMergeRepo.hgs");
  CommPrint(1, "TFULL_CHECK_MERGED_END_MARKER\n");

  // A real fast-forward: a fresh path with no divergence from main.
  Hgit("path new C:/Home/TFullMergeRepo.hgs merge_ff_target");
  FileWrite("C:/Home/TFMergeFileA.txt", "merge fileA further advanced", 29);
  Hgit("offer C:/Home/TFullMergeRepo.hgs TFMergeFile*.txt merge_advance_main_only");
  Hgit("path go C:/Home/TFullMergeRepo.hgs merge_ff_target");
  CommPrint(1, "TFULL_MERGE_FF_BEGIN\n");
  Hgit("merge C:/Home/TFullMergeRepo.hgs main");
  CommPrint(1, "TFULL_MERGE_FF_END_MARKER\n");

  // --- ignore rules (ADR 0014, v1.8.0, probes 117/118) ---
  Del("C:/Home/TFIgnoreRoot/x.tmp", FALSE, FALSE, FALSE);
  Del("C:/Home/TFIgnoreRoot/keep.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/TFIgnoreRoot/.hgitignore", FALSE, FALSE, FALSE);
  Del("C:/Home/TFIgnoreRoot", FALSE, TRUE, FALSE);
  Del("C:/Home/TFIgnoreRepo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/TFIgnoreRepo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/TFIgnoreRepo.hgs");
  DirMk("C:/Home/TFIgnoreRoot");
  FileWrite("C:/Home/TFIgnoreRoot/.hgitignore", "*.tmp\n", 6);
  FileWrite("C:/Home/TFIgnoreRoot/keep.txt", "kept", 4);
  FileWrite("C:/Home/TFIgnoreRoot/x.tmp", "ignored", 7);
  CommPrint(1, "TFULL_IGNORE_BEGIN\n");
  Hgit("offertree C:/Home/TFIgnoreRepo.hgs C:/Home/TFIgnoreRoot/ ignore_test_offer");
  CommPrint(1, "TFULL_IGNORE_END_MARKER\n");
  CommPrint(1, "TFULL_IGNORE_CHECK_BEGIN\n");
  Hgit("check C:/Home/TFIgnoreRepo.hgs");
  CommPrint(1, "TFULL_IGNORE_CHECK_END_MARKER\n");

  // --- attributes/modes (ADR 0015, v1.8.1, probes 119/120): a pure
  // mode change (no content edit) is surfaced by both status and
  // diff, and its OBJ_ATTRS object stays real (check-reachable). ---
  Del("C:/Home/TFAttrsRepo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/TFAttrsRepo.hgs.m", FALSE, FALSE, FALSE);
  Del("C:/Home/.hgitattributes", FALSE, FALSE, FALSE);
  Del("C:/Home/TFAttrsScript.txt", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/TFAttrsRepo.hgs");
  FileWrite("C:/Home/TFAttrsScript.txt", "echo hi", 7);
  Hgit("offer C:/Home/TFAttrsRepo.hgs C:/Home/TFAttrsScript.txt attrs_root_commit");
  FileWrite("C:/Home/.hgitattributes", "TFAttrsScript.txt executable\n", 29);
  CommPrint(1, "TFULL_ATTRS_STATUS_BEGIN\n");
  Hgit("status C:/Home/TFAttrsRepo.hgs C:/Home/TFAttrsScript.txt C:/Home/");
  CommPrint(1, "TFULL_ATTRS_STATUS_END_MARKER\n");
  Hgit("offer C:/Home/TFAttrsRepo.hgs C:/Home/TFAttrsScript.txt attrs_mode_offer");
  U8 attrs_head_hash[64];
  CurrentHeadRead("C:/Home/TFAttrsRepo.hgs", attrs_head_hash);
  U8 attrs_head_hex[129];
  HashToHex(attrs_head_hash, attrs_head_hex);
  U8 attrs_diff_cmd[512];
  StrPrint(attrs_diff_cmd, "diff C:/Home/TFAttrsRepo.hgs %s", attrs_head_hex);
  CommPrint(1, "TFULL_ATTRS_DIFF_BEGIN\n");
  Hgit(attrs_diff_cmd);
  CommPrint(1, "TFULL_ATTRS_DIFF_END_MARKER\n");
  CommPrint(1, "TFULL_ATTRS_CHECK_BEGIN\n");
  Hgit("check C:/Home/TFAttrsRepo.hgs");
  CommPrint(1, "TFULL_ATTRS_CHECK_END_MARKER\n");
  Del("C:/Home/.hgitattributes", FALSE, FALSE, FALSE);

  // --- merge's own real 3-way mode merge (ADR 0015 follow-up, probe
  // 121): a clean mode-only change round-trips through a real,
  // non-fast-forward merge, surfaced by diff on the merge commit. ---
  Del("C:/Home/TFMergeModeRepo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/TFMergeModeRepo.hgs.m", FALSE, FALSE, FALSE);
  Del("C:/Home/.hgitattributes", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/TFMergeModeRepo.hgs");
  FileWrite("C:/Home/TFMM_a.txt", "shared", 6);
  FileWrite("C:/Home/TFMM_b.txt", "other root", 10);
  Hgit("offer C:/Home/TFMergeModeRepo.hgs TFMM_*.txt mm_root");
  Hgit("path new C:/Home/TFMergeModeRepo.hgs mm_feature");
  Hgit("path go C:/Home/TFMergeModeRepo.hgs mm_feature");
  FileWrite("C:/Home/.hgitattributes", "TFMM_a.txt executable\n", 23);
  Hgit("offer C:/Home/TFMergeModeRepo.hgs TFMM_*.txt mm_mode_change");
  Hgit("path go C:/Home/TFMergeModeRepo.hgs main");
  Del("C:/Home/.hgitattributes", FALSE, FALSE, FALSE);
  FileWrite("C:/Home/TFMM_b.txt", "other EDITED", 12);
  Hgit("offer C:/Home/TFMergeModeRepo.hgs TFMM_*.txt mm_other_edit");
  CommPrint(1, "TFULL_MERGEMODE_MERGE_BEGIN\n");
  Hgit("merge C:/Home/TFMergeModeRepo.hgs mm_feature");
  CommPrint(1, "TFULL_MERGEMODE_MERGE_END_MARKER\n");
  U8 mm_head[64];
  CurrentHeadRead("C:/Home/TFMergeModeRepo.hgs", mm_head);
  U8 mm_hex[129];
  HashToHex(mm_head, mm_hex);
  U8 mm_diff_cmd[512];
  StrPrint(mm_diff_cmd, "diff C:/Home/TFMergeModeRepo.hgs %s", mm_hex);
  CommPrint(1, "TFULL_MERGEMODE_DIFF_BEGIN\n");
  Hgit(mm_diff_cmd); // expect DIFF_MODE_CHANGED TFMM_a.txt 0 -> 2
  CommPrint(1, "TFULL_MERGEMODE_DIFF_END_MARKER\n");
  CommPrint(1, "TFULL_MERGEMODE_CHECK_BEGIN\n");
  Hgit("check C:/Home/TFMergeModeRepo.hgs");
  CommPrint(1, "TFULL_MERGEMODE_CHECK_END_MARKER\n");

  // --- discoverability ---
  Hgit("version");
  Hgit("logo");
  CommPrint(1, "TFULL_HELP_BEGIN\n");
  Hgit("help");
  CommPrint(1, "TFULL_HELP_END_MARKER\n");

  CommPrint(1, "TFULL_END\n");
}
HgitFullRegressionTest;

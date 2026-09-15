// Probe 121 test driver: `hgit merge`'s own real 3-way MODE merge
// (ADR 0015 follow-up, docs/ROADMAP-v1.8.md's "mode-only changes"
// gap) - mode is now merged independently of content, the same
// base/ours/theirs decision content already used, and a genuine
// mode-only conflict is reported honestly rather than guessed.
// Verification reuses `hgit diff`'s own already-proven
// DIFF_MODE_CHANGED output (probe 120) rather than re-parsing objects
// by hand.
U0 P121MergeMode3WayTest()
{
  // --- Case 1: clean mode-only 3-way merge, no conflict ---
  // Two files offered together via one wildcard mask (same reason
  // probe 99 does this: `hgit offer`'s own real semantics build the
  // new tree ENTIRELY from what the mask matches - a single-file mask
  // would silently drop the other file from every later commit).
  Del("C:/Home/P121D.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P121D.hgs.m", FALSE, FALSE, FALSE);
  Del("C:/Home/.hgitattributes", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P121D.hgs");
  FileWrite("C:/Home/P121D_file.txt", "shared content", 14);
  FileWrite("C:/Home/P121D_other.txt", "other root", 10);
  Hgit("offer C:/Home/P121D.hgs P121D_*.txt root_both");

  Hgit("path new C:/Home/P121D.hgs feature");
  Hgit("path go C:/Home/P121D.hgs feature");
  // Content of P121D_file.txt is NOT touched - only its mode changes.
  FileWrite("C:/Home/.hgitattributes", "P121D_file.txt executable\n", 27);
  Hgit("offer C:/Home/P121D.hgs P121D_*.txt feature_mode_change");

  // Back to main: reset .hgitattributes (a live filesystem input, not
  // branch-scoped - same gotcha probe 99 already documented for
  // working-directory content) so main's own re-offer genuinely
  // represents "no attrs rule here", and make a real, unrelated
  // content edit so main's own HEAD diverges from base too (otherwise
  // this would be a trivial fast-forward, never exercising the real
  // 3-way merge code at all).
  Hgit("path go C:/Home/P121D.hgs main");
  Del("C:/Home/.hgitattributes", FALSE, FALSE, FALSE);
  FileWrite("C:/Home/P121D_other.txt", "other EDITED by main", 21);
  Hgit("offer C:/Home/P121D.hgs P121D_*.txt main_edits_other");

  CommPrint(1, "P121_CASE1_MERGE_BEGIN\n");
  Hgit("merge C:/Home/P121D.hgs feature");
  CommPrint(1, "P121_CASE1_MERGE_END\n");

  U8 merged_head[64];
  CurrentHeadRead("C:/Home/P121D.hgs", merged_head);
  U8 merged_hex[129];
  HashToHex(merged_head, merged_hex);
  U8 cmd[512];
  StrPrint(cmd, "diff C:/Home/P121D.hgs %s", merged_hex);
  CommPrint(1, "P121_CASE1_DIFF_BEGIN\n");
  Hgit(cmd); // expect DIFF_MODE_CHANGED P121D_file.txt (first parent =
             // ours = main, mode 0; merged tree carries theirs' mode 2)
             // and NOT for P121D_other.txt (content changed, not mode)
  CommPrint(1, "P121_CASE1_DIFF_END\n");

  CommPrint(1, "P121_CASE1_CHECK_BEGIN\n");
  Hgit("check C:/Home/P121D.hgs"); // real referential-integrity check
                                   // on the merge commit's own new
                                   // attrs_hash, same as every other
                                   // object
  CommPrint(1, "P121_CASE1_CHECK_END\n");

  // --- Case 2: genuine mode-only conflict - both sides change mode,
  // differently, content never changes at all ---
  Del("C:/Home/P121C.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P121C.hgs.m", FALSE, FALSE, FALSE);
  Del("C:/Home/.hgitattributes", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P121C.hgs");
  FileWrite("C:/Home/P121C_file.txt", "shared content", 14);
  Hgit("offer C:/Home/P121C.hgs P121C_file.txt root_offer");

  Hgit("path new C:/Home/P121C.hgs feature");
  Hgit("path go C:/Home/P121C.hgs feature");
  FileWrite("C:/Home/.hgitattributes", "P121C_file.txt executable\n", 27);
  Hgit("offer C:/Home/P121C.hgs P121C_file.txt feature_executable");

  Hgit("path go C:/Home/P121C.hgs main");
  FileWrite("C:/Home/.hgitattributes", "P121C_file.txt binary\n", 23);
  Hgit("offer C:/Home/P121C.hgs P121C_file.txt main_binary");

  U8 pre_merge_head[64];
  CurrentHeadRead("C:/Home/P121C.hgs", pre_merge_head);

  CommPrint(1, "P121_CASE2_MERGE_BEGIN\n");
  Hgit("merge C:/Home/P121C.hgs feature");
  CommPrint(1, "P121_CASE2_MERGE_END\n"); // expect MERGE_CONFLICT
                                          // P121C_file.txt then
                                          // MERGE_ABORTED conflicts=1

  U8 post_merge_head[64];
  CurrentHeadRead("C:/Home/P121C.hgs", post_merge_head);
  Bool head_unchanged = TRUE;
  I64 hi;
  for (hi=0; hi<64; hi++) if (pre_merge_head[hi] != post_merge_head[hi]) head_unchanged = FALSE;
  CommPrint(1, "P121_CASE2_HEAD_UNCHANGED=%d\n", head_unchanged); // zero
                                                                  // side
                                                                  // effects,
                                                                  // same
                                                                  // stance
                                                                  // as
                                                                  // every
                                                                  // other
                                                                  // real
                                                                  // conflict

  CommPrint(1, "P121_CASE2_CHECK_BEGIN\n");
  Hgit("check C:/Home/P121C.hgs"); // aborted merge must leave a
                                   // real, clean, uncorrupted repo
  CommPrint(1, "P121_CASE2_CHECK_END\n");

  CommPrint(1, "PASS p121_merge_mode_3way\n");
}
P121MergeMode3WayTest;

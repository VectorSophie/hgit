// Probe 120 test driver: mode changes surfaced in `hgit status` and
// `hgit diff` (ADR 0015's own "mode/type changes surfaced in status
// and diff" requirement, docs/ROADMAP-v1.8.md v1.8.1).
U0 P120ModeChangeTest()
{
  Del("C:/Home/P120Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P120Repo.hgs.m", FALSE, FALSE, FALSE);
  Del("C:/Home/.hgitattributes", FALSE, FALSE, FALSE);
  Del("C:/Home/P120Script.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/P120Plain.txt", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P120Repo.hgs");

  U8 *mask = "C:/Home/P120*.txt";
  U8 cmd[512];

  // Two files, no .hgitattributes yet - both plain text, mode 0.
  FileWrite("C:/Home/P120Script.txt", "echo hi", 7);
  FileWrite("C:/Home/P120Plain.txt", "just data", 9);
  StrPrint(cmd, "offer C:/Home/P120Repo.hgs %s root_commit", mask);
  Hgit(cmd);

  // Content is UNCHANGED for both files, but a real rule now marks
  // P120Script.txt executable - a pure mode change, no content edit.
  FileWrite("C:/Home/.hgitattributes", "P120Script.txt executable\n", 26);

  CommPrint(1, "P120_STATUS_BEGIN\n");
  StrPrint(cmd, "status C:/Home/P120Repo.hgs %s C:/Home/", mask);
  Hgit(cmd);
  CommPrint(1, "P120_STATUS_END\n");

  // Re-offer to persist the mode change as a real second commit.
  StrPrint(cmd, "offer C:/Home/P120Repo.hgs %s second_offer", mask);
  Hgit(cmd);

  U8 head_hash[64];
  CurrentHeadRead("C:/Home/P120Repo.hgs", head_hash);
  U8 head_hex[129];
  HashToHex(head_hash, head_hex);
  StrPrint(cmd, "diff C:/Home/P120Repo.hgs %s", head_hex);
  CommPrint(1, "P120_DIFF_BEGIN\n");
  Hgit(cmd);
  CommPrint(1, "P120_DIFF_END\n");

  // A THIRD offer with the .hgitattributes rule removed again (mode ->
  // 0) - reported once more via both status (before) and diff (after).
  Del("C:/Home/.hgitattributes", FALSE, FALSE, FALSE);
  CommPrint(1, "P120_STATUS2_BEGIN\n");
  StrPrint(cmd, "status C:/Home/P120Repo.hgs %s C:/Home/", mask);
  Hgit(cmd);
  CommPrint(1, "P120_STATUS2_END\n");

  StrPrint(cmd, "offer C:/Home/P120Repo.hgs %s third_offer", mask);
  Hgit(cmd);
  CurrentHeadRead("C:/Home/P120Repo.hgs", head_hash);
  HashToHex(head_hash, head_hex);
  StrPrint(cmd, "diff C:/Home/P120Repo.hgs %s", head_hex);
  CommPrint(1, "P120_DIFF2_BEGIN\n");
  Hgit(cmd);
  CommPrint(1, "P120_DIFF2_END\n");

  StrPrint(cmd, "check C:/Home/P120Repo.hgs");
  Hgit(cmd);

  CommPrint(1, "PASS p120_mode_change_status_diff\n");
}
P120ModeChangeTest;

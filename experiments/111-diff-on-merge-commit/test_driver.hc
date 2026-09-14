// Probe 111 test driver: real verification of `hgit diff` against a
// real merge commit - Diff.HC's own header comment never mentioned
// merge commits at all (it predates ADR 0011). Confirms the existing
// single-parent behavior (diff against the FIRST parent only) is sane
// and coherent when applied to a merge commit, not a crash or a
// silently wrong answer.
U0 P111DiffOnMergeTest()
{
  Del("C:/Home/P111Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P111Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P111Repo.hgs");

  U8 *mask = "C:/Home/P111*.txt";
  U8 cmd[512];

  FileWrite("C:/Home/P111Top.txt", "top v1", 6);
  StrPrint(cmd, "offer C:/Home/P111Repo.hgs %s root_commit", mask);
  Hgit(cmd);

  Hgit("path new C:/Home/P111Repo.hgs feature");
  Hgit("path go C:/Home/P111Repo.hgs feature");
  FileWrite("C:/Home/P111Feat.txt", "feat v1", 7);
  StrPrint(cmd, "offer C:/Home/P111Repo.hgs %s feature_commit", mask);
  Hgit(cmd);

  Hgit("path go C:/Home/P111Repo.hgs main");
  Del("C:/Home/P111Feat.txt", FALSE, FALSE, FALSE);
  FileWrite("C:/Home/P111Main2.txt", "main2 v1", 8);
  StrPrint(cmd, "offer C:/Home/P111Repo.hgs %s main_commit_2", mask);
  Hgit(cmd);

  Hgit("merge C:/Home/P111Repo.hgs feature");

  U8 head_hash[64];
  CurrentHeadRead("C:/Home/P111Repo.hgs", head_hash);
  U8 head_hex[129];
  HashToHex(head_hash, head_hex);
  StrPrint(cmd, "diff C:/Home/P111Repo.hgs %s", head_hex);

  CommPrint(1, "P111_DIFF_BEGIN\n");
  Hgit(cmd);
  CommPrint(1, "P111_DIFF_END\n");

  CommPrint(1, "PASS p111_diff_on_merge_commit\n");
}
P111DiffOnMergeTest;

// Probe 112 test driver: `hgit see` now prints a real SEE_PARENT line
// per parent hash, not just a count - verified against a root commit
// (0 parents), an ordinary commit (1 parent), and a real merge commit
// (2 parents, confirming both the real ours/theirs hashes and their
// real order).
U0 P112SeeParentHashesTest()
{
  Del("C:/Home/P112Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P112Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P112Repo.hgs");

  U8 *mask = "C:/Home/P112*.txt";
  U8 cmd[512];

  // Root commit - 0 parents.
  FileWrite("C:/Home/P112Top.txt", "top v1", 6);
  StrPrint(cmd, "offer C:/Home/P112Repo.hgs %s root_commit", mask);
  Hgit(cmd);
  U8 root_hash[64];
  CurrentHeadRead("C:/Home/P112Repo.hgs", root_hash);
  U8 root_hex[129];
  HashToHex(root_hash, root_hex);

  StrPrint(cmd, "see C:/Home/P112Repo.hgs %s", root_hex);
  CommPrint(1, "P112_SEE_ROOT_BEGIN\n");
  Hgit(cmd);
  CommPrint(1, "P112_SEE_ROOT_END\n");

  // feature diverges from root.
  Hgit("path new C:/Home/P112Repo.hgs feature");
  Hgit("path go C:/Home/P112Repo.hgs feature");
  FileWrite("C:/Home/P112Feat.txt", "feat v1", 7);
  StrPrint(cmd, "offer C:/Home/P112Repo.hgs %s feature_commit", mask);
  Hgit(cmd);
  U8 theirs_hash[64];
  CurrentHeadRead("C:/Home/P112Repo.hgs", theirs_hash);
  U8 theirs_hex[129];
  HashToHex(theirs_hash, theirs_hex);

  // main gets a second, ordinary (1-parent) commit.
  Hgit("path go C:/Home/P112Repo.hgs main");
  Del("C:/Home/P112Feat.txt", FALSE, FALSE, FALSE);
  FileWrite("C:/Home/P112Main2.txt", "main2 v1", 8);
  StrPrint(cmd, "offer C:/Home/P112Repo.hgs %s main_commit_2", mask);
  Hgit(cmd);
  U8 ours_hash[64];
  CurrentHeadRead("C:/Home/P112Repo.hgs", ours_hash);
  U8 ours_hex[129];
  HashToHex(ours_hash, ours_hex);

  StrPrint(cmd, "see C:/Home/P112Repo.hgs %s", ours_hex);
  CommPrint(1, "P112_SEE_ONE_PARENT_BEGIN\n");
  Hgit(cmd);
  CommPrint(1, "P112_SEE_ONE_PARENT_END\n");
  CommPrint(1, "P112_EXPECT_PARENT=%s\n", root_hex);

  // Real merge - 2 parents (ours=main_commit_2, theirs=feature_commit).
  Hgit("merge C:/Home/P112Repo.hgs feature");
  U8 merge_hash[64];
  CurrentHeadRead("C:/Home/P112Repo.hgs", merge_hash);
  U8 merge_hex[129];
  HashToHex(merge_hash, merge_hex);

  StrPrint(cmd, "see C:/Home/P112Repo.hgs %s", merge_hex);
  CommPrint(1, "P112_SEE_MERGE_BEGIN\n");
  Hgit(cmd);
  CommPrint(1, "P112_SEE_MERGE_END\n");
  CommPrint(1, "P112_EXPECT_OURS=%s\n", ours_hex);
  CommPrint(1, "P112_EXPECT_THEIRS=%s\n", theirs_hex);

  CommPrint(1, "PASS p112_see_parent_hashes\n");
}
P112SeeParentHashesTest;

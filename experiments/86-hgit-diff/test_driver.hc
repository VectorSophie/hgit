// Probe 86 test driver: `hgit diff` - per-commit tree diff, including
// exact and fuzzy rename detection.
U0 P86DiffTest()
{
  Del("C:/Home/P86Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P86Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P86Repo.hgs");

  FileWrite("C:/Home/P86Stays.txt", "never touched", 13);
  FileWrite("C:/Home/P86ToModify.txt", "version one", 11);
  FileWrite("C:/Home/P86ToDelete.txt", "going away for real", 20);
  FileWrite("C:/Home/P86Orig.txt",
    "The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog again and again.", 106);
  Hgit("offer C:/Home/P86Repo.hgs P86*.txt first_commit");

  U8 root_hash[64];
  CurrentHeadRead("C:/Home/P86Repo.hgs", root_hash);
  U8 root_hex[129];
  HashToHex(root_hash, root_hex);

  // Second commit: modify one, delete one, rename one WITH an edit,
  // add a genuinely new one. Compare the SECOND commit against the
  // FIRST via `hgit diff`.
  FileWrite("C:/Home/P86ToModify.txt", "version two, changed", 21);
  Del("C:/Home/P86ToDelete.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/P86Orig.txt", FALSE, FALSE, FALSE);
  FileWrite("C:/Home/P86Renamed.txt",
    "The quick brown fox LEAPS over the lazy dog. The quick brown fox jumps over the lazy dog again and again.", 106);
  FileWrite("C:/Home/P86GenuinelyNew.txt", "brand new file, no relation at all here", 40);
  Hgit("offer C:/Home/P86Repo.hgs P86*.txt second_commit");

  U8 head_hash[64];
  CurrentHeadRead("C:/Home/P86Repo.hgs", head_hash);
  U8 head_hex[129];
  HashToHex(head_hash, head_hex);
  U8 cmd[512];
  StrPrint(cmd, "diff C:/Home/P86Repo.hgs %s", head_hex);
  CommPrint(1, "P86_DIFF_SECOND_BEGIN\n");
  Hgit(cmd);
  CommPrint(1, "P86_DIFF_SECOND_END\n");

  // Also diff the FIRST (root) commit - every entry should be NEW,
  // since it has no parent.
  U8 root_cmd[512];
  StrPrint(root_cmd, "diff C:/Home/P86Repo.hgs %s", root_hex);
  CommPrint(1, "P86_DIFF_ROOT_BEGIN\n");
  Hgit(root_cmd);
  CommPrint(1, "P86_DIFF_ROOT_END\n");

  CommPrint(1, "PASS p86_diff_test\n");
}
P86DiffTest;

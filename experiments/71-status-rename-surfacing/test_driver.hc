// Probe 71 test driver: status rename surfacing.
// Positive: offer a file, commit it, then on disk rename it (write
// identical content under a new name, delete the old file) WITHOUT
// offering - `hgit status` should report STATUS_RENAMED old -> new,
// not separate STATUS_DELETED/STATUS_NEW lines.
// Negative: also leave one genuinely new, one genuinely deleted (no
// content match) file present, confirm those still print normally.
U0 P71StatusRenameTest()
{
  Del("C:/Home/P71Repo.hgs", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P71Repo.hgs");

  FileWrite("C:/Home/P71Orig.txt", "rename me please", 16);
  FileWrite("C:/Home/P71Stays.txt", "never touched", 13);
  FileWrite("C:/Home/P71WillDelete.txt", "going away for real", 20);

  Hgit("offer C:/Home/P71Repo.hgs P71*.txt initial_three");
  CommPrint(1, "P71_OFFER_ONE_DONE\n");

  // Simulate an out-of-band rename: same content, new name, old name
  // gone; also a genuinely new file and a genuinely deleted file, both
  // present at the same time as a real opportunity for a false match.
  Del("C:/Home/P71Orig.txt", FALSE, FALSE, FALSE);
  FileWrite("C:/Home/P71Renamed.txt", "rename me please", 16);
  Del("C:/Home/P71WillDelete.txt", FALSE, FALSE, FALSE);
  FileWrite("C:/Home/P71GenuinelyNew.txt", "brand new content here", 22);

  CommPrint(1, "P71_STATUS_BEGIN\n");
  Hgit("status C:/Home/P71Repo.hgs C:/Home/P71*.txt C:/Home/");
  CommPrint(1, "P71_STATUS_END_MARKER\n");
}
P71StatusRenameTest;

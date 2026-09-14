// Probe 113 test driver: a new repo now starts at format_version 2,
// and hgit check now actually shows it (previously read internally
// but never surfaced to a user by any real command).
U0 P113CheckFormatVersionTest()
{
  Del("C:/Home/P113Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P113Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P113Repo.hgs");

  CommPrint(1, "P113_CHECK_EMPTY_BEGIN\n");
  Hgit("check C:/Home/P113Repo.hgs");
  CommPrint(1, "P113_CHECK_EMPTY_END\n");

  // Confirm the repo works completely normally at the new version -
  // this isn't just a header change with everything else broken.
  FileWrite("C:/Home/P113File.txt", "v1", 2);
  Hgit("offer C:/Home/P113Repo.hgs C:/Home/P113File.txt first_offer");

  CommPrint(1, "P113_CHECK_AFTER_OFFER_BEGIN\n");
  Hgit("check C:/Home/P113Repo.hgs");
  CommPrint(1, "P113_CHECK_AFTER_OFFER_END\n");

  CommPrint(1, "PASS p113_check_format_version\n");
}
P113CheckFormatVersionTest;

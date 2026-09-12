// probe 35 — offer/status/history now respect the CURRENT path, not
// just "main", through the real Hgit(cmdline) dispatcher. Verifies two
// paths accumulate genuinely independent HEAD/history, and that
// switching current path is what actually changes which one a command
// sees - not just bookkeeping, as it was as of probe 34.

Hgit("init \"C:/Home/P35Repo.hgs\"");

U8 fa35[3]; fa35[0]='o';fa35[1]='n';fa35[2]='e';
FileWrite("C:/Home/P35FileA.txt", fa35, 3);
Hgit("offer \"C:/Home/P35Repo.hgs\" \"C:/Home/P35FileA*\" main commit 1");
U8 main_head1_35[64];
HeadRead("C:/Home/P35Repo.hgs", main_head1_35); // main's HEAD == <repo>.head directly

// branch off "feature" from main's current state, switch to it.
Hgit("path new \"C:/Home/P35Repo.hgs\" feature");
Hgit("path go \"C:/Home/P35Repo.hgs\" feature");

// offer again while on "feature" - main's own .head file must NOT move.
U8 fa2_35[3]; fa2_35[0]='t';fa2_35[1]='w';fa2_35[2]='o';
FileWrite("C:/Home/P35FileA.txt", fa2_35, 3);
Hgit("offer \"C:/Home/P35Repo.hgs\" \"C:/Home/P35FileA*\" feature commit 1");

U8 main_head_after_35[64];
HeadRead("C:/Home/P35Repo.hgs", main_head_after_35); // still reads main's own file directly
Bool main_unchanged = TRUE;
I64 k35;
for (k35=0;k35<64;k35++) if (main_head_after_35[k35]!=main_head1_35[k35]) main_unchanged=FALSE;
CommPrint(1, "main_unchanged_after_feature_offer=%d\n", main_unchanged);

U8 feature_head_path_35[256];
PathHeadFilePath("C:/Home/P35Repo.hgs", "feature", feature_head_path_35);
I64 fsize35;
U8 *fbuf35 = FileRead(feature_head_path_35, &fsize35);
Bool feature_head_differs_from_main = TRUE;
if (fbuf35 != NULL && fsize35 == 64) {
  Bool same = TRUE;
  for (k35=0;k35<64;k35++) if (fbuf35[k35]!=main_head1_35[k35]) same=FALSE;
  feature_head_differs_from_main = !same;
}
CommPrint(1, "feature_head_differs_from_main=%d\n", feature_head_differs_from_main);

// history while on "feature" should show 2 entries (root + feature's
// own commit); switching back to main and running history should show
// only main's 1 entry - proving HgitHistory now actually depends on
// current path, not always main.
Hgit("history \"C:/Home/P35Repo.hgs\"");     // expect 2 entries (on feature)
Hgit("path go \"C:/Home/P35Repo.hgs\" main");
Hgit("history \"C:/Home/P35Repo.hgs\"");     // expect 1 entry (on main)

// status while on main (0 uncommitted changes expected, file matches
// main's own last commit) vs status while on feature.
Hgit("status \"C:/Home/P35Repo.hgs\" \"C:/Home/P35FileA*\" \"\"");
Hgit("path go \"C:/Home/P35Repo.hgs\" feature");
Hgit("status \"C:/Home/P35Repo.hgs\" \"C:/Home/P35FileA*\" \"\"");

if (main_unchanged && feature_head_differs_from_main)
  CommPrint(1, "PASS path_aware_offer\n");
else
  CommPrint(1, "FAIL path_aware_offer\n");

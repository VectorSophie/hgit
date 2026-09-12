// probe 34 — named paths (hgit's branch equivalent): list/new/go/close,
// through the real Hgit(cmdline) dispatcher's two-word "path <sub>"
// parsing.

Hgit("init \"C:/Home/P34Repo.hgs\"");

// list on a fresh repo - only "main" should exist.
Hgit("path list \"C:/Home/P34Repo.hgs\"");

// give main a real commit so path-new has a real HEAD to copy.
U8 fa34[3]; fa34[0]='o';fa34[1]='n';fa34[2]='e';
FileWrite("C:/Home/P34FileA.txt", fa34, 3);
Hgit("offer \"C:/Home/P34Repo.hgs\" \"C:/Home/P34FileA*\" first offer");
U8 main_head_34[64];
HeadRead("C:/Home/P34Repo.hgs", main_head_34);
U8 main_head_hex_34[129];
HashToHex(main_head_34, main_head_hex_34);
CommPrint(1, "main_head=%s\n", main_head_hex_34);

// create a new path "feature" - should copy main's current HEAD.
Hgit("path new \"C:/Home/P34Repo.hgs\" feature");
U8 feature_head_path_34[256];
PathHeadFilePath("C:/Home/P34Repo.hgs", "feature", feature_head_path_34);
I64 fsize34;
U8 *fbuf34 = FileRead(feature_head_path_34, &fsize34);
Bool feature_head_exists = (fbuf34 != NULL && fsize34 == 64);
Bool feature_head_matches_main = TRUE;
I64 k34;
if (feature_head_exists) {
  for (k34=0;k34<64;k34++) if (fbuf34[k34]!=main_head_34[k34]) feature_head_matches_main=FALSE;
} else {
  feature_head_matches_main = FALSE;
}
CommPrint(1, "feature_head_exists=%d feature_head_matches_main=%d\n",
          feature_head_exists, feature_head_matches_main);

// creating the same path again should fail.
Hgit("path new \"C:/Home/P34Repo.hgs\" feature");

// list should now show main + feature.
Hgit("path list \"C:/Home/P34Repo.hgs\"");

// switch current path to feature.
Hgit("path go \"C:/Home/P34Repo.hgs\" feature");
U8 cur_name_34[64];
CurrentPathGet("C:/Home/P34Repo.hgs", cur_name_34);
CommPrint(1, "current_after_go=%s\n", cur_name_34);

// go to a nonexistent path should fail and leave current unchanged.
Hgit("path go \"C:/Home/P34Repo.hgs\" doesnotexist");
U8 cur_name2_34[64];
CurrentPathGet("C:/Home/P34Repo.hgs", cur_name2_34);
Bool current_unchanged = (StrCmp(cur_name2_34, "feature") == 0);
CommPrint(1, "current_unchanged_after_bad_go=%d\n", current_unchanged);

// close "main" must be refused.
Hgit("path close \"C:/Home/P34Repo.hgs\" main");
Bool main_still_exists = PathExists("C:/Home/P34Repo.hgs", "main");
CommPrint(1, "main_still_exists=%d\n", main_still_exists);

// close "feature" (the current path) - should succeed and reset
// current back to main.
Hgit("path close \"C:/Home/P34Repo.hgs\" feature");
Bool feature_gone = !PathExists("C:/Home/P34Repo.hgs", "feature");
U8 cur_name3_34[64];
CurrentPathGet("C:/Home/P34Repo.hgs", cur_name3_34);
Bool current_reset_to_main = (StrCmp(cur_name3_34, "main") == 0);
CommPrint(1, "feature_gone=%d current_reset_to_main=%d\n",
          feature_gone, current_reset_to_main);

// final list should show only main again.
Hgit("path list \"C:/Home/P34Repo.hgs\"");

if (feature_head_exists && feature_head_matches_main &&
    current_unchanged && main_still_exists &&
    feature_gone && current_reset_to_main)
  CommPrint(1, "PASS hgit_paths\n");
else
  CommPrint(1, "FAIL hgit_paths\n");

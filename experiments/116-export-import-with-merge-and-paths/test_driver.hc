// Probe 116 test driver: `hgit export`/`hgit import` (a raw byte copy
// of both the .hgs object file and Meta.HC's own .m sidecar,
// Portable.HC) had never been tested against a repo containing a
// real merge commit AND more than one real named path with its own
// distinct HEAD. Structurally this should be trivially safe - it's a
// whole-file byte copy, not a parser that could be confused by
// specific content - but never directly confirmed until now.
U0 P116ExportImportMergeTest()
{
  Del("C:/Home/P116Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P116Repo.hgs.m", FALSE, FALSE, FALSE);
  Del("C:/Home/P116Exported.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P116Exported.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P116Repo.hgs");

  U8 *mask = "C:/Home/P116*.txt";
  U8 cmd[512];

  FileWrite("C:/Home/P116Top.txt", "top v1", 6);
  StrPrint(cmd, "offer C:/Home/P116Repo.hgs %s root_commit", mask);
  Hgit(cmd);

  Hgit("path new C:/Home/P116Repo.hgs feature");
  Hgit("path go C:/Home/P116Repo.hgs feature");
  FileWrite("C:/Home/P116Feat.txt", "feat v1", 7);
  StrPrint(cmd, "offer C:/Home/P116Repo.hgs %s feature_commit", mask);
  Hgit(cmd);
  U8 feature_head[64];
  CurrentHeadRead("C:/Home/P116Repo.hgs", feature_head);
  U8 feature_hex[129];
  HashToHex(feature_head, feature_hex);

  Hgit("path go C:/Home/P116Repo.hgs main");
  Del("C:/Home/P116Feat.txt", FALSE, FALSE, FALSE);
  FileWrite("C:/Home/P116Main2.txt", "main2 v1", 8);
  StrPrint(cmd, "offer C:/Home/P116Repo.hgs %s main_commit_2", mask);
  Hgit(cmd);

  Hgit("merge C:/Home/P116Repo.hgs feature");
  U8 merge_head[64];
  CurrentHeadRead("C:/Home/P116Repo.hgs", merge_head);
  U8 merge_hex[129];
  HashToHex(merge_head, merge_hex);
  CommPrint(1, "P116_ORIGINAL_MAIN=%s\n", merge_hex);
  CommPrint(1, "P116_ORIGINAL_FEATURE=%s\n", feature_hex);

  Hgit("export C:/Home/P116Repo.hgs C:/Home/P116Exported.hgs");

  CommPrint(1, "P116_CHECK_EXPORTED_BEGIN\n");
  Hgit("check C:/Home/P116Exported.hgs");
  CommPrint(1, "P116_CHECK_EXPORTED_END\n");

  CommPrint(1, "P116_PATHLIST_BEGIN\n");
  Hgit("path list C:/Home/P116Exported.hgs");
  CommPrint(1, "P116_PATHLIST_END\n");

  // Confirm main's own (post-merge) HEAD survived the copy exactly.
  U8 exported_main_head[64];
  CurrentHeadRead("C:/Home/P116Exported.hgs", exported_main_head);
  U8 exported_main_hex[129];
  HashToHex(exported_main_head, exported_main_hex);
  CommPrint(1, "P116_EXPORTED_MAIN=%s\n", exported_main_hex);

  // Confirm feature's own, DIFFERENT HEAD also survived, on the
  // exported copy specifically.
  Hgit("path go C:/Home/P116Exported.hgs feature");
  U8 exported_feature_head[64];
  CurrentHeadRead("C:/Home/P116Exported.hgs", exported_feature_head);
  U8 exported_feature_hex[129];
  HashToHex(exported_feature_head, exported_feature_hex);
  CommPrint(1, "P116_EXPORTED_FEATURE=%s\n", exported_feature_hex);
  Hgit("path go C:/Home/P116Exported.hgs main");

  // Confirm the operation log survived the copy too - undo on the
  // EXPORTED copy should still work, restoring main's HEAD to its
  // real pre-merge commit there.
  Hgit("undo C:/Home/P116Exported.hgs");
  U8 exported_after_undo[64];
  CurrentHeadRead("C:/Home/P116Exported.hgs", exported_after_undo);
  U8 exported_after_undo_hex[129];
  HashToHex(exported_after_undo, exported_after_undo_hex);
  CommPrint(1, "P116_EXPORTED_AFTER_UNDO=%s\n", exported_after_undo_hex);

  // Confirm undoing the EXPORTED copy did NOT affect the ORIGINAL
  // repo - export is a real, independent copy, not a shared reference.
  U8 original_main_still[64];
  CurrentHeadRead("C:/Home/P116Repo.hgs", original_main_still);
  U8 original_main_still_hex[129];
  HashToHex(original_main_still, original_main_still_hex);
  CommPrint(1, "P116_ORIGINAL_MAIN_STILL=%s\n", original_main_still_hex);

  CommPrint(1, "PASS p116_export_import_merge\n");
}
P116ExportImportMergeTest;

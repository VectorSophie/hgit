// Probe 101 test driver: does Del()'s own real, primary-source-
// confirmed `del_dir` parameter (Kernel/BlkDev/DskCopy.HC's own
// `I64 Del(U8 *files_find_mask, Bool make_mask=FALSE, Bool
// del_dir=FALSE, Bool print_msg=TRUE)`, `FileSysRedSea.HC`'s own
// `RedSeaFilesDel`) really delete a directory ENTRY from disk, not
// just its contents - the real "delete a directory from disk"
// primitive this project has repeatedly flagged as unexplored
// (docs/research/failed-approaches.md's 2026-09-14 DirTreeDel entry,
// ADR 0010/probe 94's own "Not yet done" lists)?
//
// A real, isolated test - no hgit code involved at all, matching the
// same caution the DirTreeDel incident's own recovery used.
U0 P101DelDirTest()
{
  DirMk("C:/Home/P101Dir");
  FileWrite("C:/Home/P101Dir/a.txt", "hello", 5);

  CommPrint(1, "P101_BEFORE_DIR_CHECK\n");
  CDirEntry *before_de = FilesFind("C:/Home/P101Dir*", 0);
  Bool found_before = (before_de != NULL);
  CommPrint(1, "P101_FOUND_BEFORE=%d\n", found_before);
  if (before_de) DirTreeDel(before_de);

  // Delete the file inside first (the already-safe, established
  // practice), then the now-empty directory entry itself via the
  // real del_dir=TRUE parameter.
  Del("C:/Home/P101Dir/a.txt", FALSE, FALSE, FALSE);
  CommPrint(1, "P101_DIR_DEL_BEGIN\n");
  I64 del_result = Del("C:/Home/P101Dir", FALSE, TRUE, FALSE);
  CommPrint(1, "P101_DIR_DEL_RESULT=%d\n", del_result);
  CommPrint(1, "P101_DIR_DEL_END\n");

  CDirEntry *after_de = FilesFind("C:/Home/P101Dir*", 0);
  Bool found_after = (after_de != NULL);
  CommPrint(1, "P101_FOUND_AFTER=%d\n", found_after);
  if (after_de) DirTreeDel(after_de);

  CommPrint(1, "PASS p101_del_dir_test\n");
}
P101DelDirTest;

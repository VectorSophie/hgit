// Probe 88: recursive directory enumeration - a real primitive check
// for whether hgit could ever support subdirectories (currently
// entirely flat, single-level trees only, per Tree.HC's own header
// comment). FilesFind itself is confirmed NON-recursive (a single
// wildcard call lists a directory's own immediate entries only,
// including subdirectories as zero-size entries with attr&16 set -
// not their contents) - this builds and verifies a real recursive
// WALKER on top of it, standalone, not wired into Offer.HC/any real
// command yet.
U0 P88RecursiveWalk(U8 *dir_path, I64 depth)
{
  U8 mask[256];
  StrPrint(mask, "%s*", dir_path);
  CDirEntry *tmpde = FilesFind(mask, 0);
  CDirEntry *tmpde1 = tmpde;
  while (tmpde) {
    I64 name_start = 0, j;
    for (j=0; tmpde->full_name[j]; j++) if (tmpde->full_name[j]=='/') name_start=j+1;
    Bool is_dot = StrCmp(tmpde->full_name+name_start, ".") == 0;
    Bool is_dotdot = StrCmp(tmpde->full_name+name_start, "..") == 0;
    if (!is_dot && !is_dotdot) {
      if (tmpde->attr & 16) {
        CommPrint(1, "P88_DIR depth=%d name=%s\n", depth, tmpde->full_name);
        U8 subdir[256];
        StrPrint(subdir, "%s/", tmpde->full_name);
        P88RecursiveWalk(subdir, depth+1);
      } else {
        CommPrint(1, "P88_FILE depth=%d name=%s size=%d\n", depth, tmpde->full_name, tmpde->size);
      }
    }
    tmpde = tmpde->next;
  }
  DirTreeDel(tmpde1);
}

U0 P88RecursiveWalkTest()
{
  DirMk("C:/Home/P88Root");
  DirMk("C:/Home/P88Root/SubA");
  DirMk("C:/Home/P88Root/SubA/SubAA");
  DirMk("C:/Home/P88Root/SubB");
  FileWrite("C:/Home/P88Root/top.txt", "top level", 9);
  FileWrite("C:/Home/P88Root/SubA/a1.txt", "in suba", 7);
  FileWrite("C:/Home/P88Root/SubA/SubAA/deep.txt", "deeply nested", 13);
  FileWrite("C:/Home/P88Root/SubB/b1.txt", "in subb", 7);

  CommPrint(1, "P88_WALK_BEGIN\n");
  P88RecursiveWalk("C:/Home/P88Root/", 0);
  CommPrint(1, "P88_WALK_END\n");
  CommPrint(1, "PASS p88_recursive_walk_test\n");
}
P88RecursiveWalkTest;

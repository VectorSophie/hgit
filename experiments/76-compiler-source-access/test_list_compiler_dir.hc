U0 P76FindDis2()
{
  CDirEntry *tmpde = FilesFind("D:/Compiler/*", 0);
  CDirEntry *tmpde1 = tmpde;
  I64 n = 0;
  while (tmpde) {
    CommPrint(1, "FOUND %s\n", tmpde->full_name);
    n++;
    tmpde = tmpde->next;
  }
  DirTreeDel(tmpde1);
  CommPrint(1, "P76_FINDDIS2_DONE count=%d\n", n);
}
P76FindDis2;

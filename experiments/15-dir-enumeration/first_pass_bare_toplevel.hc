CDirEntry *tmpde = FilesFind("*", 0);
CDirEntry *tmpde1 = tmpde;
I64 count = 0;
while (tmpde) {
  CommPrint(1,"entry: name=%s size=%d\n", tmpde->full_name, tmpde->size);
  count++;
  tmpde = tmpde->next;
}
CommPrint(1,"count=%d\n", count);
DirTreeDel(tmpde1);
if (count > 0)
  CommPrint(1,"PASS dir_enumeration\n");
else
  CommPrint(1,"FAIL dir_enumeration\n");

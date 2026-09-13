U0 P76ReadOpt()
{
  I64 sz;
  U8 *buf = FileRead("D:/Compiler/OptPass012.HC.Z", &sz);
  if (buf == NULL) { CommPrint(1, "P76_READOPT_NULL\n"); return; }
  CommPrint(1, "P76_READOPT_SIZE=%d\n", sz);
  I64 i;
  I64 cap = sz; if (cap > 200) cap = 200;
  for (i=0; i<cap; i++) CommPrint(1, "%c", buf[i]);
  CommPrint(1, "\nP76_READOPT_DONE\n");
}
P76ReadOpt;

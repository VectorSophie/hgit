U0 P76ReadOpt3()
{
  I64 sz;
  U8 *buf = FileRead("D:/Compiler/OptPass012.HC.Z", &sz);
  if (buf == NULL) { CommPrint(1, "P76_READOPT3_NULL\n"); return; }
  I64 i;
  I64 start = 3000, cap = sz; if (cap > 5500) cap = 5500;
  for (i=start; i<cap; i++) CommPrint(1, "%c", buf[i]);
  CommPrint(1, "\nP76_READOPT3_DONE\n");
}
P76ReadOpt3;

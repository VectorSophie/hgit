U0 P76ReadOpt2()
{
  I64 sz;
  U8 *buf = FileRead("D:/Compiler/OptPass012.HC.Z", &sz);
  if (buf == NULL) { CommPrint(1, "P76_READOPT2_NULL\n"); return; }
  I64 i;
  I64 start = 0, cap = sz; if (cap > 3000) cap = 3000;
  for (i=start; i<cap; i++) CommPrint(1, "%c", buf[i]);
  CommPrint(1, "\nP76_READOPT2_DONE\n");
}
P76ReadOpt2;

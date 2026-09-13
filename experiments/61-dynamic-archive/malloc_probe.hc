U0 MallocProbe()
{
  I64 size = 20000;
  U8 *buf = MAlloc(size);
  I64 i;
  for (i=0; i<size; i++) buf[i] = (i % 256);
  Bool ok = TRUE;
  for (i=0; i<size; i++) if (buf[i] != (i % 256)) ok = FALSE;
  CommPrint(1, "MALLOC_PROBE size=%d ok=%d\n", size, ok);
  Free(buf);
  CommPrint(1, "PASS malloc_probe\n");
}
MallocProbe;

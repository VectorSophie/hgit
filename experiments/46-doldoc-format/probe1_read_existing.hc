// probe 46 step 1 — read a real, already-existing TempleOS help
// document's raw bytes to confirm whether $..$ DolDoc commands are
// stored as literal text in the file, or some binary/escaped form the
// renderer decodes - the exact unresolved risk flagged in doc 02.

I64 size;
U8 *buf = FileRead("::/Doc/CmdLineOverview.DD", &size);
CommPrint(1, "exists=%d size=%d\n", buf!=NULL, size);
if (buf != NULL) {
  I64 n = size;
  if (n > 400) n = 400;
  I64 i;
  for (i=0; i<n; i++) CommPrint(1, "%c", buf[i]);
  CommPrint(1, "\n---END---\n");
}

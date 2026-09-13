// probe 46 step 3 — confirm the .DD file's raw bytes on disk are
// exactly the literal command text we wrote (round-trip, no
// transformation happened on write or on Ed() viewing it).
I64 size;
U8 *buf = FileRead("C:/Home/HgitHistoryTest.DD", &size);
CommPrint(1, "exists=%d size=%d\n", buf!=NULL, size);
if (buf != NULL) {
  I64 i;
  for (i=0; i<size; i++) CommPrint(1, "%c", buf[i]);
  CommPrint(1, "\n---END---\n");
}

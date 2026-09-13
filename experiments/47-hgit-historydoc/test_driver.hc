// probe 47 — `hgit historydoc`: a real DolDoc history view, built on
// probe 46's confirmed research (literal $..$ text, HolyC-writable,
// renders via Ed()). Two real commits, generate the doc, verify both
// its raw byte content (the commands are really there) and its
// rendered appearance (screenshot, checked separately after this
// push).

Hgit("init \"C:/Home/P47Repo.hgs\"");
U8 fa47[3]; fa47[0]='o';fa47[1]='n';fa47[2]='e';
FileWrite("C:/Home/P47FileA.txt", fa47, 3);
Hgit("offer \"C:/Home/P47Repo.hgs\" \"C:/Home/P47FileA*\" root commit");
U8 fa2_47[3]; fa2_47[0]='t';fa2_47[1]='w';fa2_47[2]='o';
FileWrite("C:/Home/P47FileA.txt", fa2_47, 3);
Hgit("offer \"C:/Home/P47Repo.hgs\" \"C:/Home/P47FileA*\" second commit");

Hgit("historydoc \"C:/Home/P47Repo.hgs\" \"C:/Home/P47History.DD\"");

// verify the raw content landed correctly - both commits present,
// colored, in the right (most-recent-first) order.
I64 size;
U8 *buf = FileRead("C:/Home/P47History.DD", &size);
CommPrint(1, "doc_exists=%d size=%d\n", buf!=NULL, size);
if (buf != NULL) {
  I64 i;
  for (i=0; i<size; i++) CommPrint(1, "%c", buf[i]);
  CommPrint(1, "\n---END---\n");
}

Ed("C:/Home/P47History.DD");

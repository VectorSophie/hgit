// probe 46 step 2 — can HolyC code WRITE a new .DD file (not just
// read an existing one) containing real DolDoc commands, and have it
// render correctly when opened? Uses CommPrint-style literal command
// text (confirmed real in step 1: e.g. $FG,2$ sets a color) via
// FileWrite, then Ed() opens it for a live, rendered view.

U8 doc_content[512];
U8 *src = "$FG,2$hgit history (rendered DolDoc test)$FG$$CR$$CR$"
          "$FG,4$commit 1$FG$: root offering$CR$"
          "$FG,4$commit 2$FG$: second offering$CR$";
I64 i = 0;
while (src[i]) { doc_content[i] = src[i]; i++; }
doc_content[i] = 0;

FileWrite("C:/Home/HgitHistoryTest.DD", doc_content, i);
CommPrint(1, "wrote %d bytes\n", i);

Ed("C:/Home/HgitHistoryTest.DD");

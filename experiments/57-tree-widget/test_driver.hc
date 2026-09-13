U0 P57CTest()
{
  U8 doc[1024];
  I64 dlen=0;
  U8 *s;
  I64 fi;
  s="$FG,5$hgit reconciliation (tree)$FG$$CR$$CR$";
  for (fi=0;s[fi];fi++) doc[dlen++]=s[fi];
  s="$TR,\"correct: commit abc123\"$$CR$";
  for (fi=0;s[fi];fi++) doc[dlen++]=s[fi];
  s="$ID,+2$";
  for (fi=0;s[fi];fi++) doc[dlen++]=s[fi];
  s="target: offer_one$CR$entity: none$CR$";
  for (fi=0;s[fi];fi++) doc[dlen++]=s[fi];
  s="$ID,-2$";
  for (fi=0;s[fi];fi++) doc[dlen++]=s[fi];
  s="$TR,\"revert: commit def456\"$$CR$";
  for (fi=0;s[fi];fi++) doc[dlen++]=s[fi];
  s="$ID,+2$";
  for (fi=0;s[fi];fi++) doc[dlen++]=s[fi];
  s="target: offer_two$CR$";
  for (fi=0;s[fi];fi++) doc[dlen++]=s[fi];
  s="$ID,-2$";
  for (fi=0;s[fi];fi++) doc[dlen++]=s[fi];
  FileWrite("C:/Home/P57CTree.DD", doc, dlen);
  CommPrint(1,"WROTE bytes=%d\n", dlen);
}
P57CTest;

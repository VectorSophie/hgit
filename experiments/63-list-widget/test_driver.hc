U0 P63Test()
{
  DefineLstLoad("HGIT_REL_TYPES","CONTINUES\0CORRECTS\0REVERTS\0RECONCILES\0");
  U8 *doc="$FG,5$hgit LS widget test$FG$$CR$$CR$"
    "relation type: $LS,D=\"HGIT_REL_TYPES\"$$CR$";
  I64 dlen = StrLen(doc);
  FileWrite("C:/Home/P63LS.DD", doc, dlen);
  CommPrint(1,"WROTE bytes=%d\n", dlen);
}
P63Test;

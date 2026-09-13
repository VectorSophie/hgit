U0 P54Test()
{
  I64 fd;
  U8 *doc="$FG,5$hgit widget test$FG$$CR$$CR$"
    "$LK,\"reconcile_here\"$Click this link$LK$$CR$"
    "$TR$Root$CR$  Child A$CR$  Child B$CR$$TR$$CR$";
  fd=FileWrite("C:/Home/P54Widgets.DD", doc, StrLen(doc));
  CommPrint(1,"WROTE bytes=%d\n", StrLen(doc));
  CommPrint(1,"PASS doldoc_widgets_written\n");
}
P54Test;

// diagnostic 6b: same as diag6 but correctly wrapped in a real
// function (diag6.hc's bare top-level for loop with local decls was
// itself invalid per this project's own documented HolyC quirk -
// caught here, not repeated).
U0 Diag6b()
{
  U8 buf8[8];
  I64 i;
  for (i=0;i<8;i++) buf8[i] = i+1;

  U8 name[64];
  I64 lens[7];
  lens[0]=28; lens[1]=30; lens[2]=31; lens[3]=32; lens[4]=33; lens[5]=34; lens[6]=36;

  I64 li;
  for (li=0; li<7; li++) {
    I64 total_len = lens[li];
    U8 *prefix = "C:/Home/";
    I64 p = 0;
    while (prefix[p]) { name[p] = prefix[p]; p++; }
    I64 fname_len = total_len - 8;
    I64 j;
    for (j=0; j<fname_len; j++) name[p+j] = 'a';
    name[p+fname_len] = 0;

    FileWrite(name, buf8, 8);
    I64 sz;
    U8 *rb = FileRead(name, &sz);
    CommPrint(1, "len=%d exists=%d size=%d\n", total_len, rb!=NULL, sz);
  }
}
Diag6b();

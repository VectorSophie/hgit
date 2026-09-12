// diagnostic 6: binary-search the exact filename/path length boundary
// between "FileWrite/FileRead round-trips" and "silently does nothing".
// Uses fixed short "C:/Home/" prefix (8 chars) and pads the filename
// with 'x' characters to hit exact target total lengths.

U8 buf8[8];
I64 i;
for (i=0;i<8;i++) buf8[i] = i+1;

U8 name[64];
I64 lens[7];
lens[0]=28; lens[1]=30; lens[2]=31; lens[3]=32; lens[4]=33; lens[5]=34; lens[6]=36;

I64 li;
for (li=0; li<7; li++) {
  I64 total_len = lens[li];
  // "C:/Home/" is 8 chars; fill the rest with 'a', ensure valid (no
  // dot needed - test raw length limit first, not a specific shape).
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

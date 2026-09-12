I64 ExtractTokenQ(U8 *s, I64 pos, U8 *out, I64 out_max)
{
  while (s[pos]==' ') pos++;
  I64 i=0;
  if (s[pos]=='"') {
    pos++;
    while (s[pos] && s[pos]!='"' && i<out_max-1) { out[i]=s[pos]; i++; pos++; }
    if (s[pos]=='"') pos++;
  } else {
    while (s[pos] && s[pos]!=' ' && i<out_max-1) { out[i]=s[pos]; i++; pos++; }
  }
  out[i]=0;
  while (s[pos]==' ') pos++;
  return pos;
}

// --- backward compatibility: unquoted token still works exactly as before ---
U8 tok1[64];
I64 pos1 = ExtractTokenQ("plain_token rest_of_string", 0, tok1, 64);
CommPrint(1, "tok1=%s pos1=%d (expect 'plain_token' 12)\n", tok1, pos1);

// --- a quoted token containing a space is extracted whole, quotes stripped ---
U8 tok2[64];
I64 pos2 = ExtractTokenQ("\"C:/Home/Repo With Space.hgs\" nextarg", 0, tok2, 64);
CommPrint(1, "tok2=%s pos2=%d\n", tok2, pos2);

// --- the actual point: create a real file at a spaced path, and confirm
// a quoted dispatcher argument round-trips through to a real FileWrite/
// FileRead using that exact path ---
U8 spaced_data[5]; spaced_data[0]='s';spaced_data[1]='p';spaced_data[2]='a';spaced_data[3]='c';spaced_data[4]='e';
FileWrite(tok2, spaced_data, 5);
I64 rsize;
U8 *rbuf = FileRead("C:/Home/Repo With Space.hgs", &rsize);
CommPrint(1, "spaced_file_exists=%d spaced_file_size=%d\n", rbuf!=NULL, rsize);

if (StrCmp(tok1,"plain_token")==0 && pos1==12 &&
    StrCmp(tok2,"C:/Home/Repo With Space.hgs")==0 &&
    rbuf!=NULL && rsize==5)
  CommPrint(1, "PASS quoted_token_parsing\n");
else
  CommPrint(1, "FAIL quoted_token_parsing\n");

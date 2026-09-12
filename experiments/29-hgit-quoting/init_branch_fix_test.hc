U0 Hgit5(U8 *cmdline)
{
  I64 i = 0;
  while (cmdline[i] && cmdline[i] != ' ') i++;
  U8 cmd[32];
  I64 j;
  for (j=0; j<i && j<31; j++) cmd[j] = cmdline[j];
  cmd[j] = 0;
  U8 *rest = cmdline + i;
  while (*rest == ' ') rest++;
  if (StrCmp(cmd, "init") == 0) {
    U8 init_path[256];
    ExtractToken(rest, 0, init_path, 256);
    Bool ok = HgitInit(init_path);
    if (ok) CommPrint(1, "DISPATCH_OK init %s\n", init_path);
    else CommPrint(1, "DISPATCH_ERR init_failed %s\n", init_path);
  }
}
Hgit5("init \"C:/Home/Quoted Repo2.hgs\"");
I64 q2size;
U8 *q2buf = FileRead("C:/Home/Quoted Repo2.hgs", &q2size);
CommPrint(1,"fixed_quoted_repo_created=%d size=%d\n", q2buf!=NULL, q2size);

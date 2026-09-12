// Hgit.HC — the actual entry point. Resolves the open question from
// doc 01 ("how does an argv-taking hgit command fit a system whose cmd
// line is a live HolyC REPL") - the premise was wrong. TempleOS has NO
// space-separated shell-argument syntax at all (confirmed from primary
// source, Doc/CmdLineOverview.DD: every native "command" - Dir(...),
// Cd(...), Ed(...) - is a literal HolyC function call with normal
// parens/string-literal args, never bare unquoted tokens). So there is
// no argv/main() convention to fit into.
//
// hgit's entry point is one function, `Hgit`, taking a single string
// exactly the way every other native command takes its one string
// argument. It splits the first space-separated word as a command name
// and dispatches to the already-independently-verified `Hgit*()`
// functions (Init.HC, Status.HC, Offer.HC, History.HC, See.HC). Called
// at the cmd line exactly like any other TempleOS command:
//
//     Hgit("init C:/Home/MyRepo.hgs");
//     Hgit("status C:/Home/MyRepo.hgs C:/Home/MyFiles* C:/Home/");
//     Hgit("history C:/Home/MyRepo.hgs");
//
// Verified (experiments/23-hgit-dispatch/, experiments/24-hgit-dispatch-more/):
// init/status/history all dispatch correctly against a real repository,
// and an unknown command reports cleanly.
//
// IMPORTANT HolyC quirk, confirmed by testing (see
// experiments/24-hgit-dispatch-more/): declaring a same-named local
// variable in two different `else if` branches of ONE function can
// throw "Duplicate member" at compile time - HolyC's local-variable
// scope for `if`/`else if` branches inside a single function does not
// appear to be block-scoped the way C's is. Every branch below uses a
// distinctly-named local for anything that isn't shared across
// branches (e.g. `hist_repo_path`, not a second `repo_path`) - don't
// "clean this up" by reusing a name from another branch.
//
// `offer` and `see` are not wired yet - `offer` needs a free-text
// message field (can't be naively space-split the way the others are)
// and a timestamp source; `see` needs hex-string-to-hash parsing.
// Neither has been designed, let alone tested - real next work.
//
// Depends on Canon.HC, Blake2b.HC, Archive.HC, Hgs.HC, Object.HC,
// Tree.HC, Commit.HC, Index.HC, Init.HC, Head.HC, WorkDir.HC,
// Status.HC, History.HC.

I64 ExtractToken(U8 *s, I64 pos, U8 *out, I64 out_max)
{
  while (s[pos]==' ') pos++;
  I64 i=0;
  while (s[pos] && s[pos]!=' ' && i<out_max-1) { out[i]=s[pos]; i++; pos++; }
  out[i]=0;
  while (s[pos]==' ') pos++;
  return pos;
}

U0 Hgit(U8 *cmdline)
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
    Bool ok = HgitInit(rest);
    if (ok) CommPrint(1, "DISPATCH_OK init %s\n", rest);
    else CommPrint(1, "DISPATCH_ERR init_failed %s\n", rest);
  } else if (StrCmp(cmd, "status") == 0) {
    U8 repo_path[256], find_mask[256], dir_prefix[256];
    I64 p = 0;
    p = ExtractToken(rest, p, repo_path, 256);
    p = ExtractToken(rest, p, find_mask, 256);
    p = ExtractToken(rest, p, dir_prefix, 256);
    HgitStatus(repo_path, find_mask, dir_prefix);
  } else if (StrCmp(cmd, "history") == 0) {
    U8 hist_repo_path[256];
    ExtractToken(rest, 0, hist_repo_path, 256);
    HgitHistory(hist_repo_path);
  } else {
    CommPrint(1, "DISPATCH_ERR unknown_command %s\n", cmd);
  }
}

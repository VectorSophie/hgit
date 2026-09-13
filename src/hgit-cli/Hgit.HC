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
//     Hgit("init \"C:/Home/My Repo.hgs\"");   // quoted path, spaces OK
//     Hgit("status C:/Home/MyRepo.hgs C:/Home/MyFiles* C:/Home/");
//     Hgit("history C:/Home/MyRepo.hgs");
//
// Verified (experiments/23-hgit-dispatch/, experiments/24-hgit-dispatch-more/,
// experiments/26-hgit-see-dispatch/, experiments/27-hgit-offer-dispatch/):
// all five commands (init/status/history/see/offer) dispatch correctly
// against a real repository, and an unknown command reports cleanly.
// `offer`'s free-text message (spaces preserved, not truncated at the
// first space) round-tripped correctly through a real commit and back
// out via `see`.
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
// `offer`'s free-text message is everything after its first two
// tokens (repo path, find mask), taken verbatim via StrLen - not
// further split on spaces. Its timestamp is `cnts.jiffies` (confirmed
// real, `Kernel/KTask.HC` uses it directly as a plain comparable/
// addable number) - a monotonic jiffy count, not wall-clock time; see
// Commit.HC's own note that the timestamp's real-world meaning is
// still undecided.
//
// IMPORTANT: every branch here is compiled as part of ONE function
// body, so HolyC must resolve every symbol any branch references at
// COMPILE time, regardless of which branch runs. Concretely: testing
// ANY single command through this file requires including ALL of
// Init.HC, Status.HC (+ WorkDir.HC), History.HC, See.HC (+ Hex.HC),
// and Offer.HC - not just the one command being tested. Forgetting one
// throws a real compile error naming the missing function (e.g.
// "Compiler Parse Error at 'HgitInit'") - this happened three times
// while building this file (experiments/26, 27) and was first
// misdiagnosed as a session-state issue before the actual pattern
// (missing dependency, not session weirdness) was confirmed. See
// failed-approaches.md's corrected entry.
//
// Depends on Canon.HC, Blake2b.HC, Archive.HC, Hgs.HC, Object.HC,
// Tree.HC, Commit.HC, Index.HC, Init.HC, Head.HC, WorkDir.HC,
// Status.HC, History.HC, See.HC, Hex.HC, Offer.HC.

// Extracts the next token from `s` starting at `pos`. A token wrapped
// in double quotes (`"like this"`) is read up to the matching closing
// quote - allowing spaces inside - with the quotes themselves stripped
// from `out`; otherwise reads up to the next space, as before.
// Verified (experiments/29-hgit-quoting/): a real file created at a
// space-containing path via a quoted argument round-tripped correctly
// through FileWrite/FileRead; plain unquoted tokens are unaffected
// (confirmed same output/position as before this was added).
I64 ExtractToken(U8 *s, I64 pos, U8 *out, I64 out_max)
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

// Parses a non-negative decimal integer from a NUL-terminated string
// (digits only - no sign, no whitespace skipping beyond what
// ExtractToken already stripped). Just enough for a small index like
// `hgit operation restore <op>`'s <op> argument; not a general atoi.
I64 ParseI64(U8 *s)
{
  I64 v = 0;
  I64 i = 0;
  while (s[i] >= '0' && s[i] <= '9') {
    v = v*10 + (s[i]-'0');
    i++;
  }
  return v;
}

// Shared by the `correct`/`revert`/`reconcile` dispatch branches
// (ADR 0005, experiments/51-relation-commands/): parses
// "<repo> <target_hex> <find_mask> <message...>" from `rest` and
// offers with the given relation tag naming the decoded target commit.
// Reports its own DISPATCH_OK/ERR so each caller doesn't repeat it.
// Parses "<repo> <target_hex> <entity_hex> <find_mask> <message...>" -
// `entity_hex` is 16 hex chars per Hex.HC's U64ToHex/HexToU64 (ADR
// 0006); pass 16 zero digits ("0000000000000000") for "not
// entity-scoped," matching Commit.HC's own 0-means-unscoped sentinel.
U0 HgitOfferRelatedCmd(U8 *rest, U8 relation_tag, U8 *cmd_name)
{
  U8 rel_repo_path[256], rel_hex[129], rel_entity_hex[17], rel_find_mask[256];
  I64 rel_p = 0;
  rel_p = ExtractToken(rest, rel_p, rel_repo_path, 256);
  rel_p = ExtractToken(rest, rel_p, rel_hex, 129);
  rel_p = ExtractToken(rest, rel_p, rel_entity_hex, 17);
  rel_p = ExtractToken(rest, rel_p, rel_find_mask, 256);
  U8 *rel_message = rest + rel_p;
  I64 rel_mlen = StrLen(rel_message);

  U8 rel_target[64];
  Bool hok = HexToHash(rel_hex, rel_target);
  if (!hok) { CommPrint(1, "DISPATCH_ERR bad_hash %s\n", rel_hex); return; }

  U64 rel_entity_id;
  Bool eok = HexToU64(rel_entity_hex, &rel_entity_id);
  if (!eok) { CommPrint(1, "DISPATCH_ERR bad_entity_id %s\n", rel_entity_hex); return; }

  U64 rel_ts = cnts.jiffies;
  HgitOfferWithRelation(rel_repo_path, rel_find_mask, rel_message, rel_mlen,
                         rel_ts, relation_tag, rel_target, rel_entity_id);
  CommPrint(1, "DISPATCH_OK %s\n", cmd_name);
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
    U8 init_path[256];
    ExtractToken(rest, 0, init_path, 256);
    Bool ok = HgitInit(init_path);
    if (ok) CommPrint(1, "DISPATCH_OK init %s\n", init_path);
    else CommPrint(1, "DISPATCH_ERR init_failed %s\n", init_path);
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
  } else if (StrCmp(cmd, "see") == 0) {
    U8 see_repo_path[256], see_hex[129];
    I64 see_p = 0;
    see_p = ExtractToken(rest, see_p, see_repo_path, 256);
    see_p = ExtractToken(rest, see_p, see_hex, 129);
    U8 see_hash[64];
    Bool see_ok = HexToHash(see_hex, see_hash);
    if (!see_ok) { CommPrint(1, "DISPATCH_ERR bad_hash %s\n", see_hex); return; }
    HgitSee(see_repo_path, see_hash);
  } else if (StrCmp(cmd, "offer") == 0) {
    U8 offer_repo_path[256], offer_find_mask[256];
    I64 offer_p = 0;
    offer_p = ExtractToken(rest, offer_p, offer_repo_path, 256);
    offer_p = ExtractToken(rest, offer_p, offer_find_mask, 256);
    U8 *offer_message = rest + offer_p;
    I64 offer_mlen = StrLen(offer_message);
    U64 offer_ts = cnts.jiffies;
    HgitOffer(offer_repo_path, offer_find_mask, offer_message, offer_mlen, offer_ts);
    CommPrint(1, "DISPATCH_OK offer\n");
  } else if (StrCmp(cmd, "correct") == 0) {
    HgitOfferRelatedCmd(rest, REL_CORRECTS, "correct");
  } else if (StrCmp(cmd, "revert") == 0) {
    HgitOfferRelatedCmd(rest, REL_REVERTS, "revert");
  } else if (StrCmp(cmd, "reconcile") == 0) {
    HgitOfferRelatedCmd(rest, REL_RECONCILES, "reconcile");
  } else if (StrCmp(cmd, "undo") == 0) {
    U8 undo_repo_path[256];
    ExtractToken(rest, 0, undo_repo_path, 256);
    Bool undo_ok = OpLogUndo(undo_repo_path);
    if (undo_ok) CommPrint(1, "DISPATCH_OK undo\n");
    else CommPrint(1, "DISPATCH_ERR nothing_to_undo\n");
  } else if (StrCmp(cmd, "redo") == 0) {
    U8 redo_repo_path[256];
    ExtractToken(rest, 0, redo_repo_path, 256);
    Bool redo_ok = OpLogRedo(redo_repo_path);
    if (redo_ok) CommPrint(1, "DISPATCH_OK redo\n");
    else CommPrint(1, "DISPATCH_ERR nothing_to_redo\n");
  } else if (StrCmp(cmd, "operation") == 0) {
    // Two-word command ("operation history ...") - `cmd` above only
    // captured "operation", so pull the sub-command as the next token
    // of `rest` before treating whatever follows as the sub-command's
    // own arguments.
    U8 op_sub[32];
    I64 op_p = ExtractToken(rest, 0, op_sub, 32);
    if (StrCmp(op_sub, "history") == 0) {
      U8 op_hist_repo_path[256];
      ExtractToken(rest, op_p, op_hist_repo_path, 256);
      OpLogHistory(op_hist_repo_path);
      CommPrint(1, "DISPATCH_OK operation_history\n");
    } else if (StrCmp(op_sub, "restore") == 0) {
      U8 op_rest_repo_path[256], op_rest_idx_str[32];
      I64 op_rest_p = ExtractToken(rest, op_p, op_rest_repo_path, 256);
      ExtractToken(rest, op_rest_p, op_rest_idx_str, 32);
      I64 op_rest_idx = ParseI64(op_rest_idx_str);
      Bool op_rest_ok = OpLogRestore(op_rest_repo_path, op_rest_idx);
      if (op_rest_ok) CommPrint(1, "DISPATCH_OK operation_restore %d\n", op_rest_idx);
      else CommPrint(1, "DISPATCH_ERR operation_restore_failed %d\n", op_rest_idx);
    } else {
      CommPrint(1, "DISPATCH_ERR unknown_operation_subcommand %s\n", op_sub);
    }
  } else if (StrCmp(cmd, "path") == 0) {
    U8 path_sub[32];
    I64 path_p = ExtractToken(rest, 0, path_sub, 32);
    if (StrCmp(path_sub, "list") == 0) {
      U8 path_list_repo[256];
      ExtractToken(rest, path_p, path_list_repo, 256);
      PathListPrint(path_list_repo);
      CommPrint(1, "DISPATCH_OK path_list\n");
    } else if (StrCmp(path_sub, "new") == 0) {
      U8 path_new_repo[256], path_new_name[HGIT_MAX_PATH_NAME];
      I64 path_new_p = ExtractToken(rest, path_p, path_new_repo, 256);
      ExtractToken(rest, path_new_p, path_new_name, HGIT_MAX_PATH_NAME);
      Bool path_new_ok = PathNew(path_new_repo, path_new_name);
      if (path_new_ok) CommPrint(1, "DISPATCH_OK path_new %s\n", path_new_name);
      else CommPrint(1, "DISPATCH_ERR path_new_failed %s\n", path_new_name);
    } else if (StrCmp(path_sub, "go") == 0) {
      U8 path_go_repo[256], path_go_name[HGIT_MAX_PATH_NAME];
      I64 path_go_p = ExtractToken(rest, path_p, path_go_repo, 256);
      ExtractToken(rest, path_go_p, path_go_name, HGIT_MAX_PATH_NAME);
      Bool path_go_ok = PathGo(path_go_repo, path_go_name);
      if (path_go_ok) CommPrint(1, "DISPATCH_OK path_go %s\n", path_go_name);
      else CommPrint(1, "DISPATCH_ERR path_go_failed %s\n", path_go_name);
    } else if (StrCmp(path_sub, "close") == 0) {
      U8 path_close_repo[256], path_close_name[HGIT_MAX_PATH_NAME];
      I64 path_close_p = ExtractToken(rest, path_p, path_close_repo, 256);
      ExtractToken(rest, path_close_p, path_close_name, HGIT_MAX_PATH_NAME);
      Bool path_close_ok = PathClose(path_close_repo, path_close_name);
      if (path_close_ok) CommPrint(1, "DISPATCH_OK path_close %s\n", path_close_name);
      else CommPrint(1, "DISPATCH_ERR path_close_failed %s\n", path_close_name);
    } else {
      CommPrint(1, "DISPATCH_ERR unknown_path_subcommand %s\n", path_sub);
    }
  } else if (StrCmp(cmd, "historydoc") == 0) {
    U8 hdoc_repo[256], hdoc_dest[256];
    I64 hdoc_p = ExtractToken(rest, 0, hdoc_repo, 256);
    ExtractToken(rest, hdoc_p, hdoc_dest, 256);
    HgitHistoryDoc(hdoc_repo, hdoc_dest);
    CommPrint(1, "DISPATCH_OK historydoc\n");
  } else if (StrCmp(cmd, "reconciledoc") == 0) {
    U8 rdoc_repo[256], rdoc_hex[129], rdoc_dest[256];
    I64 rdoc_p1 = ExtractToken(rest, 0, rdoc_repo, 256);
    I64 rdoc_p2 = ExtractToken(rest, rdoc_p1, rdoc_hex, 129);
    ExtractToken(rest, rdoc_p2, rdoc_dest, 256);
    U8 rdoc_hash[64];
    if (!HexToHash(rdoc_hex, rdoc_hash)) {
      CommPrint(1, "DISPATCH_ERR reconciledoc_bad_hex\n");
    } else {
      HgitReconcileDoc(rdoc_repo, rdoc_hash, rdoc_dest);
      CommPrint(1, "DISPATCH_OK reconciledoc\n");
    }
  } else if (StrCmp(cmd, "reconcileoverview") == 0) {
    U8 rov_repo[256], rov_dest[256];
    I64 rov_p = ExtractToken(rest, 0, rov_repo, 256);
    ExtractToken(rest, rov_p, rov_dest, 256);
    HgitReconcileOverview(rov_repo, rov_dest);
    CommPrint(1, "DISPATCH_OK reconcileoverview\n");
  } else if (StrCmp(cmd, "export") == 0) {
    U8 export_src[256], export_dest[256];
    I64 export_p = ExtractToken(rest, 0, export_src, 256);
    ExtractToken(rest, export_p, export_dest, 256);
    HgitCopyRepo(export_src, export_dest);
    CommPrint(1, "DISPATCH_OK export\n");
  } else if (StrCmp(cmd, "import") == 0) {
    U8 import_src[256], import_dest[256];
    I64 import_p = ExtractToken(rest, 0, import_src, 256);
    ExtractToken(rest, import_p, import_dest, 256);
    HgitCopyRepo(import_src, import_dest);
    CommPrint(1, "DISPATCH_OK import\n");
  } else {
    CommPrint(1, "DISPATCH_ERR unknown_command %s\n", cmd);
  }
}

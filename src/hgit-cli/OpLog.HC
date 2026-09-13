// OpLog.HC — the tool-operation log, separate from project history
// (commits), per the product thesis: "Project history and tool-
// operation history are separate. Every modifying hgit command records
// an operation so ordinary recovery becomes: hgit undo / hgit redo /
// hgit operation history / hgit operation restore <operation>."
//
// Probe 44: this file's PUBLIC API (OpLogAppend/OpLogUndo/OpLogRedo/
// OpLogHistory/OpLogRestore) is now backed by `src/hgit-core/Meta.HC`'s
// operation-log slice internally, completing ADR 0003's real-command
// cutover started in probe 43 (which moved Paths.HC over the same
// way). Every function's SIGNATURE and observable behavior is
// unchanged - Offer.HC and Hgit.HC needed no changes at all. This
// retires the old `.oplog.<name>`/`.redolog.<name>` sidecar files that
// motivated ADR 0003 in the first place.
//
// All operations are scoped to whichever path is CURRENT right now
// (via Paths.HC's CurrentPathGet - reused, not reimplemented), same
// path-scoping this file already had since probe 36.
//
// Depends on Meta.HC (MetaOpLogAppend/MetaOpLogPopLast/MetaOpLogGet/
// MetaOpLogCount/MetaRedoLogAppend/MetaRedoLogPopLast/MetaRedoLogClear),
// Paths.HC (CurrentPathGet, CurrentHeadWrite, HGIT_MAX_PATH_NAME), and
// Hex.HC (HashToHex, for OpLogHistory's printable output only - kept
// out of Meta.HC itself, which shouldn't depend on hgit-cli).

// Logs a real operation (e.g. offer) for the current path. Also
// clears that path's redo log: doing new work after an undo
// invalidates whatever was undone, same as any other tool's undo/redo
// stack. Deliberately not done inside MetaOpLogAppend itself, since
// OpLogRedo (below) also calls it and must NOT clear the redo log as
// a side effect of that internal reuse.
U0 OpLogAppend(U8 *repo_path, U8 *prev_head, U8 *new_head, U64 timestamp)
{
  U8 cur_name[HGIT_MAX_PATH_NAME];
  CurrentPathGet(repo_path, cur_name);
  MetaOpLogAppend(repo_path, cur_name, prev_head, new_head, timestamp);
  MetaRedoLogClear(repo_path, cur_name);
}

// Restores HEAD to the most recently logged operation's prev_head,
// removes that entry from the undo log, and pushes it onto the redo
// log so OpLogRedo can replay it. Returns FALSE (no change made) if
// there's nothing to undo for the current path.
Bool OpLogUndo(U8 *repo_path)
{
  U8 cur_name[HGIT_MAX_PATH_NAME];
  CurrentPathGet(repo_path, cur_name);
  U8 prev_head[64], new_head[64];
  U64 ts;
  Bool found = MetaOpLogPopLast(repo_path, cur_name, prev_head, new_head, &ts);
  if (!found) return FALSE;
  CurrentHeadWrite(repo_path, prev_head);
  MetaRedoLogAppend(repo_path, cur_name, prev_head, new_head, ts);
  return TRUE;
}

// Re-applies the most recently undone operation for the current path:
// sets HEAD back to that entry's new_head, removes it from the redo
// log, and pushes it back onto the undo log. Returns FALSE if there's
// nothing to redo.
Bool OpLogRedo(U8 *repo_path)
{
  U8 cur_name[HGIT_MAX_PATH_NAME];
  CurrentPathGet(repo_path, cur_name);
  U8 prev_head[64], new_head[64];
  U64 ts;
  Bool found = MetaRedoLogPopLast(repo_path, cur_name, prev_head, new_head, &ts);
  if (!found) return FALSE;
  CurrentHeadWrite(repo_path, new_head);
  MetaOpLogAppend(repo_path, cur_name, prev_head, new_head, ts);
  return TRUE;
}

// Prints every logged operation for the current path (oldest first):
// index, timestamp, and the prev_head/new_head hashes in hex.
// Read-only - doesn't touch HEAD or either log.
U0 OpLogHistory(U8 *repo_path)
{
  U8 cur_name[HGIT_MAX_PATH_NAME];
  CurrentPathGet(repo_path, cur_name);
  I64 count = MetaOpLogCount(repo_path, cur_name);
  if (count == 0) {
    CommPrint(1, "OPLOG_EMPTY\n");
    return;
  }
  I64 i;
  for (i=0; i<count; i++) {
    U8 prev_head[64], new_head[64];
    U64 ts;
    MetaOpLogGet(repo_path, cur_name, i, prev_head, new_head, &ts);
    U8 prev_hex[129], new_hex[129];
    HashToHex(prev_head, prev_hex);
    HashToHex(new_head, new_hex);
    CommPrint(1, "OP %d ts=%d prev=%s new=%s\n", i, ts, prev_hex, new_hex);
  }
}

// Jumps the current path's HEAD directly to the `new_head` recorded
// by the operation at `index` (0-based, oldest first - same numbering
// OpLogHistory prints), regardless of how many steps away that is.
// Deliberately does not touch the undo/redo logs (see OpLog.HC's
// original design note, unchanged from probe 38): reconciling an
// arbitrary restore with undo/redo afterward is out of scope.
Bool OpLogRestore(U8 *repo_path, I64 index)
{
  U8 cur_name[HGIT_MAX_PATH_NAME];
  CurrentPathGet(repo_path, cur_name);
  U8 prev_head[64], new_head[64];
  U64 ts;
  Bool found = MetaOpLogGet(repo_path, cur_name, index, prev_head, new_head, &ts);
  if (!found) return FALSE;
  CurrentHeadWrite(repo_path, new_head);
  return TRUE;
}

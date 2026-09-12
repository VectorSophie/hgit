// OpLog.HC — the tool-operation log, separate from project history
// (commits), per the product thesis: "Project history and tool-
// operation history are separate. Every modifying hgit command records
// an operation so ordinary recovery becomes: hgit undo / hgit redo /
// hgit operation history / hgit operation restore <operation>."
//
// Undo + redo (probe 32): a `<repo_path>.redolog` sidecar, same
// 136-byte entry shape as `.oplog`, holds entries popped by undo so
// they can be replayed. `OpLogUndo` now pushes the entry it reverts
// onto the redo log before truncating the undo log; `OpLogRedo` pops
// the most recently undone entry, re-applies its `new_head`, and
// pushes it back onto the undo log — standard undo/redo-stack
// semantics. `OpLogAppend` (called by every real mutating operation,
// e.g. `offer`) clears the redo log: doing new work after an undo
// invalidates whatever was undone, same as any other tool's undo/redo.
// `hgit operation history`/`hgit operation restore <op>` are still not
// built yet.
//
// Entry format (136 bytes, both `.oplog` and `.redolog`):
//   U64 timestamp
//   64 bytes prev_head   (all-zero = "no commit existed yet")
//   64 bytes new_head
//
// The all-zero prev_head sentinel is a practical choice, not a proven
// one: a real BLAKE2b-512 hash is vanishingly unlikely to be all
// zero bytes, but this hasn't been formally ruled out or guarded
// against - flagged as a known, low-probability edge case.
//
// Verified (experiments/30-oplog-undo/): two offerings logged, then two
// successive undos correctly walk HEAD back through the second
// commit's hash, to the first commit's hash, to the all-zero
// no-commit sentinel - and a third undo correctly reports nothing left
// to undo rather than doing something wrong. Wired into Offer.HC itself
// and verified through the real Hgit(cmdline) dispatcher in
// experiments/31-oplog-in-offer/.
//
// Confirmed HolyC quirk hit while building this (not new - already in
// holyc-parser's own bug-compat corpus,
// `009-bug-compat-bug-ternary-not-supported.hc`): the `?:` ternary
// operator is not supported. Use plain if/else for conditional
// assignment.
//
// Depends on Canon.HC (PutU64LE) and Head.HC (HeadWrite).

U0 OpLogPath(U8 *repo_path, U8 *out_path)
{
  I64 i = 0;
  while (repo_path[i]) { out_path[i] = repo_path[i]; i++; }
  out_path[i++]='.'; out_path[i++]='o'; out_path[i++]='p';
  out_path[i++]='l'; out_path[i++]='o'; out_path[i++]='g';
  out_path[i] = 0;
}

U0 RedoLogPath(U8 *repo_path, U8 *out_path)
{
  I64 i = 0;
  while (repo_path[i]) { out_path[i] = repo_path[i]; i++; }
  out_path[i++]='.'; out_path[i++]='r'; out_path[i++]='e';
  out_path[i++]='d'; out_path[i++]='o'; out_path[i++]='l';
  out_path[i++]='o'; out_path[i++]='g'; out_path[i] = 0;
}

// Shared by OpLogAppend/OpLogUndo/OpLogRedo: appends one 136-byte
// entry to whichever sidecar file `path` names.
U0 OpLogAppendTo(U8 *path, U8 *prev_head, U8 *new_head, U64 timestamp)
{
  I64 old_size;
  U8 *old_buf = FileRead(path, &old_size);
  I64 total_old;
  if (old_buf==NULL) total_old = 0; else total_old = old_size;

  U8 new_buf[16384]; // fixed cap for now - ~120 entries; grow if hit
  I64 j;
  for (j=0; j<total_old; j++) new_buf[j] = old_buf[j];
  I64 pos = total_old;
  PutU64LE(new_buf, pos, timestamp); pos += 8;
  for (j=0; j<64; j++) new_buf[pos+j] = prev_head[j]; pos += 64;
  for (j=0; j<64; j++) new_buf[pos+j] = new_head[j]; pos += 64;
  FileWrite(path, new_buf, pos);
}

// Logs a real operation (e.g. offer). Also clears the redo log: doing
// new work after an undo invalidates whatever was undone, same as any
// other tool's undo/redo stack.
U0 OpLogAppend(U8 *repo_path, U8 *prev_head, U8 *new_head, U64 timestamp)
{
  U8 log_path[256];
  OpLogPath(repo_path, log_path);
  OpLogAppendTo(log_path, prev_head, new_head, timestamp);

  U8 redo_path[256];
  RedoLogPath(repo_path, redo_path);
  U8 empty[1];
  FileWrite(redo_path, empty, 0);
}

// Restores HEAD to the most recently logged operation's prev_head,
// removes that entry from the undo log, and pushes it onto the redo
// log so OpLogRedo can replay it. Returns FALSE (no change made) if
// the log is empty or missing - callers should treat that as "nothing
// to undo," not an error.
Bool OpLogUndo(U8 *repo_path)
{
  U8 log_path[256];
  OpLogPath(repo_path, log_path);
  I64 size;
  U8 *buf = FileRead(log_path, &size);
  if (buf==NULL || size < 136) return FALSE;
  I64 last_off = size - 136;
  U8 *prev_head = buf + last_off + 8;
  U8 *new_head = buf + last_off + 8 + 64;
  U64 timestamp = GetU64LE(buf, last_off);

  HeadWrite(repo_path, prev_head);

  U8 redo_path[256];
  RedoLogPath(repo_path, redo_path);
  OpLogAppendTo(redo_path, prev_head, new_head, timestamp);

  FileWrite(log_path, buf, last_off);
  return TRUE;
}

// Prints every logged operation (oldest first): index, timestamp, and
// the prev_head/new_head hashes in hex. Read-only - doesn't touch HEAD
// or either log file. Uses HashToHex (Hex.HC); depends on it and on
// OpLogPath above.
U0 OpLogHistory(U8 *repo_path)
{
  U8 log_path[256];
  OpLogPath(repo_path, log_path);
  I64 size;
  U8 *buf = FileRead(log_path, &size);
  if (buf==NULL || size < 136) {
    CommPrint(1, "OPLOG_EMPTY\n");
    return;
  }
  I64 count = size / 136;
  I64 i;
  for (i=0; i<count; i++) {
    I64 off = i*136;
    U64 ts = GetU64LE(buf, off);
    U8 prev_hex[129], new_hex[129];
    HashToHex(buf+off+8, prev_hex);
    HashToHex(buf+off+8+64, new_hex);
    CommPrint(1, "OP %d ts=%d prev=%s new=%s\n", i, ts, prev_hex, new_hex);
  }
}

// Re-applies the most recently undone operation: sets HEAD back to
// that entry's new_head, removes it from the redo log, and pushes it
// back onto the undo log. Returns FALSE if there's nothing to redo
// (redo log empty/missing, or nothing has been undone since the last
// real operation).
Bool OpLogRedo(U8 *repo_path)
{
  U8 redo_path[256];
  RedoLogPath(repo_path, redo_path);
  I64 size;
  U8 *buf = FileRead(redo_path, &size);
  if (buf==NULL || size < 136) return FALSE;
  I64 last_off = size - 136;
  U8 *prev_head = buf + last_off + 8;
  U8 *new_head = buf + last_off + 8 + 64;
  U64 timestamp = GetU64LE(buf, last_off);

  HeadWrite(repo_path, new_head);

  U8 log_path[256];
  OpLogPath(repo_path, log_path);
  OpLogAppendTo(log_path, prev_head, new_head, timestamp);

  FileWrite(redo_path, buf, last_off);
  return TRUE;
}

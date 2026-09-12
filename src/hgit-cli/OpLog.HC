// OpLog.HC — the tool-operation log, separate from project history
// (commits), per the product thesis: "Project history and tool-
// operation history are separate. Every modifying hgit command records
// an operation so ordinary recovery becomes: hgit undo / hgit redo /
// hgit operation history / hgit operation restore <operation>."
//
// This is the first, minimal slice: append an entry recording HEAD's
// before/after value on every offer, and undo the most recent one.
// `redo` and `operation history`/`operation restore <op>` are not
// built yet - this is a single-level undo (pop the last entry, revert
// HEAD, done), not a full undo/redo stack with a movable cursor.
//
// Entry format (136 bytes, sidecar file `<repo_path>.oplog`):
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
// to undo rather than doing something wrong.
//
// Confirmed HolyC quirk hit while building this (not new - already in
// holyc-parser's own bug-compat corpus,
// `009-bug-compat-bug-ternary-not-supported.hc`): the `?:` ternary
// operator is not supported. Use plain if/else for conditional
// assignment.
//
// Depends on Canon.HC (PutU64LE) and Head.HC (HeadWrite). Not yet
// wired into Offer.HC - that's the next step, not done here.

U0 OpLogPath(U8 *repo_path, U8 *out_path)
{
  I64 i = 0;
  while (repo_path[i]) { out_path[i] = repo_path[i]; i++; }
  out_path[i++]='.'; out_path[i++]='o'; out_path[i++]='p';
  out_path[i++]='l'; out_path[i++]='o'; out_path[i++]='g';
  out_path[i] = 0;
}

U0 OpLogAppend(U8 *repo_path, U8 *prev_head, U8 *new_head, U64 timestamp)
{
  U8 log_path[256];
  OpLogPath(repo_path, log_path);
  I64 old_size;
  U8 *old_buf = FileRead(log_path, &old_size);
  I64 total_old;
  if (old_buf==NULL) total_old = 0; else total_old = old_size;

  U8 new_buf[16384]; // fixed cap for now - ~120 entries; grow if hit
  I64 j;
  for (j=0; j<total_old; j++) new_buf[j] = old_buf[j];
  I64 pos = total_old;
  PutU64LE(new_buf, pos, timestamp); pos += 8;
  for (j=0; j<64; j++) new_buf[pos+j] = prev_head[j]; pos += 64;
  for (j=0; j<64; j++) new_buf[pos+j] = new_head[j]; pos += 64;
  FileWrite(log_path, new_buf, pos);
}

// Restores HEAD to the most recently logged operation's prev_head and
// removes that entry from the log. Returns FALSE (no change made) if
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
  HeadWrite(repo_path, prev_head);
  FileWrite(log_path, buf, last_off);
  return TRUE;
}

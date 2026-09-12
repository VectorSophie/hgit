// Paths.HC — named paths (hgit's branch equivalent), per the brief's
// `hgit path list/new/go/close` vocabulary.
//
// Deliberately minimal, first slice: path bookkeeping only (create,
// list, switch "current path," close) — NOT yet wired into
// Offer.HC/Status.HC/History.HC/See.HC/OpLog.HC, so creating or
// switching paths doesn't yet change what those commands operate on.
// That's the natural next step, not done here — same pattern this
// project already used for OpLog.HC (built and verified standalone in
// probe 30, wired into Offer.HC in probe 31).
//
// Design:
//   - "main" is the implicit default path — it always exists, is never
//     stored in the path list, and its HEAD is exactly `<repo_path>.head`
//     (byte-identical location to every already-verified probe, so this
//     adds nothing new for repos that never touch paths).
//   - `<repo_path>.paths`: every OTHER path's name, as a flat list of
//     [U8 name_len][name bytes] entries, read until EOF. No count
//     prefix — same "read until end of buffer" pattern as OpLog.HC's
//     fixed-size entries, just variable-length here.
//   - `<repo_path>.currentpath`: raw bytes = the current path's name
//     (no NUL terminator, no length prefix). Missing/empty means "main".
//   - `<repo_path>.head.<name>`: HEAD storage for any non-main path
//     (same 64-byte format as Head.HC's `.head` file).
//
// Depends on Head.HC (HeadRead/HeadWrite, for the "main" case) and
// Canon.HC only for the general style; no BLAKE2b/object-layer
// dependency, this is pure bookkeeping.

#define HGIT_MAX_PATH_NAME 64

U0 PathListFilePath(U8 *repo_path, U8 *out_path)
{
  I64 i = 0;
  while (repo_path[i]) { out_path[i] = repo_path[i]; i++; }
  out_path[i++]='.'; out_path[i++]='p'; out_path[i++]='a';
  out_path[i++]='t'; out_path[i++]='h'; out_path[i++]='s';
  out_path[i] = 0;
}

U0 CurrentPathFilePath(U8 *repo_path, U8 *out_path)
{
  I64 i = 0;
  while (repo_path[i]) { out_path[i] = repo_path[i]; i++; }
  out_path[i++]='.'; out_path[i++]='c'; out_path[i++]='u';
  out_path[i++]='r'; out_path[i++]='r'; out_path[i++]='e';
  out_path[i++]='n'; out_path[i++]='t'; out_path[i++]='p';
  out_path[i++]='a'; out_path[i++]='t'; out_path[i++]='h';
  out_path[i] = 0;
}

// HEAD storage location for `name` under this repo. "main" reuses
// Head.HC's own `<repo_path>.head` unchanged; anything else gets its
// own `<repo_path>.head.<name>` sidecar.
U0 PathHeadFilePath(U8 *repo_path, U8 *name, U8 *out_path)
{
  if (StrCmp(name, "main") == 0) {
    HeadPath(repo_path, out_path);
    return;
  }
  U8 base[256];
  HeadPath(repo_path, base); // "<repo_path>.head"
  I64 i = 0;
  while (base[i]) { out_path[i] = base[i]; i++; }
  out_path[i++] = '.';
  I64 j = 0;
  while (name[j]) { out_path[i++] = name[j]; j++; }
  out_path[i] = 0;
}

// Writes out_name = the current path's name (defaults to "main" if the
// `.currentpath` sidecar is missing or empty).
U0 CurrentPathGet(U8 *repo_path, U8 *out_name)
{
  U8 cp_path[256];
  CurrentPathFilePath(repo_path, cp_path);
  I64 size;
  U8 *buf = FileRead(cp_path, &size);
  if (buf == NULL || size <= 0) {
    out_name[0]='m'; out_name[1]='a'; out_name[2]='i'; out_name[3]='n'; out_name[4]=0;
    return;
  }
  I64 i;
  for (i=0; i<size && i<HGIT_MAX_PATH_NAME-1; i++) out_name[i] = buf[i];
  out_name[i] = 0;
}

// TRUE if `name` is "main" or already appears in the path list.
Bool PathExists(U8 *repo_path, U8 *name)
{
  if (StrCmp(name, "main") == 0) return TRUE;
  U8 list_path[256];
  PathListFilePath(repo_path, list_path);
  I64 size;
  U8 *buf = FileRead(list_path, &size);
  if (buf == NULL) return FALSE;
  I64 target_len = StrLen(name);
  I64 pos = 0;
  while (pos < size) {
    U8 name_len = buf[pos]; pos += 1;
    Bool same = (name_len == target_len);
    I64 i;
    if (same) for (i=0; i<name_len; i++) if (name[i] != buf[pos+i]) same = FALSE;
    pos += name_len;
    if (same) return TRUE;
  }
  return FALSE;
}

// Prints every path name, "main" first, then each entry in the path
// list file (creation order).
U0 PathListPrint(U8 *repo_path)
{
  CommPrint(1, "PATH main\n");
  U8 list_path[256];
  PathListFilePath(repo_path, list_path);
  I64 size;
  U8 *buf = FileRead(list_path, &size);
  if (buf == NULL) return;
  I64 pos = 0;
  while (pos < size) {
    U8 name_len = buf[pos]; pos += 1;
    U8 name[HGIT_MAX_PATH_NAME];
    I64 i;
    for (i=0; i<name_len; i++) name[i] = buf[pos+i];
    name[name_len] = 0;
    pos += name_len;
    CommPrint(1, "PATH %s\n", name);
  }
}

// Creates a new path named `name`, pointing its HEAD at whatever the
// CURRENT path's HEAD is right now (all-zero if the current path has
// no offerings yet). Returns FALSE if `name` already exists (including
// "main", which can't be recreated) or is too long.
Bool PathNew(U8 *repo_path, U8 *name)
{
  I64 name_len = StrLen(name);
  if (name_len <= 0 || name_len >= HGIT_MAX_PATH_NAME) return FALSE;
  if (PathExists(repo_path, name)) return FALSE;

  U8 cur_name[HGIT_MAX_PATH_NAME];
  CurrentPathGet(repo_path, cur_name);
  U8 cur_head_path[256];
  PathHeadFilePath(repo_path, cur_name, cur_head_path);
  I64 cur_size;
  U8 *cur_buf = FileRead(cur_head_path, &cur_size);
  U8 head[64];
  I64 i;
  if (cur_buf != NULL && cur_size == 64) {
    for (i=0; i<64; i++) head[i] = cur_buf[i];
  } else {
    for (i=0; i<64; i++) head[i] = 0;
  }

  U8 new_head_path[256];
  PathHeadFilePath(repo_path, name, new_head_path);
  FileWrite(new_head_path, head, 64);

  // Append to the path list.
  U8 list_path[256];
  PathListFilePath(repo_path, list_path);
  I64 old_size;
  U8 *old_buf = FileRead(list_path, &old_size);
  I64 total_old;
  if (old_buf == NULL) total_old = 0; else total_old = old_size;
  U8 new_buf[4096];
  I64 j;
  for (j=0; j<total_old; j++) new_buf[j] = old_buf[j];
  I64 pos = total_old;
  new_buf[pos] = name_len; pos += 1;
  for (j=0; j<name_len; j++) new_buf[pos+j] = name[j];
  pos += name_len;
  FileWrite(list_path, new_buf, pos);
  return TRUE;
}

// Switches the current path to `name`. Returns FALSE if `name` doesn't
// exist (callers should create it with PathNew first).
Bool PathGo(U8 *repo_path, U8 *name)
{
  if (!PathExists(repo_path, name)) return FALSE;
  U8 cp_path[256];
  CurrentPathFilePath(repo_path, cp_path);
  FileWrite(cp_path, name, StrLen(name));
  return TRUE;
}

// Reads HEAD for whichever path is CURRENT right now (same
// TRUE/FALSE-if-no-offerings-yet convention as Head.HC's HeadRead).
// This is the first thing that makes `path go` actually mean
// something: everything that used to call HeadRead(repo_path, ...)
// directly only ever saw "main"'s HEAD regardless of current path.
Bool CurrentHeadRead(U8 *repo_path, U8 *hash_out)
{
  U8 cur_name[HGIT_MAX_PATH_NAME];
  CurrentPathGet(repo_path, cur_name);
  U8 hp[256];
  PathHeadFilePath(repo_path, cur_name, hp);
  I64 size;
  U8 *buf = FileRead(hp, &size);
  if (buf == NULL || size != 64) return FALSE;
  I64 i;
  for (i=0; i<64; i++) hash_out[i] = buf[i];
  return TRUE;
}

// Writes HEAD for whichever path is CURRENT right now.
U0 CurrentHeadWrite(U8 *repo_path, U8 *hash)
{
  U8 cur_name[HGIT_MAX_PATH_NAME];
  CurrentPathGet(repo_path, cur_name);
  U8 hp[256];
  PathHeadFilePath(repo_path, cur_name, hp);
  FileWrite(hp, hash, 64);
}

// Removes `name` from the path list (its .head.<name> sidecar is left
// on disk, orphaned but unreachable through this API — not deleted;
// TempleOS's Del() exists but deleting it isn't exercised here, kept
// out of scope for this probe). If the closed path was current,
// switches current back to "main". Refuses to close "main" itself.
Bool PathClose(U8 *repo_path, U8 *name)
{
  if (StrCmp(name, "main") == 0) return FALSE;
  U8 list_path[256];
  PathListFilePath(repo_path, list_path);
  I64 size;
  U8 *buf = FileRead(list_path, &size);
  if (buf == NULL) return FALSE;

  U8 new_buf[4096];
  I64 new_len = 0, pos = 0;
  Bool found = FALSE;
  I64 name_len_target = StrLen(name);
  while (pos < size) {
    U8 name_len = buf[pos];
    I64 entry_start = pos;
    pos += 1;
    Bool same = (name_len == name_len_target);
    I64 i;
    if (same) for (i=0; i<name_len; i++) if (buf[pos+i] != name[i]) same = FALSE;
    pos += name_len;
    if (same) {
      found = TRUE;
    } else {
      I64 entry_len = pos - entry_start;
      for (i=0; i<entry_len; i++) new_buf[new_len+i] = buf[entry_start+i];
      new_len += entry_len;
    }
  }
  if (!found) return FALSE;
  FileWrite(list_path, new_buf, new_len);

  U8 cur_name[HGIT_MAX_PATH_NAME];
  CurrentPathGet(repo_path, cur_name);
  if (StrCmp(cur_name, name) == 0) {
    U8 cp_path[256];
    CurrentPathFilePath(repo_path, cp_path);
    U8 main_name[8]; main_name[0]='m';main_name[1]='a';main_name[2]='i';main_name[3]='n';main_name[4]=0;
    FileWrite(cp_path, main_name, 4);
  }
  return TRUE;
}

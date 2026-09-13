// Meta.HC — the combined per-repo metadata file, per ADR 0003
// (docs/adr/0003-path-length-ceiling.md).
//
// Real TempleOS/RedSea constraint found in probe 36
// (experiments/36-path-scoped-oplog/): a full path string longer than
// 33 characters is silently rejected by FileWrite/FileRead - no error,
// the call just no-ops. Every sidecar-file-per-concern this project
// built before this (Head.HC's `.head.<name>`, Paths.HC's `.paths`/
// `.currentpath`, OpLog.HC's `.ol.<name>`/`.rl.<name>`) grows its own
// filename with the path name, shrinking the safe budget every time a
// new per-path concern is added.
//
// One combined file per repo, `<repo_path>.m` - a single short, FIXED
// suffix that never grows no matter how many paths exist or how long
// their names are, because path names live INSIDE the file's own
// structure as data, not in filenames as identity.
//
// Probe 40 built and verified the HEAD-storage slice alone
// (MetaReadHead/MetaWriteHead). Probe 41 added path declaration/listing
// (MetaPathExists/MetaPathDeclare/MetaPathList) and the current-path
// pointer (MetaCurrentGet/MetaCurrentSet). Probe 42 adds the operation
// log (MetaOpLogAppend/MetaOpLogPopLast) - now every concern
// Paths.HC's and OpLog.HC's sidecar files used to hold lives in this
// one file too. Deliberately NOT yet wired in: Head.HC/Paths.HC/
// OpLog.HC and every real hgit command still use today's separate-
// sidecar-file layout - same incremental pattern this project already
// used for OpLog.HC itself (built standalone in probe 30, wired into
// Offer.HC in probe 31).
//
// Depends on Canon.HC (PutU64LE/GetU64LE, for the operation-log entry
// slice only) - load it first.
//
// Record format (flat, read-until-EOF, same style as Paths.HC's
// `.paths` file):
//   U8  name_len     (0 for a "global," not-per-path record, e.g. the
//                      current-path pointer)
//   name_len bytes of path name
//   U8  tag
//   U8  payload_len
//   payload_len bytes of payload
//
// Tags:
//   META_TAG_HEAD          - payload is the path's 64-byte HEAD hash
//   META_TAG_PATH_DECLARED - marks a (non-"main") path name as
//                            existing; payload_len 0, no payload -
//                            the record's own name IS the data
//   META_TAG_CURRENT       - name_len 0 (global); payload is the
//                            current path's name bytes
//
// Every "set" operation splices out any existing record for the same
// (name, tag) before appending the new one (MetaSpliceOut) - so each
// (name, tag) pair has at most one record at a time, not an
// ever-growing history. MetaFind (last-match-wins scan) and
// MetaAppendRecord are the two shared primitives every public
// function below is built from.

#define META_TAG_HEAD 1
#define META_TAG_PATH_DECLARED 2
#define META_TAG_CURRENT 3

// Kept self-contained (hgit-core shouldn't depend on hgit-cli's
// Paths.HC) even though it matches Paths.HC's own HGIT_MAX_PATH_NAME.
#define META_MAX_PATH_NAME 64

// Real bug found and fixed (experiments/66-meta-dynamic-buffer/): every
// write function below used to rebuild the whole metadata file into a
// fixed `U8 new_buf[16384]` stack buffer before writing it back - the
// exact same class of bug ADR 0007 fixed in Offer.HC's `archive`, but
// worse here: it did NOT crash. A real 150-offer stress test grew this
// file past 16384 bytes (~144 bytes/offer - one HEAD record replace
// plus one oplog append) with zero error or crash, and silently lost
// data instead: only 115 of 150 real operation-log entries survived,
// and HEAD silently stopped advancing partway through, both without
// any error signal at all. `new_buf` is now `MAlloc`'d from the
// existing file's real size (already known from `FileRead`) plus this
// headroom for the one new record being written, freed on every exit
// path. A repo that behaves this way (writes silently stop taking
// effect, no error) is a much worse failure mode than probes 55/60/61's
// own crashes - a crash is at least visible.
#define META_BUF_HEADROOM 1024

U0 MetaPath(U8 *repo_path, U8 *out_path)
{
  I64 i = 0;
  while (repo_path[i]) { out_path[i] = repo_path[i]; i++; }
  out_path[i++] = '.'; out_path[i++] = 'm';
  out_path[i] = 0;
}

// Scans buf (size bytes) for the LAST record matching (name, tag).
// Returns the payload's byte OFFSET within buf (so the caller computes
// `buf + offset` itself - avoids a pointer-to-pointer out-parameter,
// a syntax shape not used/verified anywhere else in this project) and
// sets *payload_len_out to its length. Returns -1 (payload_len_out
// untouched) if nothing matches.
I64 MetaFind(U8 *buf, I64 size, U8 *name, U8 tag, I64 *payload_len_out)
{
  I64 target_len = StrLen(name);
  I64 pos = 0;
  I64 found_off = -1;
  while (pos < size) {
    U8 name_len = buf[pos]; pos += 1;
    U8 *rec_name = buf + pos; pos += name_len;
    U8 rtag = buf[pos]; pos += 1;
    U8 payload_len = buf[pos]; pos += 1;
    I64 payload_off = pos; pos += payload_len;

    if (rtag == tag && name_len == target_len) {
      Bool same = TRUE;
      I64 fi;
      for (fi=0; fi<name_len; fi++) if (rec_name[fi] != name[fi]) same = FALSE;
      if (same) {
        found_off = payload_off;
        *payload_len_out = payload_len;
        // keep scanning - last match wins (splice-on-write should
        // keep this to one, but cheap insurance against a stale dup).
      }
    }
  }
  return found_off;
}

// Copies every record from buf (size bytes) EXCEPT ones matching
// (name, tag) into out_buf. Sets *out_len to the copied length.
U0 MetaSpliceOut(U8 *buf, I64 size, U8 *name, U8 tag, U8 *out_buf, I64 *out_len)
{
  I64 target_len = StrLen(name);
  I64 pos = 0, new_len = 0;
  while (pos < size) {
    I64 entry_start = pos;
    U8 name_len = buf[pos]; pos += 1;
    U8 *rec_name = buf + pos; pos += name_len;
    U8 rtag = buf[pos]; pos += 1;
    U8 payload_len = buf[pos]; pos += 1;
    pos += payload_len;

    Bool is_match = FALSE;
    if (rtag == tag && name_len == target_len) {
      Bool same = TRUE;
      I64 si;
      for (si=0; si<name_len; si++) if (rec_name[si] != name[si]) same = FALSE;
      is_match = same;
    }
    if (!is_match) {
      I64 entry_len = pos - entry_start;
      I64 ci;
      for (ci=0; ci<entry_len; ci++) out_buf[new_len+ci] = buf[entry_start+ci];
      new_len += entry_len;
    }
  }
  *out_len = new_len;
}

// Appends one record (name, tag, payload) to buf at *len, advancing it.
U0 MetaAppendRecord(U8 *buf, I64 *len, U8 *name, U8 tag, U8 *payload, U8 payload_len)
{
  I64 name_len = StrLen(name);
  I64 pos = *len;
  buf[pos] = name_len; pos += 1;
  I64 ai;
  for (ai=0; ai<name_len; ai++) buf[pos+ai] = name[ai];
  pos += name_len;
  buf[pos] = tag; pos += 1;
  buf[pos] = payload_len; pos += 1;
  for (ai=0; ai<payload_len; ai++) buf[pos+ai] = payload[ai];
  pos += payload_len;
  *len = pos;
}

// Reads the current HEAD hash (64 bytes) recorded for path `name`.
// Returns FALSE if no such record exists yet (same convention as
// Head.HC's HeadRead/Paths.HC's CurrentHeadRead).
Bool MetaReadHead(U8 *repo_path, U8 *name, U8 *hash_out)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  if (buf == NULL) return FALSE;

  I64 payload_len;
  I64 payload_off = MetaFind(buf, size, name, META_TAG_HEAD, &payload_len);
  if (payload_off < 0) return FALSE;
  I64 i;
  for (i=0; i<64; i++) hash_out[i] = buf[payload_off+i];
  return TRUE;
}

// Sets path `name`'s HEAD to `hash` (64 bytes), replacing any existing
// HEAD record for that name.
U0 MetaWriteHead(U8 *repo_path, U8 *name, U8 *hash)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  I64 total_old;
  if (buf == NULL) total_old = 0; else total_old = size;

  U8 *new_buf = MAlloc(total_old + META_BUF_HEADROOM);
  I64 new_len;
  MetaSpliceOut(buf, total_old, name, META_TAG_HEAD, new_buf, &new_len);
  MetaAppendRecord(new_buf, &new_len, name, META_TAG_HEAD, hash, 64);
  FileWrite(meta_path, new_buf, new_len);
  Free(new_buf);
}

// TRUE if `name` is "main" (always exists, never stored) or has a
// META_TAG_PATH_DECLARED record.
Bool MetaPathExists(U8 *repo_path, U8 *name)
{
  if (StrCmp(name, "main") == 0) return TRUE;
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  if (buf == NULL) return FALSE;
  I64 payload_len;
  return MetaFind(buf, size, name, META_TAG_PATH_DECLARED, &payload_len) >= 0;
}

// Declares `name` as an existing path (idempotent - does nothing if
// already declared or if `name` is "main").
U0 MetaPathDeclare(U8 *repo_path, U8 *name)
{
  if (MetaPathExists(repo_path, name)) return;
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  I64 total_old;
  if (buf == NULL) total_old = 0; else total_old = size;

  U8 *new_buf = MAlloc(total_old + META_BUF_HEADROOM);
  I64 new_len = 0;
  I64 i;
  for (i=0; i<total_old; i++) new_buf[i] = buf[i];
  new_len = total_old;
  U8 no_payload[1];
  MetaAppendRecord(new_buf, &new_len, name, META_TAG_PATH_DECLARED, no_payload, 0);
  FileWrite(meta_path, new_buf, new_len);
  Free(new_buf);
}

// Un-declares `name` (removes its META_TAG_PATH_DECLARED record, if
// any). Does nothing for "main" (can never be undeclared) or a name
// that was never declared. Does NOT touch its HEAD or operation-log
// records - those become orphaned but unreachable via
// MetaPathExists/MetaPathList, the same "left behind, not deleted"
// choice Paths.HC's original PathClose made for its own sidecar files.
U0 MetaPathUndeclare(U8 *repo_path, U8 *name)
{
  if (StrCmp(name, "main") == 0) return;
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  if (buf == NULL) return;
  U8 *new_buf = MAlloc(size + META_BUF_HEADROOM);
  I64 new_len;
  MetaSpliceOut(buf, size, name, META_TAG_PATH_DECLARED, new_buf, &new_len);
  FileWrite(meta_path, new_buf, new_len);
  Free(new_buf);
}

// Prints every path name, "main" first, then each META_TAG_PATH_DECLARED
// record found (creation order).
U0 MetaPathList(U8 *repo_path)
{
  CommPrint(1, "PATH main\n");
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  if (buf == NULL) return;
  I64 pos = 0;
  while (pos < size) {
    U8 name_len = buf[pos]; pos += 1;
    U8 *rec_name = buf + pos; pos += name_len;
    U8 rec_tag = buf[pos]; pos += 1;
    U8 payload_len = buf[pos]; pos += 1;
    pos += payload_len;
    if (rec_tag == META_TAG_PATH_DECLARED) {
      U8 name_buf[META_MAX_PATH_NAME];
      I64 ni; // NOT "pi" - TempleOS predefines that as the F64 constant
               // pi (confirmed, probe 41): a local var named pi produces
               // a cryptic "Expecting '*' at INT:400921FB54442D18 (F64)"
               // parse error (that hex IS pi's IEEE754 bit pattern).
      for (ni=0; ni<name_len; ni++) name_buf[ni] = rec_name[ni];
      name_buf[name_len] = 0;
      CommPrint(1, "PATH %s\n", name_buf);
    }
  }
}

// Writes out_name = the current path's name (defaults to "main" if no
// META_TAG_CURRENT record exists yet - same convention as Paths.HC's
// CurrentPathGet).
U0 MetaCurrentGet(U8 *repo_path, U8 *out_name)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  I64 payload_len;
  I64 payload_off = -1;
  if (buf != NULL) payload_off = MetaFind(buf, size, "", META_TAG_CURRENT, &payload_len);
  if (payload_off < 0) {
    out_name[0]='m'; out_name[1]='a'; out_name[2]='i'; out_name[3]='n'; out_name[4]=0;
    return;
  }
  I64 i;
  for (i=0; i<payload_len; i++) out_name[i] = buf[payload_off+i];
  out_name[payload_len] = 0;
}

// Sets the current path to `name`, replacing any existing
// META_TAG_CURRENT record.
U0 MetaCurrentSet(U8 *repo_path, U8 *name)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  I64 total_old;
  if (buf == NULL) total_old = 0; else total_old = size;

  U8 *new_buf = MAlloc(total_old + META_BUF_HEADROOM);
  I64 new_len;
  MetaSpliceOut(buf, total_old, "", META_TAG_CURRENT, new_buf, &new_len);
  MetaAppendRecord(new_buf, &new_len, "", META_TAG_CURRENT, name, StrLen(name));
  FileWrite(meta_path, new_buf, new_len);
  Free(new_buf);
}

// --- Operation log (probe 42) ---
//
// Unlike HEAD/CURRENT (one record per name, replaced on every write),
// operation-log entries for a path ACCUMULATE - each real operation
// (e.g. an offer) appends one, and undo pops the most recently
// appended one. This needs a different removal primitive from
// MetaSpliceOut (which strips EVERY matching record): MetaSpliceOutLast
// finds and removes only the LAST matching record, leaving earlier
// same-(name,tag) entries alone. Each entry is 136 bytes, the same
// shape OpLog.HC's sidecar-file version already uses and verified
// (probe 30): U64 timestamp + 64-byte prev_head + 64-byte new_head.

#define META_TAG_OPLOG 4

// Finds the LAST record matching (name, tag), copies its payload into
// payload_out (caller-sized buffer) and its length into
// *payload_len_out, and writes every OTHER record (including earlier
// same-name/tag ones) into out_buf/*out_len - i.e. removes exactly one
// occurrence, not all of them. Returns FALSE (out_buf just a copy of
// buf, payload_out untouched) if no match exists.
Bool MetaSpliceOutLast(U8 *buf, I64 size, U8 *name, U8 tag,
                        U8 *out_buf, I64 *out_len,
                        U8 *payload_out, I64 *payload_len_out)
{
  I64 target_len = StrLen(name);
  I64 pos = 0;
  I64 match_start = -1, match_end = -1, match_payload_off = -1, match_payload_len = 0;
  while (pos < size) {
    I64 entry_start = pos;
    U8 name_len = buf[pos]; pos += 1;
    U8 *rec_name = buf + pos; pos += name_len;
    U8 rtag = buf[pos]; pos += 1;
    U8 payload_len = buf[pos]; pos += 1;
    I64 payload_off = pos; pos += payload_len;

    if (rtag == tag && name_len == target_len) {
      Bool same = TRUE;
      I64 li;
      for (li=0; li<name_len; li++) if (rec_name[li] != name[li]) same = FALSE;
      if (same) {
        match_start = entry_start;
        match_end = pos;
        match_payload_off = payload_off;
        match_payload_len = payload_len;
      }
    }
  }
  if (match_start < 0) {
    I64 zi;
    for (zi=0; zi<size; zi++) out_buf[zi] = buf[zi];
    *out_len = size;
    return FALSE;
  }
  I64 pli;
  for (pli=0; pli<match_payload_len; pli++) payload_out[pli] = buf[match_payload_off+pli];
  *payload_len_out = match_payload_len;

  I64 new_len = 0, ci;
  for (ci=0; ci<match_start; ci++) out_buf[new_len++] = buf[ci];
  for (ci=match_end; ci<size; ci++) out_buf[new_len++] = buf[ci];
  *out_len = new_len;
  return TRUE;
}

// Appends one 136-byte operation-log entry for path `name`.
U0 MetaOpLogAppend(U8 *repo_path, U8 *name, U8 *prev_head, U8 *new_head, U64 timestamp)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  I64 total_old;
  if (buf == NULL) total_old = 0; else total_old = size;

  U8 payload[136];
  PutU64LE(payload, 0, timestamp);
  I64 bi;
  for (bi=0; bi<64; bi++) payload[8+bi] = prev_head[bi];
  for (bi=0; bi<64; bi++) payload[72+bi] = new_head[bi];

  U8 *new_buf = MAlloc(total_old + META_BUF_HEADROOM);
  I64 new_len = 0;
  for (bi=0; bi<total_old; bi++) new_buf[bi] = buf[bi];
  new_len = total_old;
  MetaAppendRecord(new_buf, &new_len, name, META_TAG_OPLOG, payload, 136);
  FileWrite(meta_path, new_buf, new_len);
  Free(new_buf);
}

// Pops the most recently appended operation-log entry for path `name`:
// removes it and returns its prev_head/new_head/timestamp. Returns
// FALSE (outputs untouched) if there's nothing to pop.
Bool MetaOpLogPopLast(U8 *repo_path, U8 *name, U8 *prev_head_out, U8 *new_head_out, U64 *timestamp_out)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  if (buf == NULL) return FALSE;

  U8 *new_buf = MAlloc(size + META_BUF_HEADROOM);
  I64 new_len;
  U8 payload[136];
  I64 payload_len;
  Bool found = MetaSpliceOutLast(buf, size, name, META_TAG_OPLOG, new_buf, &new_len, payload, &payload_len);
  if (!found) { Free(new_buf); return FALSE; }

  *timestamp_out = GetU64LE(payload, 0);
  I64 bi;
  for (bi=0; bi<64; bi++) prev_head_out[bi] = payload[8+bi];
  for (bi=0; bi<64; bi++) new_head_out[bi] = payload[72+bi];

  FileWrite(meta_path, new_buf, new_len);
  Free(new_buf);
  return TRUE;
}

// Returns TRUE and fills prev/new/timestamp for the entry at `index`
// (0-based, oldest first) among path `name`'s operation-log entries.
// FALSE if out of range. Read-only. Deliberately returns raw fields,
// not a printable string - hgit-core (this file) shouldn't depend on
// hgit-cli's hex-conversion helpers; callers building a human-readable
// listing do that themselves (see OpLog.HC's OpLogHistory).
Bool MetaOpLogGet(U8 *repo_path, U8 *name, I64 index, U8 *prev_out, U8 *new_out, U64 *timestamp_out)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  if (buf == NULL) return FALSE;
  I64 target_len = StrLen(name);
  I64 pos = 0, idx = 0;
  while (pos < size) {
    U8 name_len = buf[pos]; pos += 1;
    U8 *rec_name = buf + pos; pos += name_len;
    U8 tag = buf[pos]; pos += 1;
    U8 payload_len = buf[pos]; pos += 1;
    I64 payload_off = pos; pos += payload_len;
    if (tag == META_TAG_OPLOG && name_len == target_len) {
      Bool same = TRUE;
      I64 gi;
      for (gi=0; gi<name_len; gi++) if (rec_name[gi] != name[gi]) same = FALSE;
      if (same) {
        if (idx == index) {
          *timestamp_out = GetU64LE(buf, payload_off);
          I64 bi;
          for (bi=0; bi<64; bi++) prev_out[bi] = buf[payload_off+8+bi];
          for (bi=0; bi<64; bi++) new_out[bi] = buf[payload_off+72+bi];
          return TRUE;
        }
        idx++;
      }
    }
  }
  return FALSE;
}

// Count of operation-log entries for path `name`.
I64 MetaOpLogCount(U8 *repo_path, U8 *name)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  if (buf == NULL) return 0;
  I64 target_len = StrLen(name);
  I64 pos = 0, count = 0;
  while (pos < size) {
    U8 name_len = buf[pos]; pos += 1;
    U8 *rec_name = buf + pos; pos += name_len;
    U8 tag = buf[pos]; pos += 1;
    U8 payload_len = buf[pos]; pos += 1;
    pos += payload_len;
    if (tag == META_TAG_OPLOG && name_len == target_len) {
      Bool same = TRUE;
      I64 ki;
      for (ki=0; ki<name_len; ki++) if (rec_name[ki] != name[ki]) same = FALSE;
      if (same) count++;
    }
  }
  return count;
}

// --- Redo log: same accumulate/pop-last shape as the operation log
// above, kept as a separate tag rather than reusing META_TAG_OPLOG so
// the two never collide when scanned. OpLog.HC's own OpLogAppend is
// responsible for calling MetaRedoLogClear (a real new operation
// invalidates whatever was undone) - deliberately NOT done
// automatically inside MetaOpLogAppend itself, since OpLogRedo also
// calls MetaOpLogAppend (to push a redone entry back onto the undo
// log) and must NOT clear the remaining redo log as a side effect of
// that internal reuse.

#define META_TAG_REDOLOG 5

U0 MetaRedoLogAppend(U8 *repo_path, U8 *name, U8 *prev_head, U8 *new_head, U64 timestamp)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  I64 total_old;
  if (buf == NULL) total_old = 0; else total_old = size;

  U8 payload[136];
  PutU64LE(payload, 0, timestamp);
  I64 bi;
  for (bi=0; bi<64; bi++) payload[8+bi] = prev_head[bi];
  for (bi=0; bi<64; bi++) payload[72+bi] = new_head[bi];

  U8 *new_buf = MAlloc(total_old + META_BUF_HEADROOM);
  I64 new_len = 0;
  for (bi=0; bi<total_old; bi++) new_buf[bi] = buf[bi];
  new_len = total_old;
  MetaAppendRecord(new_buf, &new_len, name, META_TAG_REDOLOG, payload, 136);
  FileWrite(meta_path, new_buf, new_len);
  Free(new_buf);
}

Bool MetaRedoLogPopLast(U8 *repo_path, U8 *name, U8 *prev_head_out, U8 *new_head_out, U64 *timestamp_out)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  if (buf == NULL) return FALSE;

  U8 *new_buf = MAlloc(size + META_BUF_HEADROOM);
  I64 new_len;
  U8 payload[136];
  I64 payload_len;
  Bool found = MetaSpliceOutLast(buf, size, name, META_TAG_REDOLOG, new_buf, &new_len, payload, &payload_len);
  if (!found) { Free(new_buf); return FALSE; }

  *timestamp_out = GetU64LE(payload, 0);
  I64 bi;
  for (bi=0; bi<64; bi++) prev_head_out[bi] = payload[8+bi];
  for (bi=0; bi<64; bi++) new_head_out[bi] = payload[72+bi];

  FileWrite(meta_path, new_buf, new_len);
  Free(new_buf);
  return TRUE;
}

// Clears every redo-log entry for path `name` (standard undo/redo
// semantics: a real new operation invalidates whatever was undone).
U0 MetaRedoLogClear(U8 *repo_path, U8 *name)
{
  U8 meta_path[256];
  MetaPath(repo_path, meta_path);
  I64 size;
  U8 *buf = FileRead(meta_path, &size);
  if (buf == NULL) return;
  U8 *new_buf = MAlloc(size + META_BUF_HEADROOM);
  I64 new_len;
  MetaSpliceOut(buf, size, name, META_TAG_REDOLOG, new_buf, &new_len);
  FileWrite(meta_path, new_buf, new_len);
  Free(new_buf);
}

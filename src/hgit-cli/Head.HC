// Head.HC — the "current offering" pointer: hgit's minimal ref/HEAD
// equivalent, unblocking `status`/`offer`/`history` against a real
// prior commit rather than only the empty-repo case (probe 16).
//
// Deliberately minimal for M1: ONE pointer per repository, no named
// paths/branches yet (the brief's `hgit path` commands are explicitly
// M2 work - "paths" - not built here; a single implicit path is enough
// to make `offer`/`history` meaningful). Stored as a sidecar file next
// to the repo (`<repo_path>.head`, exactly 64 bytes: the latest
// commit's hash) rather than inside the `.HGS` file itself - the .HGS
// header's own reserved field is only 2 bytes, nowhere near enough for
// a 64-byte hash, and keeping it as a separate small file means it can
// use plain FileWrite/FileRead with no changes to the archive format.
//
// Verified (experiments/17-head-pointer/): absent on a fresh repo
// (correctly reports "no offerings yet" via HeadRead returning FALSE,
// same NULL-means-absent convention as HgitInit/HgitStatus), settable,
// and independently re-settable to a second value (confirms it's a
// real mutable pointer, not a write-once accident).
//
// Depends only on kernel FileRead/FileWrite - no hgit-core dependency,
// since it doesn't touch the .HGS format itself.

U0 HeadPath(U8 *repo_path, U8 *out_path)
{
  I64 i = 0;
  while (repo_path[i]) { out_path[i] = repo_path[i]; i++; }
  out_path[i++]='.'; out_path[i++]='h'; out_path[i++]='e';
  out_path[i++]='a'; out_path[i++]='d'; out_path[i]=0;
}

// Returns TRUE and fills hash_out (64 bytes) if the repo has a current
// offering; FALSE (hash_out untouched) if it doesn't yet.
Bool HeadRead(U8 *repo_path, U8 *hash_out)
{
  U8 hp[256];
  HeadPath(repo_path, hp);
  I64 size;
  U8 *buf = FileRead(hp, &size);
  if (buf == NULL || size != 64) return FALSE;
  I64 i;
  for (i=0; i<64; i++) hash_out[i] = buf[i];
  return TRUE;
}

// Sets the repo's current offering to `hash` (64 bytes), overwriting
// any previous value.
U0 HeadWrite(U8 *repo_path, U8 *hash)
{
  U8 hp[256];
  HeadPath(repo_path, hp);
  FileWrite(hp, hash, 64);
}

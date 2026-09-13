// Paths.HC — named paths (hgit's branch equivalent), per the brief's
// `hgit path list/new/go/close` vocabulary. Design decisions written
// up retroactively in `docs/adr/0012-named-paths.md`.
//
// Probe 43: this file's PUBLIC API (CurrentPathGet/PathExists/
// PathListPrint/PathNew/PathGo/CurrentHeadRead/CurrentHeadWrite/
// PathClose) is now backed by `src/hgit-core/Meta.HC`'s combined
// per-repo metadata file (ADR 0003) internally - every function's
// SIGNATURE and observable behavior is unchanged from probes 34/35/37,
// so Hgit.HC/Offer.HC/History.HC/Status.HC (every real caller) needed
// no changes at all. This retires the old one-sidecar-file-per-concern
// scheme (`.head.<name>`, `.paths`, `.currentpath`) that motivated ADR
// 0003 in the first place - the real path-length ceiling those files
// were vulnerable to (probe 36) no longer applies to path names at
// all, since names now live inside Meta.HC's one combined file rather
// than in filenames.
//
// `PathNameFits` is kept (same name, same call site in PathNew) but
// its actual constraint changed: under the old scheme it had to budget
// for `repo_path + ".head." + name`; under Meta.HC it only needs
// `repo_path + ".m"` to fit - `name` no longer affects any filename at
// all, so long path names that used to be rejected are now accepted.
//
// Depends on Meta.HC (MetaPathExists/MetaPathDeclare/MetaPathUndeclare/
// MetaPathList/MetaCurrentGet/MetaCurrentSet/MetaReadHead/MetaWriteHead)
// and, transitively, Canon.HC. Load Meta.HC first.

#define HGIT_MAX_PATH_NAME 64

// The real, previously-undocumented TempleOS/RedSea limit found in
// probe 36: a full path string longer than this is silently rejected
// by FileWrite/FileRead - no error, the call just no-ops.
#define HGIT_MAX_SAFE_PATH_LEN 33

// TRUE if the combined metadata file itself (`<repo_path>.m`, from
// Meta.HC's MetaPath) would stay at or under HGIT_MAX_SAFE_PATH_LEN.
// `name` no longer affects this at all under the Meta.HC design (kept
// as a parameter only so PathNew's call site is unchanged) - unlike
// the old per-path-sidecar scheme, a long path NAME is never rejected
// by this check anymore, only a long REPO path would be.
Bool PathNameFits(U8 *repo_path, U8 *name)
{
  return StrLen(repo_path) + 2 <= HGIT_MAX_SAFE_PATH_LEN;
}

// Writes out_name = the current path's name (defaults to "main").
U0 CurrentPathGet(U8 *repo_path, U8 *out_name)
{
  MetaCurrentGet(repo_path, out_name);
}

// TRUE if `name` is "main" or has been declared via PathNew.
Bool PathExists(U8 *repo_path, U8 *name)
{
  return MetaPathExists(repo_path, name);
}

// Prints every path name, "main" first, then each declared path.
U0 PathListPrint(U8 *repo_path)
{
  MetaPathList(repo_path);
}

// Creates a new path named `name`, pointing its HEAD at whatever the
// CURRENT path's HEAD is right now (all-zero if the current path has
// no offerings yet). Returns FALSE if `name` already exists (including
// "main"), is too long, or would push the combined metadata file's own
// path past the safe limit (see PathNameFits above).
Bool PathNew(U8 *repo_path, U8 *name)
{
  I64 name_len = StrLen(name);
  if (name_len <= 0 || name_len >= HGIT_MAX_PATH_NAME) return FALSE;
  if (!PathNameFits(repo_path, name)) return FALSE;
  if (MetaPathExists(repo_path, name)) return FALSE;

  U8 cur_name[HGIT_MAX_PATH_NAME];
  MetaCurrentGet(repo_path, cur_name);
  U8 head[64];
  Bool has_head = MetaReadHead(repo_path, cur_name, head);
  if (!has_head) {
    I64 zi;
    for (zi=0; zi<64; zi++) head[zi] = 0;
  }

  MetaWriteHead(repo_path, name, head);
  MetaPathDeclare(repo_path, name);
  return TRUE;
}

// Switches the current path to `name`. Returns FALSE if `name` doesn't
// exist (callers should create it with PathNew first).
Bool PathGo(U8 *repo_path, U8 *name)
{
  if (!MetaPathExists(repo_path, name)) return FALSE;
  MetaCurrentSet(repo_path, name);
  return TRUE;
}

// Reads HEAD for whichever path is CURRENT right now.
Bool CurrentHeadRead(U8 *repo_path, U8 *hash_out)
{
  U8 cur_name[HGIT_MAX_PATH_NAME];
  MetaCurrentGet(repo_path, cur_name);
  return MetaReadHead(repo_path, cur_name, hash_out);
}

// Writes HEAD for whichever path is CURRENT right now.
U0 CurrentHeadWrite(U8 *repo_path, U8 *hash)
{
  U8 cur_name[HGIT_MAX_PATH_NAME];
  MetaCurrentGet(repo_path, cur_name);
  MetaWriteHead(repo_path, cur_name, hash);
}

// Removes `name` (its HEAD/operation-log records are left behind,
// orphaned but unreachable - same choice the pre-Meta.HC version made
// for its own sidecar files). If the closed path was current, switches
// current back to "main". Refuses to close "main" itself or a path
// that doesn't exist.
Bool PathClose(U8 *repo_path, U8 *name)
{
  if (StrCmp(name, "main") == 0) return FALSE;
  if (!MetaPathExists(repo_path, name)) return FALSE;
  MetaPathUndeclare(repo_path, name);

  U8 cur_name[HGIT_MAX_PATH_NAME];
  MetaCurrentGet(repo_path, cur_name);
  if (StrCmp(cur_name, name) == 0) {
    MetaCurrentSet(repo_path, "main");
  }
  return TRUE;
}

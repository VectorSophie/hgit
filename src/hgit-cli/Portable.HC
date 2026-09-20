// Portable.HC — whole-repo export/import.
//
// Probe 39 proved the OBJECT layer (`.hgs` bytes alone) is portable -
// but a copied `.hgs` file had no HEAD, no paths, no history, because
// those lived in N separate sidecar files keyed to the exact original
// repo path. Now that ADR 0003 is fully wired in (probe 44), a repo's
// ENTIRE state - object layer plus every tool-state concern (HEAD,
// path list, current-path, operation log, redo log) - lives in exactly
// TWO files: `<repo_path>` itself and `<repo_path>.m` (Meta.HC). So a
// full, WORKING copy - not just the object bytes - is just copying
// both files. This is a direct, concrete payoff of ADR 0003's design,
// not a new architectural idea.
//
// `hgit export <repo> <dest>` and `hgit import <src> <dest>` are the
// same underlying copy, named for the two directions of use.
//
// Depends on Meta.HC (MetaPath, to find the `.m` file alongside the
// object file).

U0 CopyFileIfExists(U8 *src_path, U8 *dest_path)
{
  I64 size;
  U8 *buf = HgitFileRead(src_path, &size);
  if (buf == NULL) return;
  FileWrite(dest_path, buf, size);
}

// Copies a repo's full state (object layer + Meta.HC's combined
// metadata file) from src_repo_path to dest_repo_path. If src has no
// `.m` file yet (never touched paths/undo/redo), only the object file
// is copied - a plain object-layer copy, same as probe 39, still
// works fine on the far end (Meta.HC's own functions all default
// sensibly to "main"/empty when their `.m` file doesn't exist).
U0 HgitCopyRepo(U8 *src_repo_path, U8 *dest_repo_path)
{
  CopyFileIfExists(src_repo_path, dest_repo_path);
  U8 src_meta[256], dest_meta[256];
  MetaPath(src_repo_path, src_meta);
  MetaPath(dest_repo_path, dest_meta);
  CopyFileIfExists(src_meta, dest_meta);
}

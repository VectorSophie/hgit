// Init.HC — `hgit init`: create a new, empty repository.
//
// First real CLI-shaped command (M1) built on the now-complete
// hgit-core storage layer (Canon/Blake2b/Hgs). A repository, at this
// stage, is just a `.HGS` file containing the 16-byte header and zero
// objects - no working-directory scanning, no object creation yet
// (that's `hgit witness`/`hgit offer`, not built here).
//
// Verified (experiments/13-hgit-init/): creates a valid empty repo;
// refuses to overwrite an existing one at the same path rather than
// silently clobbering it - confirmed FileRead returns NULL cleanly for
// a missing file (no exception needed) before relying on that.
//
// Depends on Canon.HC, Blake2b.HC, Hgs.HC (HgsWriteHeader/HgsReadHeader).

// Returns TRUE on success, FALSE if a file already exists at `path`
// (existing repos/files are never overwritten by init).
Bool HgitInit(U8 *path)
{
  I64 existing_size;
  U8 *existing = FileRead(path, &existing_size);
  if (existing != NULL) return FALSE;
  U8 header[16];
  HgsWriteHeader(header, 1, 0);
  FileWrite(path, header, 16);
  return TRUE;
}

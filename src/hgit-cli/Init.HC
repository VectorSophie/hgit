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

// Probe 113 (experiments/113-check-format-version/, FORMAT.md's own
// "Versioning policy" section): a new repo now starts at
// `format_version` 2, not 1 - a real, deliberate bump correcting a
// real gap this project found in its own practice: version 1 was
// still being written for every new repo despite at least three real,
// documented breaking changes to what it means since (ADR 0004's
// entity-ID field, ADR 0010's recursive trees, ADR 0011's multi-parent
// commits). No reader anywhere branches on the literal version number
// (confirmed by direct search before this change), so this is purely
// a correction to what gets WRITTEN, not a new migration mechanism -
// no real evidence yet that one is needed (no released users, no repo
// has ever had to survive across one of these format changes). A
// version-1 repo (every repo any test/probe in this project has ever
// built) is not migrated and still reads back fine - HgsReadHeader
// doesn't reject it, and no code path treats the two differently.
//
// ADR 0015 (v1.8.1): bumped again, 2 -> 3, for the same documentation
// reason as the 1 -> 2 bump above - a real, additive commit-content
// change (has_attrs/attrs_hash) exists now. Still purely a correction
// to what gets WRITTEN: `Commit.HC`'s own bounds-check convention
// (`CommitHasAttrs`) already makes an older commit's content read
// back correctly with no attrs, with no version branch anywhere -
// same "no migration mechanism, no evidence one's needed yet" note
// as the version 2 bump.
//
// ADR 0016 (v1.8.3): bumped again, 3 -> 4 - `OBJ_CONFLICT` is a
// genuinely new object type (tag 5) and Meta.HC gains two new record
// tags (META_TAG_MERGE_STATE/META_TAG_CONFLICT). Same real story as
// every bump above: additive, an old reader's own tag-scoped scan
// already ignores a record tag it doesn't recognize, no migration
// mechanism needed - bumped for documentation honesty per this
// project's own standing discipline, not because a version branch is
// technically required to read old repos correctly.

// Returns TRUE on success, FALSE if a file already exists at `path`
// (existing repos/files are never overwritten by init).
Bool HgitInit(U8 *path)
{
  I64 existing_size;
  U8 *existing = FileRead(path, &existing_size);
  if (existing != NULL) return FALSE;
  U8 header[16];
  HgsWriteHeader(header, 4, 0);
  FileWrite(path, header, 16);
  return TRUE;
}

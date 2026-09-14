# Probe 116 — `hgit export`/`hgit import` with a real merge commit and multiple paths: verified correct

Status: **PASS**. `Portable.HC`'s `HgitCopyRepo` (behind both `export`
and `import`) is a raw whole-file byte copy of both the `.hgs` object
file and Meta.HC's own `.m` sidecar - structurally it can't be
confused by specific content (it never parses trees/commits/paths at
all), so no bug was expected. Never directly tested against a repo
with a real merge commit AND more than one real named path with its
own distinct HEAD until now.

## What was checked

A real repo with two real, DIFFERENT-HEAD paths (`main`, post-merge;
`feature`, its own separate pre-merge HEAD, never advanced by the
merge) - `hgit export`ed to a new file, then, on the EXPORTED copy
only:

- `hgit check` - `CHECK_OK objects=13 format_version=2`,
  `CHECK_REFS_OK`, `CHECK_DANGLING_NONE` - the whole object graph
  survived intact.
- `hgit path list` - both `main` and `feature` present.
- `main`'s own HEAD on the export, and `feature`'s own HEAD on the
  export (after switching to it) - both byte-for-byte identical to
  the real, independently-captured original hashes.
- `hgit undo` on the EXPORTED copy - the operation log survived the
  copy too; undo correctly restores the exported copy's own `main`
  HEAD to its real pre-merge commit.
- The ORIGINAL repo's own `main` HEAD, re-checked after undoing the
  EXPORTED copy - completely unaffected, byte-for-byte identical to
  before - confirms `export` makes a real, independent copy, not a
  shared reference of any kind.

## Verified

`test_driver.hc` (`P116ExportImportMergeTest`): every comparison above
is a real byte-for-byte hash match against an independently-captured
value (via `CurrentHeadRead`, before the copy or the undo), not visual
inspection - see `serial-log-evidence.txt`. No source change was
needed - a real verification, not a bug fix.

## What this does not do

- Does not test `hgit import`'s own direction specifically (the same
  underlying `HgitCopyRepo` call, just named for the other real use
  case - not independently re-tested, since it's provably the same
  code path).
- Does not test export/import of a repo with real, unresolved
  in-progress state (there is none in this project - every operation
  either fully completes or has zero side effects, per every real
  command's own non-destructive design).

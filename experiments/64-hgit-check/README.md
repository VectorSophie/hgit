# Probe 64 — `hgit check`: repo integrity verification

Status: **PASS** — implements the original brief's "shrine check"
command, a real gap in the command surface: `init`/`status`/`offer`/
`history`/`see` (M1), `undo`/`redo`/`operation *`/`path *`/`export`/
`import`/`historydoc` (M2), `correct`/`revert`/`reconcile` (M3),
`reconciledoc`/`reconcileoverview` (M4) all grew in, but nothing ever
verified a repo's own on-disk integrity - `hgit check` closes that.

## What it does

`src/hgit-cli/Check.HC`'s `HgitCheck(repo_path)` re-verifies every
object actually stored in a `.hgs` file: reads the file, confirms the
header, then calls `Archive.HC`'s `ArchiveVerify` (built and verified
in M0, `experiments/05-tiny-archive/`) over the object section. This
is not new hashing/verification logic - `ArchiveVerify`'s record shape
(`[U64 length][data][64-byte hash]`) is exactly what `Hgs.HC`'s
`HgsPut`/`Object.HC`'s `ObjectPut` already write for every real object
(the type tag is just the first data byte, transparent to hash
recomputation), so this is a thin, low-risk wrapper over
already-tested code, not a new format or algorithm.

Reports `CHECK_OK objects=<n>` if every object's stored hash matches
its recomputed hash, `CHECK_FAIL objects=<n> ok=<k> corrupt=<n-k>`
otherwise, plus a `CHECK_WARN object_count_mismatch` if the header's
own `object_count` field disagrees with what was actually scanned (a
cheap, separate consistency check the original `ArchiveVerify` didn't
have a caller checking before).

## Verified

- **Real success case**: a freshly offered small repo (`CHECK_OK
  objects=3`, then 6 after a repeat run) and the large, real
  26-offer/~78-object repo probe 62 built (`CHECK_OK objects=78`) both
  verify clean.
- **Real failure case, deliberately induced**: `test_driver_corruption.hc`
  flips one byte inside a real repo's object section (past the 16-byte
  header, via a direct `FileRead`/`FileWrite` round trip, not through
  any hgit command) and confirms `hgit check` catches it precisely -
  `CHECK_FAIL objects=3 ok=2 corrupt=1` - not a false pass, not a
  crash.
- Verified against both the two touched files pushed standalone and a
  freshly rebuilt `packaging/HgitAll.HC` pushed whole from scratch, per
  this project's own standard regression practice. Daemon confirmed
  responsive throughout.

## Not yet done

- Doesn't identify *which* object is corrupt (just the count) - real,
  cheap follow-up (`ArchiveVerify` would need a per-record callback or
  index output, not built here).
- Doesn't check anything beyond hash integrity (e.g. that every
  `parent_hash`/`tree_hash`/`relation_target` a commit references
  actually resolves to a real object in the same archive) - a real,
  separate "referential integrity" check, out of scope for this first
  slice.

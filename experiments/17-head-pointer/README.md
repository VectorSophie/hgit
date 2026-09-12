# Probe 17 — HEAD/current-offering pointer, real TempleOS

Status: **PASS, first try.** Closes the specific blocker probe 16
identified: hgit had no way to name "the current offering."

## Design

One pointer per repository (not the brief's full multi-`path` system —
that's explicitly M2 work; a single implicit path is enough to make
`offer`/`status`/`history` meaningful for M1). Stored as a 64-byte
sidecar file (`<repo_path>.head`) rather than inside the `.HGS` file —
the archive header's reserved field is only 2 bytes, far short of a
64-byte hash, and a separate file needs no changes to the archive
format at all.

## What was tested

1. `HeadRead` on a freshly-`HgitInit`'d repo (no head file yet) →
   `found_before=0` — correctly reports "no current offering," reusing
   the same `FileRead`-returns-`NULL`-means-absent convention already
   established by `HgitInit`/`HgitStatus`.
2. `HeadWrite` a (fake, for this test) 64-byte commit hash, then
   `HeadRead` it back → `found_after=1 match=1`.
3. **`HeadWrite` a *second*, different hash to the same repo, then
   `HeadRead` again** → `match2=1` — confirms this is a real mutable
   pointer that updates, not a write-once accident that happened to
   pass on the first value alone.
4. Final: `PASS head_pointer`.

## Landed as real hgit-cli source

`src/hgit-cli/Head.HC` (`HeadPath`/`HeadRead`/`HeadWrite`) — byte-for-byte
identical to the tested version.

## Not yet done

- Not yet wired into `Status.HC`'s `STATUS_UNIMPLEMENTED` branch — that
  substitution (read HEAD, load its tree, compare against
  `WorkDirList`) is the concrete next step this unblocks, not done here.
- No `hgit offer` yet to actually *create* a real commit and call
  `HeadWrite` with its real hash — this probe used a fabricated hash to
  test the pointer mechanism in isolation.
- Still single-pointer (no named paths/branches) — deliberate M1 scope,
  not an oversight.

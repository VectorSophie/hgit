# Probe 13 — `hgit init`, the first real CLI command, real TempleOS

Status: **PASS, first try.** The first command from the product
thesis's M1 vocabulary (`hgit init`, `status`, `witness`, `offer`, ...)
actually built and verified, on top of the now-complete storage layer
(probes 03–12).

## Preliminary question answered first

Before designing "refuse to overwrite an existing repo," the actual
behavior of `FileRead` on a nonexistent file needed checking — it had
never come up in any prior probe (every prior `FileRead` call targeted
a file that had just been `FileWrite`n). Tested directly:
`FileRead("C:/Home/DefinitelyDoesNotExist.hgs", &size)` →
`probe_null=1 probe_size=0`. Clean `NULL`, no exception, no crash. This
meant `HgitInit` could use a plain `!= NULL` check with no `try`/`catch`
needed (which itself has a real cost, per an earlier session's own
"Tip of the Day": `try{} catch{}` in a function forces all its locals
non-register — worth avoiding when a simpler check suffices).

## What `HgitInit` does

Creates a new repository: a `.HGS` file containing only the 16-byte
header (version 1, 0 objects) — no working-directory scanning or object
creation yet, that's `witness`/`offer`. Refuses to overwrite a path that
already has a file at it.

## What was tested

1. `HgitInit("C:/Home/NewRepo.hgs")` on a fresh path → `r1=1` (succeeds).
2. `HgitInit` again on the **same** path → `r2=0` (correctly refused,
   didn't clobber the existing file).
3. Read the created file back and parsed its header: `rsize=16 hok=1
   version=1 count=0` — exactly an empty, valid `.HGS` repository.
4. Final: `PASS hgit_init`.

## Landed as real hgit-core... no, hgit-cli source

`src/hgit-cli/Init.HC` — the first file in a new module, separate from
`hgit-core` (per the brief's own `hgit-core`/`hgit-platform` boundary:
this is porcelain/command-surface code, not repository-format
mechanics). Byte-for-byte identical to the tested version.

## Not yet done

- No actual command-line argument parsing / entry point yet — `HgitInit`
  is a callable function, not something invoked as `hgit init` from a
  shell. That's real next work once more commands exist to make a
  dispatcher worth building.
- No `.hgit`-directory-style layout (a real repo will likely need more
  than one file eventually — this is the simplest thing that could
  possibly work, matching the brief's own minimalism preference).
- `witness`/`status`/`offer` — the commands that actually make a
  repository useful — don't exist yet.

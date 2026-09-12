# Probe 22 — `hgit see <offering>`, real TempleOS

Status: **PASS, first try.** Shows one commit's full detail — the last
M1 command from doc 10's short list before wiring everything behind a
real entry point.

## What it does

Given a commit's hash, looks it up via `Index.HC`, prints its
timestamp, parent count, and message, then resolves its tree (another
index lookup) and lists every entry (type + name).

## What was tested

Against the real repository from probes 18–21:

1. **HEAD** (the "second" commit) →
   `SEE_COMMIT ts=2000 parents=1 msg=second`, then
   `SEE_TREE entries=2` listing both `OfferFileA.txt` and
   `OfferFileB.txt` as blobs.
2. **Its parent** (walked via `CommitParentHash`, the root "first"
   commit) → `SEE_COMMIT ts=1000 parents=0 msg=first`, its own tree
   with the same 2 entries.
3. **A hash that doesn't exist in the repo** → `SEE_ERR not_found`,
   handled cleanly rather than crashing or guessing.

## Landed as real hgit-cli source

`src/hgit-cli/See.HC` (`HgitSee`) — logic byte-for-byte identical to
the tested version (confirmed via diff — comment addition only).

## Not yet done

- Takes the target as a raw 64-byte hash, not a hex string or a
  friendly reference like `HEAD` or `HEAD~1` — that's real work for
  whenever an actual argv-driven CLI entry point is built (hex-string
  parsing hasn't been designed or tested at all yet).
- No diff output (what changed vs. the parent) — only the tree's full
  entry listing, which is closer to `git show --stat` than
  `git show`.
- With `init`/`status`/`offer`/`history`/`see` all now built and
  independently verified, the concrete next step is composing them
  behind one real command-line entry point — the last M1 milestone
  item before this stops being "a library of verified functions" and
  becomes "a program."

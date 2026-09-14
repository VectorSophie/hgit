# Probe 112 — `hgit see`: real parent hashes, not just a count

Status: **PASS**. Follows the same "check what a merge commit actually
does to real command output" thread probes 109-111 opened. `See.HC`'s
own `SEE_COMMIT ts=... parents=N msg=...` line only ever showed the
parent COUNT - for a real merge commit (the only case with more than
one), a user had no way to see WHICH two commits were actually joined
without separately cross-referencing `hgit history`/`operation
history`'s own output by timestamp.

## What was built

One `SEE_PARENT <hex>` line per real parent, printed right after
`SEE_COMMIT`, in the same order `Commit.HC`'s own encoding stores them
(index 0, 1, ... - for a real merge commit, `Merge.HC`'s own
convention: index 0 = "ours", index 1 = "theirs"). A root commit (0
parents) correctly prints no `SEE_PARENT` lines at all - not a special
case, just the loop running zero times.

## Verified

`test_driver.hc` (`P112SeeParentHashesTest`): three real cases, each
cross-checked against an independently-read real hash (`CurrentHeadRead`
at the moment each commit was made, not re-derived from `see`'s own
output):

- A root commit - `parents=0`, no `SEE_PARENT` line at all.
- An ordinary one-parent commit - exactly one `SEE_PARENT` line,
  byte-for-byte matching the real parent hash read independently
  before the commit existed.
- A real merge commit - exactly two `SEE_PARENT` lines, the first
  byte-for-byte matching the real "ours" hash (`main`'s own head at
  merge time) and the second byte-for-byte matching the real "theirs"
  hash (`feature`'s own head), in that real order.

`tools/lint-package.sh` clean (only the 3 known built-in-manifest
gaps). Both the standing regression and the full command-surface
suite (`tests/full-regression.hc`) re-run clean afterward - existing
`see` output simply gained a new line for commits that have parents,
nothing else changed.

## What this does not do

- Does not change `hgit diff`/`hgit check`/any other command's own
  output - only `See.HC`.
- Does not add a way to look up a parent's own message/tree by hash
  directly from this output - a user still re-runs `hgit see <repo>
  <that hex>` themselves, same as before.

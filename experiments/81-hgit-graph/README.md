# Probe 81 — `hgit graph`: a real commit graph across every path

Status: **PASS**. User-requested feature ("finishing off with a git
graph like thing"), not a milestone-plan item.

## What was built

`src/hgit-cli/Graph.HC` — `hgit graph <repo_path> <dest.DD>` renders a
real DolDoc tree view of the repo's ENTIRE commit history across every
declared path, not just one path's own linear chain (`historydoc`) or
relation-carrying commits only (`reconcileoverview`). "main"'s own
chain renders as the trunk (root at the top, HEAD at the tip, each
commit nested one level deeper than its parent), using the same real
`$TR$`/`$ID,+2$`/`$ID,-2$` tree-widget nesting `reconcileoverview`
already verified (probes 57-59). Every OTHER declared path attaches as
its own nested branch at the exact commit it forked from — a real
analogue of `git log --graph --all`, scoped to this project's actual
ref model (named paths, not full branches with merges; no multi-parent
commits exist yet).

Fork points are real, not guessed: `Paths.HC`'s own `PathNew` copies
the current path's HEAD at creation time, so a path's fork point is
always a findable ancestor on the path it was created from - found by
walking backward from a path's own HEAD until a commit already in
main's chain is hit.

(Originally named `historygraph`; renamed to the shorter `graph` on
the user's own suggestion mid-build.)

## Verified

`test_driver.hc` (`P80HistoryGraphTest`, kept as the internal function
name it had when first written and captured - the probe directory
itself is numbered 81 to avoid colliding with a concurrent peer
session's own `experiments/80-fossil-checksum-root-cause/`): built a
real fork - `offer_one` → `offer_two` on `main`, then `path new
feature` (forking from `offer_two`), then `offer_three_on_feature` on
`feature` only. `hgit graph` produced exactly the expected structure:

```
$TR,"468bbd6656 offer_one"$$ID,+2$
  $TR,"0c6b94e6ba offer_two"$$ID,+2$
    $TR,"[feature] b0598745e9 offer_three_on_feature"$$ID,+2$$ID,-2$
  $ID,-2$
$ID,-2$
```

(reformatted here for readability; the real raw output is one
continuous stream - see `serial-log-passing-run.txt` for the exact
bytes). `offer_one` at the root, `offer_two` nested one level under
it, and `[feature]`'s own unique commit nested a further level under
`offer_two` - precisely the fork point, confirmed by exact string
match against the raw `.DD` bytes, not just visual inspection.

**Regression**: re-ran `experiments/65-head-deletion/test_driver.hc`
(the project's standing full command-surface regression) immediately
after - all still correct, `PASS p65_head_deletion_regression`.

`tools/lint-package.sh` clean before pushing - it caught a real
"duplicate member" collision in this file's own first draft (`doc0`/
`dlen0` declared in two sibling early-return blocks), fixed by
renaming the second pair before ever reaching QEMU.

## Not yet done

- Only single-level fork attachment against `main` is computed - a
  path forked from another non-main path renders as its own second
  top-level tree instead of nesting under its true immediate parent
  path (documented directly in `Graph.HC`'s own header comment).
- No ASCII line-art columns (`| * |\` style) - real DolDoc tree
  widgets (collapsible, native TempleOS UI) instead, which fits this
  project's own "executable DolDoc reconciliation" theme better than
  approximating git's own text-graph rendering would.
- No truncation guard for an extremely long individual commit message
  - `doc[]` is sized from the repo's real object count (300 bytes/
  commit heuristic) rather than a fixed cap, covering every real case
  tested so far, but not a proven bound - same honest caveat every
  other heuristically-sized buffer in this codebase carries.

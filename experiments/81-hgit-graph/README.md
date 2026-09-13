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

**Rendered, not just raw bytes**: `evidence/rendered-graph-collapsed.png`
- the same document opened in TempleOS's own `Ed()` (real technique
from probes 54/57/58/59: push a snippet calling `Ed()`, which blocks
the daemon's own command loop; screendump while it's open; dismiss
with `sendkey shift-esc`; confirm the daemon resumes via a post-marker
in the log). Shows the real title line and the root `[+] 468bbd6656
offer_one` node, collapsed by default - matching every other `$TR$`
tree this project has ever rendered (probe 57's own finding); the
daemon resumed cleanly afterward (`POST_ED` printed, then normal
`COMPILE_OK`/`D_DONE`).

**Regression**: re-ran `experiments/65-head-deletion/test_driver.hc`
(the project's standing full command-surface regression) immediately
after - all still correct, `PASS p65_head_deletion_regression`.

**Update - real attempt to get an expanded-tree screenshot, not
successful**: since a collapsed-root-only screenshot doesn't actually
show the branching structure, real mouse-click expansion was
attempted, twice, in separate follow-up sessions:
- Keyboard cursor positioning (`down`/`home`/`space`/`ret` at the
  `[+]` marker's own row/column) - moved the text cursor correctly but
  never toggled the node; `ret` at column 1 instead inserted a literal
  newline into the document (undone by not saving).
- A disposable snapshot-mode QEMU session with a real
  `-device usb-tablet` attached (absolute mouse positioning, computed
  from the marker's real pixel position via a zoomed crop of a real
  screendump) - `mouse_move`/`mouse_button` at the computed coordinate,
  and a small grid of nearby coordinates, produced no visible change.

Along the way, an unrelated real bug was found and understood: the
very first attempt showed a completely blank document pane opening
the ORIGINAL `P80GraphDemo.DD` (from this probe's own initial run) in
a fresh snapshot session - initially suspected to be the `usb-tablet`
device or a rendering regression, but isolated by testing a freshly
`FileWrite`-generated copy of the *identical* bytes in the same fresh
session, which rendered correctly. The original file itself was
stale/bad on the persistent dev disk (root cause not pursued further -
not a hgit bug, and the workaround, regenerating fresh, is trivial).

Not pursued further after this second real attempt - a genuine, hard
problem (TempleOS's own click-to-expand semantics for `$TR$` aren't
something this project's headless automation can currently drive
reliably), not a quick fix. `README.md` was updated to not show a
screenshot that only demonstrates one collapsed line - the reformatted
text structure is the real, complete illustration instead.

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

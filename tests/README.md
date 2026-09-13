# tests/ — one canonical, comprehensive regression suite

`full-regression.hc` is a single, real, re-runnable pass over hgit's
entire command surface on one fresh repo - `HgitFullRegressionTest`,
pushed and run on real TempleOS under QEMU the same way every one of
this project's ~86 `experiments/` probes has been. It exists because
this project's own real testing has been genuinely thorough
throughout, but scattered one probe-directory-per-feature across
`experiments/` - useful as a historical record of *how* each feature
was verified when it was built, but not as a single place to answer
"does the whole product still work right now."

## What it covers, in order

`init` → `offer` (root commit) → `offer` with a modify, a delete, an
exact-content-plus-edit (fuzzy) rename, and a new file all in one →
`status` (verifies all five classifications - unchanged/modified/
renamed/new/deleted - in that single offer, before it's committed) →
that same offer committed → `history` → `see` → `diff` (same five
classifications again, this time commit-vs-parent instead of
directory-vs-HEAD) → `check` (hash integrity, referential integrity,
dangling-object detection) → `undo` (confirms the undone commit's own
objects go dangling, without being destroyed) → `redo` →
`operation history` → named paths (`path new`/`go`/`list`) →
`correct` (ADR 0005/0006 typed relations) → `historydoc`/
`reconciledoc`/`reconcileoverview`/`graph` (DolDoc views - dispatch
success only, not their own rendered output) → `export` (+`check` on
the exported copy) → `import` (+`check` on the imported copy) →
`offertree`/`statustree`/`correcttree` (ADR 0010's own subdirectory
support - a real nested edit, then a real relation carried on a
nested offer) → `merge` (ADR 0011: a real non-conflicting merge
between two diverged paths, then a real fast-forward against a
never-diverged one) → `help`/`version`/`logo`.

Deliberately not exhaustive: `revert`/`reconcile` and
`reverttree`/`reconciletree` share `correct`/`correcttree`'s own
underlying code path (`HgitOfferRelatedCmd`/`HgitOfferTreeRelatedCmd`,
differing only in which `REL_*` tag is passed) and aren't separately
re-tested here. A real merge CONFLICT isn't exercised in this suite
(only the two non-conflicting/trivial outcomes) - a real, separate
scoping choice to keep this one already-long sequence's own repo
state simple and deterministic; probes 99/100 already cover the
conflict-abort path directly and thoroughly. `path close` and
`operation restore` aren't exercised (the latter's own effect on HEAD
would need care to keep the rest of this sequence deterministic - a
real scoping choice, not an oversight).

## Verified

Run end-to-end on real QEMU (`serial-log-passing-run.txt`, `TFULL_BEGIN`
through `TFULL_END`) - every stage's own real output, not just
`DISPATCH_OK`: `STATUS_MODIFIED`/`STATUS_RENAMED`/`STATUS_NEW`/
`STATUS_DELETED`/`STATUS_UNCHANGED` all correct for their respective
files in one status check; the matching `DIFF_*` set correct against
the parent commit; `CHECK_DANGLING_NONE` before `undo`,
`CHECK_DANGLING_COUNT` correctly non-zero (naming the undone commit's
own real objects) right after it; the exported AND imported repo's own
`check` both passing; a real nested `STATUS_MODIFIED SubA/inner.txt`
from `statustree`; `MERGE_OK` for a real non-conflicting merge and
`MERGE_FASTFORWARD` for a real fast-forward, each followed by its own
`check` passing. Also re-run a second time in the same session,
confirming this suite really is re-runnable, not just runnable once
from a pristine state - the property its own name claims.

**A real test-hygiene bug was found and fixed while building this**:
the first version only deleted the repo itself between manual re-runs
in this same session, not the individual working-directory files
(`TFOrig.txt`, `TFRenamed.txt`, etc.) - re-running it against a
session that already had leftover files from an earlier run matched
those old files via the same `TF*.txt` find_mask, silently
corrupting the result (e.g. a file appearing `STATUS_UNCHANGED` when
it should have been the actual rename target, because a stale copy
from a prior run already looked "already committed" against the
current tree). Fixed by explicitly `Del()`-ing every file the test
creates, not just the repo, at the very start - see the file's own
top comment. Logged as a real, useful, general lesson (not specific to
this one test) in `docs/research/failed-approaches.md`.

## How to run it

Same as any other probe: push `tests/full-regression.hc` to a live
hgit daemon (`experiments/01-temple-repl/paced_push.py`), watch for
`TFULL_BEGIN` through `TFULL_END` in the serial log, and read the
actual classification/output lines in between - a clean run alone
(`COMPILE_OK`/no crash) is not sufficient evidence; check the real
content.

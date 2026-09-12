# Probe 35 — offer/status/history become path-aware, PASS

Status: **PASS**, real, on real TempleOS under QEMU
(`serial-log-passing-run.txt`, `evidence-pass.png`). This is the "wire
it in" half of probe 34's explicitly-flagged next step — named paths
existed as pure bookkeeping there; this probe makes them actually
change what commands operate on.

## What changed

`src/hgit-cli/Paths.HC` gained `CurrentHeadRead`/`CurrentHeadWrite` —
the same TRUE/FALSE-if-empty convention as `Head.HC`'s `HeadRead`/
`HeadWrite`, but resolving through `CurrentPathGet` +
`PathHeadFilePath` instead of always `<repo_path>.head`. Four call
sites switched over: `Offer.HC` (both the parent-lookup read and the
final HEAD write), `History.HC`, `Status.HC`.

**Deliberately left unchanged:** `OpLog.HC`'s `OpLogUndo`/`OpLogRedo`
still call the plain `HeadWrite` (always "main"'s file), *not*
`CurrentHeadWrite`. The operation log itself (`<repo_path>.oplog`) is
still a single shared-across-all-paths log, not yet split per path —
making undo/redo current-path-aware without first making the log
itself path-scoped would silently let an undo on one path revert a
HEAD hash that actually belongs to a different path's history, a real
correctness bug, not just a missing feature. Flagged here rather than
introduced.

## What was verified

`test_driver.hc`, through the real `Hgit(cmdline)` dispatcher: one
commit on `main`, branch to `feature`, one more commit while on
`feature`, then check both paths independently:

```
DISPATCH_OK offer
DISPATCH_OK path_new feature
DISPATCH_OK path_go feature
DISPATCH_OK offer
main_unchanged_after_feature_offer=1
feature_head_differs_from_main=1
commit ts=1083036 msg=feature commit 1
commit ts=1081763 msg=main commit 1
HISTORY_END shown=2
DISPATCH_OK path_go main
commit ts=1081763 msg=main commit 1
HISTORY_END shown=1
STATUS_MODIFIED P35FileA.txt
STATUS_END
DISPATCH_OK path_go feature
STATUS_UNCHANGED P35FileA.txt
STATUS_END
PASS path_aware_offer
```

- Offering while on `feature` correctly leaves `main`'s own `.head`
  file untouched (checked by byte comparison, not assumed) and creates
  a genuinely different hash in `feature`'s own `.head.feature` file.
- `hgit history` while on `feature` shows **2** entries (feature's own
  commit, chained back to main's) — while on `main` shows **1** — the
  same command, same repo, different results purely because current
  path differs. This is the actual proof paths now matter, not just
  bookkeeping.
- `hgit status` while on `main` correctly reports the working file as
  `MODIFIED` (disk holds `feature`'s newer content, which `main`'s own
  last commit never recorded) — while on `feature` reports
  `UNCHANGED` (disk matches exactly what `feature` committed). Neither
  is a coincidence: both follow directly from which path's tree
  `status` is diffing against.

## Not yet done

- `undo`/`redo`/`operation history` remain main-only (see above) —
  making the op log itself path-scoped is the natural next step before
  those can safely become path-aware too.
- `hgit see` takes an explicit hash argument already, so it was never
  path-*unaware* to begin with — nothing to change there.
- No merge/reconciliation between paths still - this probe only proves
  independent tracking, not bringing divergent paths back together.

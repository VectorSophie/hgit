# Probe 32 — undo/redo stack (`hgit redo`), PASS

Status: **PASS**, real, on real TempleOS under QEMU
(`serial-log-passing-run.txt`, `evidence-pass.png`), pushed through the
already-running stage-2 daemon set up in probe 31 (no reboot needed —
first real reuse of a live session across two probes in this project).

## Design

`OpLog.HC` gained a second sidecar file, `<repo_path>.redolog`, same
136-byte entry shape as `.oplog`:

- `OpLogUndo` now pushes the entry it reverts onto the redo log
  (via a shared `OpLogAppendTo` helper both logs use) before
  truncating the undo log — instead of just discarding it, as probe 30's
  version did.
- `OpLogRedo` (new): pops the most recently undone entry off the redo
  log, re-applies its `new_head` to HEAD, and pushes it back onto the
  undo log — so undo/redo/undo/redo... works, not just one level.
- `OpLogAppend` (called by every real operation, e.g. `offer`) clears
  the redo log — standard undo/redo semantics: doing new work after an
  undo invalidates whatever was undone. Verified explicitly (see below),
  not just assumed from the design.
- `Hgit.HC` gained a `redo` dispatch branch, symmetric with `undo`.

## What was tested

`test_driver.hc`, through the real `Hgit(cmdline)` dispatcher only:

```
DISPATCH_OK init C:/Home/P32Repo.hgs
DISPATCH_OK offer
DISPATCH_OK offer
DISPATCH_OK undo
undo_matches_head1=1
DISPATCH_OK redo
redo_matches_head2=1
DISPATCH_ERR nothing_to_redo
redo_ok2=0 (expect 0)
DISPATCH_OK undo
DISPATCH_OK offer
redo_ok3=0 (expect 0, new offer must clear redo log)
PASS oplog_redo
```

- offer, offer, undo → HEAD correctly back at the first commit.
- redo → HEAD correctly forward again to the second commit.
- a second redo (nothing left to redo) correctly reports failure
  (`OpLogRedo` returns `FALSE`, checked directly since `Hgit()` itself
  is `U0` and doesn't surface a return value to the test — same
  workaround style as probe 30).
- undo again, then a **real new `offer`** — then redo correctly reports
  failure again, proving the redo log was actually cleared by the new
  operation, not just coincidentally empty.

## Not yet done

- `hgit operation history` / `hgit operation restore <op>` — the
  brief's richer vocabulary beyond plain undo/redo — still not built.
- The 16384-byte fixed buffer cap on `OpLogAppendTo` (~120 entries
  per log) is unchanged from probe 30/31, now shared by two sidecar
  files instead of one — still not made dynamic.
- `FileWrite(path, empty, 0)` (used to clear the redo log) was not
  independently probed as its own claim before this - it's exercised
  here only as part of the full `PASS`, not isolated the way probe 30
  isolated `FileWrite`'s shrink behavior. Worth a dedicated check if a
  future probe depends on "does FileWrite honor a zero-length write"
  more directly.

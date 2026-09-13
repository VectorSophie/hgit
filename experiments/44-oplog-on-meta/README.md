# Probe 44 — OpLog.HC cut over to Meta.HC, PASS: ADR 0003 complete

Status: **PASS**, real, on real TempleOS under QEMU
(`serial-log-passing-run.txt`, `evidence-pass.png`). This is the last
real-command cutover for ADR 0003 — every command that used to depend
on the old per-path sidecar-file scheme now runs on `Meta.HC`'s
combined metadata file.

## What changed

`src/hgit-cli/OpLog.HC` rewritten: every public function
(`OpLogAppend`/`OpLogUndo`/`OpLogRedo`/`OpLogHistory`/`OpLogRestore`)
keeps its exact name and signature, now backed by `Meta.HC`'s
operation-log slice (`MetaOpLogAppend`/`MetaOpLogPopLast`/
`MetaOpLogGet`/`MetaOpLogCount`) and a matching new redo-log slice
(`MetaRedoLogAppend`/`MetaRedoLogPopLast`/`MetaRedoLogClear`, its own
tag so it never collides with the operation log when scanned). Because
the public API is unchanged, `Offer.HC` and `Hgit.HC` needed **zero**
changes.

One real design subtlety, called out explicitly in both files' new
comments: `OpLogAppend` is responsible for clearing the redo log
(`MetaRedoLogClear`) — this is **not** baked into `MetaOpLogAppend`
itself, because `OpLogRedo` also calls `MetaOpLogAppend` internally
(to push a redone entry back onto the undo log) and must *not* wipe
the remaining redo log as a side effect of that reuse.

`OpLog.HC` now depends on `Meta.HC` (for the log itself) and `Hex.HC`
(for `OpLogHistory`'s printable hex output — deliberately kept out of
`Meta.HC`, since hgit-core shouldn't depend on hgit-cli's formatting
helpers).

## What was verified

`test_driver.hc` reuses probe 36's exact path-scoping scenario (undo on
`"feature"` reverts only its own HEAD; redo restores it; undo on
`"main"` doesn't touch `"feature"`) plus probe 38's operation-history/
restore scenario, all through the real `Hgit(cmdline)` dispatcher:

```
DISPATCH_OK undo
feature_reverted_by_own_undo=1
main_untouched_by_feature_undo=1
DISPATCH_OK redo
feature_restored_by_own_redo=1
DISPATCH_OK undo
feature_untouched_by_main_undo=1
OP 0 ts=... prev=...5eac550... new=...
OP 1 ts=... prev=... new=...
OP 2 ts=... prev=... new=...
DISPATCH_OK operation_history
DISPATCH_OK operation_restore 0
PASS oplog_on_meta
```

- `undo` on `"feature"` correctly changes its HEAD away from what it
  was (reverts it); `main`'s HEAD is confirmed byte-for-byte unchanged.
- `redo` correctly restores `"feature"`'s HEAD to exactly what it was
  before the undo.
- Switching to `"main"` and undoing there leaves `"feature"`'s HEAD
  completely untouched — real cross-path isolation, reproduced
  identically to probe 36 under the new backing store.
- `operation history` correctly lists 3 chained entries for
  `"feature"` (each entry's `prev` matching the previous entry's
  `new` — a real hash chain, not coincidence); `operation restore 0`
  runs without error.

(The `DISPATCH_ERR init_failed`/`path_new_failed`/`nothing_to_undo`
lines earlier in the same log are expected, harmless residue of an
initial test-logic bug caught and fixed mid-probe — the FIRST push had
an inverted comparison in the test itself, not in the real code, shown
by `feature_restored_by_own_redo=1` already proving `undo` had worked;
the corrected test was pushed to the same already-initialized repo, so
`init`/`path new` correctly refused to redo already-completed setup,
and `main`'s log was already empty from the first run's own undo. Not
a bug - the same "residue of re-running against the same repo"
pattern already documented in prior probes.)

## ADR 0003 — now fully wired into real commands

With this probe, every concern the old sidecar-file scheme held (HEAD,
path list, current-path, operation log, redo log) is verified running
through `Meta.HC` in real commands (`offer`/`status`/`history`/
`undo`/`redo`/`operation history`/`operation restore`/`path *`). The
`.head`/`.head.<name>`/`.paths`/`.currentpath`/`.oplog*`/`.redolog*`
sidecar files are no longer written or read by any real command -
`Head.HC` remains in the codebase (unused by real commands, not
deleted) as the only leftover.

## Not yet done

- `Head.HC` itself is not deleted - a separate decision.
- No corpus-scale stress test of `Meta.HC`'s linear-scan-based
  primitives (`MetaFind`/`MetaSpliceOut(Last)`) against a repo with
  many paths and a long operation history - fine at this project's
  current tiny scale, not yet measured beyond it (same "no premature
  optimization" stance as `Index.HC`'s own linear scan, ADR 0001).

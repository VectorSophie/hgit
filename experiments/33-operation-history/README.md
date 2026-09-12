# Probe 33 — `hgit operation history`, PASS

Status: **PASS**, real, on real TempleOS under QEMU
(`serial-log-passing-run.txt`, `evidence-pass.png`), same live stage-2
session reused from probes 31/32.

## What was added

- `src/hgit-cli/OpLog.HC`: `OpLogHistory(repo_path)` — read-only, walks
  the `.oplog` sidecar oldest-first, printing each entry's index,
  timestamp, and `prev`/`new` hashes as hex (via `Hex.HC`'s
  `HashToHex`). Prints `OPLOG_EMPTY` rather than nothing when the log
  is missing/empty.
- `src/hgit-cli/Hgit.HC`: the dispatcher's `cmd` token only ever
  captures the *first* space-separated word, so the brief's two-word
  `operation history`/`operation restore <op>` vocabulary needed a new
  `operation` branch that itself extracts a sub-command token from
  `rest` before treating anything further as that sub-command's own
  arguments. Only `history` is implemented; any other sub-command
  reports `DISPATCH_ERR unknown_operation_subcommand`, confirmed not to
  silently do nothing.

## What was verified

`test_driver.hc`, through the real two-word `Hgit("operation history ...")`
dispatch:

```
DISPATCH_OK init C:/Home/P33Repo.hgs
OPLOG_EMPTY
DISPATCH_OK operation_history
DISPATCH_OK offer
DISPATCH_OK offer
expected_new1=93e6b280...5eac550
expected_new2=56f7a14e...4d1f3b6
OP 0 ts=825782 prev=000...000 new=93e6b280...5eac550
OP 1 ts=826036 prev=93e6b280...5eac550 new=56f7a14e...4d1f3b6
DISPATCH_OK operation_history
DISPATCH_ERR unknown_operation_subcommand bogus
```

- Empty repo: `operation history` correctly prints `OPLOG_EMPTY`, not
  garbage or nothing.
- After two real offers: `OP 0`'s `new` matches the actual HEAD read
  back after the first offer (`expected_new1`) character-for-character;
  `OP 1`'s `prev` matches `OP 0`'s `new` (a real hash chain, not two
  independent values that happen to print); `OP 1`'s `new` matches the
  actual HEAD after the second offer (`expected_new2`).
- `operation bogus ...` correctly reports an unknown-subcommand error
  rather than doing nothing or crashing.

(Verification here is exact-string comparison against printed hex,
checked by reading the actual serial.log output, not an automated
boolean `PASS`/`FAIL` line — same rigor, different presentation, since
the point of this command is to print human-readable history, not
return a single true/false.)

## Not yet done

- `hgit operation restore <operation>` — the brief's other named
  command in this vocabulary — still not built. (Note: with `undo`/
  `redo` already covering "step back/forward one," `restore <op>`
  would need to jump to an arbitrary point in the log, not just the
  adjacent one — a bigger design question than this probe's scope.)
- No pagination/limit on `operation history` for a large log (shares
  the same ~120-entry fixed-buffer ceiling as `OpLogAppendTo`).

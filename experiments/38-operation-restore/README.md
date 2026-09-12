# Probe 38 — `hgit operation restore <op>`, PASS

Status: **PASS**, real, on real TempleOS under QEMU
(`serial-log-passing-run.txt`, `evidence-pass.png`). This is the last
of the brief's explicitly-named operation-log vocabulary
(`undo`/`redo`/`operation history`/`operation restore <op>`) — all
four now exist and are verified.

## Design

`OpLogRestore(repo_path, index)` in `OpLog.HC`: jumps CURRENT path's
HEAD directly to the `new_head` recorded by the operation at `index`
(0-based, oldest first — same numbering `OpLogHistory` already prints
as `OP <index>`), regardless of how many steps away that is. Refuses
out-of-range indices.

**Deliberately simpler than undo/redo**: this does *not* touch either
the undo or redo log — no popping, no pushing, just a direct HEAD set.
Making an arbitrary restore compose cleanly with undo/redo afterward
(what happens to the log entries "between" the old and new HEAD?)
would need real reconciliation logic; that's flagged as out of scope
here, not an oversight. `operation restore <op>` is for "jump to a
known point," not for chaining with undo/redo afterward.

`Hgit.HC` gained a `restore` case inside the existing `operation`
dispatch branch, plus a small `ParseI64` helper (a plain decimal-digit
parser, not a general atoi — TempleOS's own string-to-integer kernel
API wasn't independently verified from source, so a minimal local
parser was written instead, per this project's standing caution about
unverified APIs).

## What was verified

`test_driver.hc`, through the real `Hgit(cmdline)` dispatcher: three
real offers (three logged operations, `OP 0`/`OP 1`/`OP 2`), then:

```
DISPATCH_OK offer
DISPATCH_OK offer
DISPATCH_OK offer
DISPATCH_OK operation_restore 0
matches_head0_after_restore_to_0=1
DISPATCH_OK operation_restore 2
matches_head2_after_restore_to_2=1
DISPATCH_ERR operation_restore_failed 99
restore99_refused=1 head_unchanged_after_bad_restore=1
PASS operation_restore
```

- `operation restore 0` correctly jumps HEAD back to the very first
  commit's hash — a two-step jump, not just an adjacent undo.
- `operation restore 2` correctly jumps forward again to the third
  commit's hash — proving this isn't secretly just calling undo/redo
  repeatedly under the hood, it's a direct set.
- An out-of-range index (`99`, only 3 operations exist) is refused by
  both the real dispatcher and a direct `OpLogRestore` call, and HEAD
  is confirmed byte-for-byte unchanged afterward — no partial or wrong
  state left behind by the refused attempt.

## Not yet done

- No reconciliation between `operation restore` and the undo/redo
  stacks — restoring to an arbitrary point doesn't rebuild what "undo"
  or "redo" would mean relative to it afterward (flagged above, by
  design, not fixed here).
- Only operates on the CURRENT path's own log, consistent with probe
  36's path-scoping — restoring across paths isn't a concept this
  command has.

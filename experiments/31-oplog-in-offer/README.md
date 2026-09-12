# Probe 31 — wire OpLogAppend into Offer.HC (attempted; QEMU verification BLOCKED, not yet obtained)

Status: **Source change made and reasoned through; real-TempleOS verification
NOT obtained this session — infrastructure-blocked, not a code failure.**
Do not read this as "PASS" anywhere else in the repo; the previous probes
(00-30) are all genuinely QEMU-verified, this one honestly is not yet.

## What was changed (source-level, not yet re-run on real TempleOS)

- `src/hgit-cli/Offer.HC`: `HgitOffer` now calls `OpLogAppend` itself,
  right before `HeadWrite`, logging the real `prev_head` (current HEAD,
  or an all-zero sentinel when there wasn't one yet — `parent_hash` is
  uninitialized stack garbage in that branch, so the zero buffer is
  built explicitly rather than reusing it) and the new commit hash.
  Previously (probe 30) this was only ever called manually, alongside
  `HgitOffer`, never from within it.
- `src/hgit-cli/Hgit.HC`: added an `undo` branch to the `Hgit(cmdline)`
  dispatcher, calling `OpLogUndo` and reporting
  `DISPATCH_OK undo` / `DISPATCH_ERR nothing_to_undo`.
- `tools/build-package.sh`: added `src/hgit-cli/OpLog.HC` to the
  concatenation order (after `See.HC`, before `Offer.HC`, since `Offer.HC`
  now calls it). Rebuilt `packaging/HgitAll.HC` (59619 bytes).
- `experiments/31-oplog-in-offer/test_driver.hc`: a test written to
  exercise this end-to-end through the real `Hgit(cmdline)` entry point
  (init → offer → offer → undo → undo), checking the `.oplog` sidecar
  file's size directly after each offer (136 bytes, then 272) to confirm
  the log is written as a side effect of `offer` alone, with no manual
  `OpLogAppend` call anywhere in the test — unlike probe 30.

## What actually happened when this was pushed to real TempleOS

Two separate QEMU sessions were attempted, both ending the same way:
booted the persistent disk, selected Drive C, dismissed "Take Tour",
bootstrapped the stage-1 `D()` daemon (confirmed alive — `D_OK` appeared
in `serial.log` both times), then pushed real HolyC source over the
COM2 socket. In neither session did a `D_DONE` (or any compile error)
ever appear, despite waiting far longer than any prior probe needed:

- **Session 1**: pushed the full rebuilt `packaging/HgitAll.HC` (59619
  bytes) as one chunk. No `D_DONE` after >4 minutes; the QEMU process's
  own CPU-time counter showed it was initially busy (2m55s of CPU in
  the first ~4 minutes) then went nearly idle (only ~1 more minute of
  CPU across the next 5+ minutes) with still no output — consistent
  with either a genuine execution hang or the host running out of
  attention for it, not an active compile.
- **Session 2** (fresh reboot, to rule out leftover state): split the
  push into two smaller chunks — `hgit-core` (26917 bytes, function
  definitions only, no top-level statements) pushed first, on its own.
  Still no `D_DONE` after **~11 minutes** of wall-clock waiting,
  spanning several checks.

## Confounding factor found honestly, not brushed past

Partway through session 2's wait, `free -h` on the host showed severe
memory pressure: swap at 1.9/2.0 GiB used, only ~2 GiB RAM free, several
unrelated heavy processes (VS Code, Discord, multiple other Claude
sessions) competing for it. Background shell wait-loops used to poll
`serial.log` were themselves killed by the host's own low-memory
watchdog mid-probe (twice). This is a real, observed constraint — but
it does **not** fully explain the result: QEMU's own CPU-time counter
kept advancing (real work was happening), the guest never printed a
compile error, and 11 minutes is far beyond every other probe's
compile time for a similar or larger chunk (probe 28 packaged and
loaded a 55238-byte single file successfully). Whether this is the
same "genuine unexplained hang" logged in probe 29 (unresolved there
too) or purely host resource starvation this time could not be
disambiguated with the diagnostics available (screendump showed no
error window in either case) — recorded honestly as unresolved, not
guessed at.

## What this means for the source change above

The `Offer.HC`/`Hgit.HC`/`build-package.sh` edits are a small, reasoned
diff on top of already-verified code (`OpLog.HC`'s functions themselves
were fully verified in probe 30; this only moves one already-tested
call from "manual, alongside offer" to "inside offer, with the correct
zero-sentinel construction for the no-parent case") — but per this
project's own stated rule, that reasoning is not a substitute for
running it. **This is explicitly logged as not-yet-verified**, distinct
from every prior probe's real pass/fail result, until a QEMU session
with enough headroom actually returns `D_DONE`/`PASS`/`FAIL` for
`test_driver.hc`.

## Not yet done

- Re-attempt this probe's QEMU verification once host memory pressure
  has cleared (retry is cheap — no code changes needed, just re-run the
  same push against a fresh boot).
- If the hang reproduces again under normal host conditions, treat it
  as a real, reproducible HolyC/QEMU issue worth its own investigation
  (bisect by pushing progressively smaller chunks of `hgit-core` to find
  the exact file/function that stalls), rather than assuming host
  contention again.
- `redo`, `hgit operation history`, `hgit operation restore <op>` are
  still not built (see probe 30's own "not yet done" list — unchanged).

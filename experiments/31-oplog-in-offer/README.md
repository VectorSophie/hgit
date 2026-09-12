# Probe 31 — wire OpLogAppend into Offer.HC, PASS (after fixing the test harness itself)

Status: **PASS**, real, on real TempleOS under QEMU
(`serial-log-passing-run.txt`, `evidence-pass.png`). This also closes out
a real open question this project had logged twice as "genuine
unexplained hang, cause not determined" (2026-09-12 and earlier today
in this same probe) — see below, that mystery is now understood.

## What was changed (source)

- `src/hgit-cli/Offer.HC`: `HgitOffer` now calls `OpLogAppend` itself,
  right before `HeadWrite`, logging the real `prev_head` (current HEAD,
  or an all-zero sentinel when there wasn't one yet — `parent_hash` is
  uninitialized stack garbage in that branch, so the zero buffer is
  built explicitly). Previously (probe 30) this was only ever called
  manually, alongside `HgitOffer`, never from within it.
- `src/hgit-cli/Hgit.HC`: added an `undo` branch to the `Hgit(cmdline)`
  dispatcher, calling `OpLogUndo` and reporting
  `DISPATCH_OK undo` / `DISPATCH_ERR nothing_to_undo`.
- `tools/build-package.sh`: added `src/hgit-cli/OpLog.HC` to the
  concatenation order (after `See.HC`, before `Offer.HC`). Rebuilt
  `packaging/HgitAll.HC` (59619 bytes).

## What was actually verified

`test_driver.hc`, pushed and run for real, entirely through the real
`Hgit(cmdline)` entry point (no direct hgit-core calls, no manual
`OpLogAppend`):

```
DISPATCH_OK init C:/Home/P31Repo.hgs
DISPATCH_OK offer
log_exists_after_1=1 log_size_after_1_ok=1 (size=136)
DISPATCH_OK offer
heads_differ_31=1 log_size_after_2_ok=1 (size=272)
DISPATCH_OK undo
found_after_undo_31=1 matches_head1_31=1
DISPATCH_OK undo
found_after_undo2_31=1 matches_zero_31=1
PASS oplog_wired_into_offer
```

- After the *first* `offer` alone, the `.oplog` sidecar already exists
  and is exactly 136 bytes (one entry) — proof the log write is a side
  effect of `offer` itself, not something the test triggered separately.
- After the second `offer`, it's 272 bytes (two entries) and the two
  HEAD hashes are confirmed different (byte comparison).
- Two real `Hgit("undo ...")` calls (the new dispatcher branch) walk
  HEAD back through the second commit's hash, to the first commit's
  hash, to the all-zero "no commit yet" sentinel — matching probe 30's
  direct-call result, now reproduced through the CLI entry point.

## The real story: this session's earlier "hangs" were compile errors, not hangs

Two full attempts earlier in this session's work on this same probe
produced no `D_DONE` at all after 4-11 minutes of waiting, and were
initially written up as **blocked** (see the superseded first version
of this README, and the corresponding entry logged in
`docs/research/failed-approaches.md`) with host memory pressure
flagged as a possible but unconfirmed cause.

Root cause, found by actually investigating rather than accepting the
"blocked" write-up: the stage-1 `D()` daemon's `ExePutS(Db)` has **no
compile-error capture** — that's the whole reason the devkit's own
design has a stage-2 upgrade (`D2()`/`_DRun`, using
`Fs->catch_except`) in the first place, already noted in this
project's own probe 01 README, but not connected to this failure mode
until now. A trivial hand-typed test payload
(`CommPrint(1,"SANITY_PASS...`) with a shell/Python multi-layer
escaping mistake (the same class of self-inflicted bug logged
2026-09-13 elsewhere in `failed-approaches.md`) produced exactly this
symptom on demand: the screen showed a live HolyC debugger stopped on
`ERROR: Undefined identifier` from the malformed injected string, with
no host-visible signal at all (COM1 gets nothing — the debugger has
taken over the task, so `D()`'s own `while` loop never reaches its
`CommPrint(1,"D_DONE\n")` line). Headless, with no one to dismiss the
debugger, this is indistinguishable from a true hang except by
screendump — which is exactly what this project's own established
workflow already does for anomalies, just hadn't been applied to a
"D_OK but no D_DONE" case before.

**Fix applied and now standard for this project going forward:**
before pushing anything that might legitimately fail to compile (i.e.
new/changed source, not just previously-verified re-pushes), upgrade
from the stage-1 `D()` daemon to the stage-2 `D2()` daemon
(`_DRun`/`D2` from `templeos-devkit/scripts/temple-run.py`'s
`DAEMON_V2_SOURCE`, pushed once over COM2 after `D_OK`, then
`_D_exit=FALSE;D2();` typed via sendkey — note `_D_exit` must be reset
to `FALSE` before the second call, since it was left `TRUE` to break
stage-1's loop and `D2()` checks the same variable; forgetting this
makes `D2()` exit immediately, printing `D_EXIT` right after `D2_OK`,
which was hit and fixed live in this probe). Stage-2 correctly reported
`COMPILE_OK`/`COMPILE_FAIL` for every push in this probe, including a
clean `COMPILE_OK` for both the rebuilt `hgit-core` and `hgit-cli`
chunks before the test driver ran.

**This retroactively explains, but does not retroactively confirm, the
2026-09-12 probe-28 hang** logged in `failed-approaches.md` — that
entry is left as originally written (a real question about a different
push, not re-investigated here) but now has a strong plausible
explanation on file. The two hangs *within this probe* are confirmed
by direct reproduction: this exact failure mode (silent debugger stop,
zero host signal) was deliberately triggered once with a known-bad
payload and observed to match exactly.

## Not yet done

- `redo`, `hgit operation history`, `hgit operation restore <op>` —
  still not built (unchanged from probe 30).
- Retire the stage-1-only workflow described in earlier probes' READMEs
  in favor of always bootstrapping straight to stage-2 for any probe
  pushing new/changed source — not done retroactively for probes 0-30,
  since those already have real, obtained results and don't need
  re-verification.

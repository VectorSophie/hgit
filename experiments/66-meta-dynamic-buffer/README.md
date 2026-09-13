# Probe 66 — `Meta.HC`'s silent data-loss bug: worse than a crash, found and fixed

Status: **PASS** — finds and fixes a genuinely more severe bug class
than every prior fixed-buffer probe this project has done (55, 56, 60,
61, 62): this one produced **zero error signal at all**, silently
losing real user data instead of crashing.

## Why this was checked

After probes 60-62 closed out every known fixed-size-buffer overflow
in `Offer.HC`/`See.HC`/`History.HC`/`HistoryDoc.HC`/`Status.HC`/
`ReconcileDoc.HC` (all built around `Index.HC`'s hash→offset lookup),
`Meta.HC` itself - the single most load-bearing shared file in the
whole system, underneath every real command via `Paths.HC`/`OpLog.HC` -
was independently audited and found to have the *exact same*
`read-whole-file, rebuild-in-a-fixed-buffer, write-whole-file` pattern
in **nine** of its own functions (`MetaWriteHead`, `MetaPathDeclare`,
`MetaPathUndeclare`, `MetaCurrentSet`, `MetaOpLogAppend`,
`MetaOpLogPopLast`, `MetaRedoLogAppend`, `MetaRedoLogPopLast`,
`MetaRedoLogClear`), each with its own `U8 new_buf[16384]`.

## Real reproduction: a 150-offer stress test, logging the `.m` file's own size

Ran 150 ordinary `hgit offer` calls in a row, `FileRead`-ing
`<repo>.hgs.m`'s own real size before every 10th one to bisect
precisely (same technique as probes 60/61). Growth is steady, ~144
bytes/offer (one `MetaWriteHead` HEAD-record replace plus one
`MetaOpLogAppend` entry). At `i=140`, the file was already at 16,516
bytes - past the fixed 16384-byte buffer.

**Every single one of the 150 offers still reported `DISPATCH_OK` -
no crash, no error, nothing visibly wrong.** This is what made the bug
worth chasing down independently rather than assuming "it must be
fine, nothing crashed."

## The real damage, confirmed by direct verification (not assumed)

A follow-up script read the file's final size and independently
counted real operation-log entries (`MetaOpLogCount`) and checked
`HEAD`:

```
FINAL_META_SIZE=16516
OPLOG_COUNT=115 (expect 150)                          <- 35 lost, silently
SEE_COMMIT ts=... msg=offer_number_113                <- HEAD stuck 36 offers behind
```

35 of 150 real user operations were silently never recorded, and
`HEAD` silently stopped advancing partway through - a user calling
`hgit offer` 150 times would see `DISPATCH_OK` every single time and
have no way to know a third of their history was gone until they
happened to check `hgit operation history`'s count or noticed `hgit
see`/`HEAD` pointing at a stale commit. **This is a materially worse
failure mode than every prior crash-based bug in this project** - a
GPF is loud and undeniable; this was silent and would have shipped
undetected if this stress test hadn't been run.

## The fix

Same pattern as ADR 0007, applied to all nine functions: `new_buf` is
now `MAlloc`'d from the existing file's real size (already known from
`FileRead`) plus a small `META_BUF_HEADROOM` (1024 bytes - generous for
any single record this file ever appends, the largest being a 136-byte
oplog/redolog payload plus a name/tag/len header), freed on every exit
path (including the early-return paths in `MetaOpLogPopLast`/
`MetaRedoLogPopLast` when nothing matched).

## Verified

Rebooted the VM fresh and pushed the rebuilt package as the first
source compiled that session - clean compile
(`serial-log-after-fix.txt`). Re-ran the identical 150-offer stress
test against the **same already-past-the-old-ceiling repo** left over
from the pre-fix run (started at 16,516 bytes - a harsher continuation,
not a fresh-start retest) - grew cleanly and continuously to 37,966
bytes with `PASS p66_meta_bisection_done`, no crash, no stall anywhere
in the growth log (`BEFORE_OFFER` entries every 10 offers up through
`i=140`, all steady ~144 bytes/offer, no gap or plateau like the
pre-fix run showed).

Verification after the fix: `OPLOG_COUNT=265` - which is **exactly**
115 (the pre-fix run's surviving entries) + 150 (this run's full,
now-correctly-recorded 150) - full accounting, zero further loss.
`HEAD` correctly resolves to `offer_number_149`, the real last commit
of this run, not stuck partway through. Also re-ran probe 65's full
command-surface regression (`init`/`offer`/`undo`/`redo`/`path new`/
`path go`/`history`/`status`/`check`/`historydoc`/`see`) against a
separate repo - all still correct, confirming no regression to the
normal case.

## What this means for the project's own standing practice

Every prior fixed-buffer probe in this project produced a loud,
visible failure (a GPF, or - probe 56's other case - a hang). This is
the first confirmed case of a **silent** failure from the same root
cause (a fixed-size rebuild buffer not scaling with real growth) -
worth remembering as a standing lesson: a command reporting
`DISPATCH_OK` is not, by itself, proof that its effect was actually
correctly persisted at scale. Real corpus-scale testing (not just
"did it crash") is the only way this class of bug surfaces.

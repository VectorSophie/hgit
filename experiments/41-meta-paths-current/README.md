# Probe 41 — Meta.HC's path-list/current-path slice, PASS (after finding a real reserved-identifier trap: `pi`)

Status: **PASS**, real, on real TempleOS under QEMU
(`serial-log-passing-run.txt`, `evidence-pass.png`). Completes ADR
0003's combined-metadata-file design for every concern `Paths.HC`'s
sidecars used to hold (HEAD in probe 40; path declaration/listing and
current-path here) — still standalone, not yet wired into any real
command.

## What was added

`src/hgit-core/Meta.HC` gained three tags/concerns on top of probe 40's
`MetaReadHead`/`MetaWriteHead`:
- `META_TAG_PATH_DECLARED` — `MetaPathExists`/`MetaPathDeclare`
  (idempotent)/`MetaPathList`, mirroring `Paths.HC`'s `.paths` file.
- `META_TAG_CURRENT` — `MetaCurrentGet`/`MetaCurrentSet`, mirroring
  `Paths.HC`'s `.currentpath` file. Uses `name_len == 0` (a "global,"
  not-per-path record) rather than a special-cased path name.

Refactored the shared scan/splice logic behind two primitives every
public function is now built from: `MetaFind` (last-match-wins scan,
returns a byte **offset** into the caller's buffer rather than a
pointer-to-pointer out-parameter — see below) and `MetaSpliceOut`/
`MetaAppendRecord` (probe 40's pattern, now reused instead of
duplicated per concern).

## Two real bugs found and fixed, both root-caused (not guessed at)

**1. A pointer-to-pointer out-parameter doesn't parse.** The first
draft of `MetaFind` used `U8 **payload_ptr` to hand back a pointer into
the scanned buffer — a syntax shape never used anywhere else in this
project. It failed to compile (`Duplicate member`, actually a red
herring from cascading parser confusion, not this bug directly — found
by then hitting the REAL bug below first). Fixed by having `MetaFind`
return the payload's byte **offset** (an `I64`) instead, letting the
caller compute `buf + offset` itself — avoids the untested syntax
shape entirely.

**2. `pi` is a reserved TempleOS identifier — using it as a local
variable produces a bizarre, misleading parse error.** After the
offset-based fix, one specific function (the loop copying a record's
name into a temporary buffer) still failed, reproducibly, with:

```
&LexExcept PrsType PrsVarLst PrsStmt ERROR: Expecting '*' at "INT:400921FB54442D18"  (0x400921FB54442D18(F64))
```

This looked like session pollution at first (an intermittent "Fun
header args mismatch" warning appeared alongside it on some retries)
and cost several fresh-reboot cycles to rule that out - the error
reproduced identically even as the very first, only-ever push of a
brand-new, never-before-used function name on a truly clean boot,
proving it was real, not stale state. Bisecting the function body down
to a two-line minimal repro (`U8 buf[64]; I64 pi; for (pi=0; pi<3;
pi++) buf[pi] = 'x';`) and then renaming just the loop variable to
`qi` made it compile instantly - isolating the cause to the identifier
`pi` itself. **The mystery hex constant in the error message,
`0x400921FB54442D18`, is exactly IEEE754 double-precision π** — proof
TempleOS predefines `pi` as a real global `F64` constant, and a local
variable declared with that same name collides with it, producing this
specific, otherwise-baffling parse error rather than a clean
redeclaration error. Fixed by renaming the loop variable to `ni`.

This is a genuine, previously-undocumented HolyC reserved-identifier
trap, now recorded in `docs/research/01-templeos-holyc.md`.

## What was verified (after both fixes)

`test_driver.hc`, calling `Meta.HC`'s functions directly (not yet
through any dispatcher, since none of this is wired into `Hgit.HC`
yet):

```
main_exists_before=1 feature_exists_before=0 cur0=main
PATH main
feature_exists_after=1
PATH main
PATH feature
cur1=feature cur1_is_feature=1
cur2=main cur2_is_main=1
never_declared_exists=0 (expect 0)
PASS meta_paths_current
```

- `"main"` always reports as existing without ever being stored;
  `"feature"` correctly reports absent before it's declared.
- `MetaPathList` on a fresh repo shows only `main`.
- After `MetaPathDeclare(repo, "feature")` (called **twice**,
  deliberately, to test idempotency), `MetaPathExists` reports it
  present and `MetaPathList` shows exactly `main` + `feature` once
  each — not duplicated.
- `MetaCurrentSet`/`MetaCurrentGet` round-trip correctly in both
  directions (`main` → `feature` → `main`).
- A path name never declared correctly reports absent.

## Not yet done

- Still standalone: `Head.HC`/`Paths.HC`/`OpLog.HC` and every real
  command/probe (30-39) still use today's separate-sidecar-file
  layout. Migrating them onto `Meta.HC` — and moving the operation-log/
  redo-log entries into it too — is the remaining work for ADR 0003.

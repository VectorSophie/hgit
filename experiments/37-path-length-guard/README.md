# Probe 37 — proactive path-length guard on `hgit path new`, PASS

Status: **PASS**, real, on real TempleOS under QEMU
(`serial-log-passing-run.txt`, `evidence-pass.png`). This is the
concrete mitigation flagged as "remaining M2 work" after probe 36
found the real 33-character full-path ceiling — turning that silent
failure into an honest, immediate error at `path new` time.

## What changed

`src/hgit-cli/Paths.HC`: `PathNameFits(repo_path, name)` computes
`StrLen(repo_path) + 6 + StrLen(name)` (6 being the width of the
`.head.` tag — the widest of the three per-path sidecar suffixes this
project uses; `.head.` at 6 chars is wider than `.ol.`/`.rl.` at 4, so
checking against it covers all three) and compares against
`HGIT_MAX_SAFE_PATH_LEN` (33, probe 36's measured real ceiling).
`PathNew` now calls this before doing anything else — a path name that
would push its own HEAD file past the limit is refused outright,
rather than "succeeding" into a path whose HEAD can never actually be
written or read back (exactly the failure mode probe 36 diagnosed the
hard way).

## What was verified

`test_driver.hc`, using a short repo path (`C:/Home/P37.hgs`, 15
chars) so the 12/13-character name boundary lands exactly where the
math predicts (`15 + 6 + 12 = 33`, `15 + 6 + 13 = 34`):

```
DISPATCH_OK init C:/Home/P37.hgs
fits_ok=1 (expect 1)
overflow_refused=1 (expect 1)
overflow_not_listed=1 (expect 1)
PASS path_length_guard
```

- A 12-character name (total path exactly 33, the measured-good
  boundary) is correctly **accepted**.
- A 13-character name (total path 34, the measured-bad boundary) is
  correctly **refused** by `PathNew` itself — not by some later,
  confusing failure to read the HEAD file back.
- The refused name is confirmed **not** present in the path list
  afterward (`PathExists` returns `FALSE`) — no partial/orphaned state
  left behind by the refused attempt.

## Scope, honestly

This is a guard on the symptom nearest to the user (a bad `path new`
call fails loudly and immediately), not the underlying architectural
fix. It doesn't help a repo whose *own* path is already so long that
even `main`'s existing sidecar files (`.head`, `.oplog`, `.paths`,
`.currentpath` — none of which include a per-path name suffix) are
themselves at risk, and it doesn't reduce the fundamental ceiling any
sidecar-file-per-concern design faces. That remains flagged in
`docs/research/01-templeos-holyc.md`'s "Path length limit" section for
a future ADR.

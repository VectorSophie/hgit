# Probe 26 — `see` wired into the dispatcher, real TempleOS (a messy-session detour, then a clean pass)

Status: **PASS on the clean, well-organized push.** All five M1 commands
(`init`, `status`, `history`, `see`) except `offer` are now dispatched
through `Hgit(cmdline)`, the single string-based entry point.

## A messy-session detour (not a new HolyC bug — a self-inflicted mess)

The first attempt reused an already-running daemon session across
several pushes, re-including some files (`hex_test.hc`, `Init.HC`
missing then added) inconsistently between pushes. Result: one push hit
a real compile error (`Compiler Parse Error at 'HgitInit'`, because
`Init.HC` had been left out of that particular concatenation — a plain
missing-dependency mistake, same class as probe 20's). After fixing
that, a *second* push compiled cleanly but produced **no output at all**
from the new test code, with no error either — most likely from
redefining several already-loaded top-level test variables/functions
a second time in the same long-lived daemon session in an inconsistent
order. Not fully root-caused, and not worth chasing: rather than keep
debugging session-state ambiguity, the fix was to reboot to a clean
slate and push one well-organized file with every dependency included
exactly once — the standing discipline every other probe in this
project already follows, temporarily skipped here for speed and paid
for immediately. `messy_session_attempt.hc` is kept for the record;
`tested_source.hc` is the actual clean pass.

## What was tested, on the clean pass

Against the real repository from probes 18–25, via `Hgit(cmdline)` only
(the string dispatcher, not direct function calls):

```
--- see via dispatcher, real HEAD hash ---
SEE_COMMIT ts=2000 parents=1 msg=second
SEE_TREE entries=2
  entry type=1 name=OfferFileA.txt
  entry type=1 name=OfferFileB.txt
SEE_END
--- see via dispatcher, garbage hash ---
DISPATCH_ERR bad_hash notarealhash
--- unknown command still handled ---
DISPATCH_ERR unknown_command frobnicate
```

`Hgit("see C:/Home/OfferTestRepo.hgs <128-char-hex-of-HEAD>")` produced
identical output to calling `HgitSee` directly (probe 22) — confirming
the dispatcher composition, including hex parsing, adds no behavior
change.

## Landed as real hgit-cli source

`src/hgit-cli/Hgit.HC` — `see` branch added (using a distinctly-named
`see_p`/`see_repo_path`/`see_hex`/`see_hash`, applying probe 24's
scoping lesson preemptively rather than rediscovering it). Logic
byte-for-byte identical to the tested version (confirmed via diff).

## Not yet done

- **`offer` is the last unwired command** — free-text message field and
  a timestamp source, the two pieces deliberately deferred since
  probe 23. With this probe, it's the only one left.
- The messy-session failure mode (silent no-output after a clean
  compile, from redefinition ordering across pushes in one long daemon
  session) is worth a name but not yet a root cause — flagged here as a
  reason to prefer clean, single, complete pushes over incremental
  redefinition within one session, not fully explained.

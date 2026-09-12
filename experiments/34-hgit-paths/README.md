# Probe 34 — named paths (`hgit path list/new/go/close`), PASS

Status: **PASS**, real, on real TempleOS under QEMU
(`serial-log-passing-run.txt`, `evidence-pass.png`).

Also surfaced and fixed a second real infra reliability issue in this
project's own test harness — see below — distinct from probe 31's
stage-1-error-capture finding.

## Design

`src/hgit-cli/Paths.HC` (new): "main" is the implicit default path —
always exists, never stored anywhere, and its HEAD is exactly
`<repo_path>.head` (byte-identical to every prior probe, so nothing
that never touches paths is affected). Any other path's name lives in
a flat `<repo_path>.paths` list ([U8 name_len][name] entries, read
until EOF); its HEAD lives at `<repo_path>.head.<name>`. The "current
path" is tracked in `<repo_path>.currentpath` (raw name bytes, no
NUL/length prefix; missing means "main").

Deliberately minimal / not yet done: this is bookkeeping only.
`path new`/`path go`/`path close` don't yet change what `offer`/
`status`/`history`/`see`/`undo`/`redo`/`operation history` operate on —
those all still hardcode "main"'s `.head` file via `Head.HC`. Wiring
"whichever path is current" into those commands is the natural next
step, not done here — same incremental pattern this project used for
`OpLog.HC` (built standalone in probe 30, wired into `Offer.HC` in
probe 31).

`Hgit.HC` gained a `path` top-level branch (like `operation`) that
extracts a second-word sub-command, then that sub-command's own args.

## What was verified

`test_driver.hc`, through the real `Hgit(cmdline)` dispatcher:

```
DISPATCH_OK init C:/Home/P34Repo.hgs
PATH main
DISPATCH_OK path_list
DISPATCH_OK offer
main_head=75e707bc...230d9ba
DISPATCH_OK path_new feature
feature_head_exists=1 feature_head_matches_main=1
DISPATCH_ERR path_new_failed feature
PATH main
PATH feature
DISPATCH_OK path_list
DISPATCH_OK path_go feature
current_after_go=feature
DISPATCH_ERR path_go_failed doesnotexist
current_unchanged_after_bad_go=1
DISPATCH_ERR path_close_failed main
main_still_exists=1
DISPATCH_OK path_close feature
feature_gone=1 current_reset_to_main=1
PATH main
DISPATCH_OK path_list
PASS hgit_paths
```

- `path new feature` on a repo with a real commit correctly copies
  main's actual HEAD hash byte-for-byte into `feature`'s own head file.
- Recreating an existing path (`feature` again) is correctly refused.
- `path list` correctly shows both `main` and `feature` after creation,
  and only `main` again after `feature` is closed.
- `path go feature` switches current path; going to a nonexistent path
  is refused and leaves the current path unchanged (checked directly,
  not assumed).
- `path close main` is refused (main can never be closed).
- `path close feature` (the *current* path) succeeds and resets current
  back to `main`, and `feature` is confirmed gone from `PathExists`.

## A second real infra bug found and fixed this probe: unpaced large pushes can drop bytes

While pushing the ~46KB `hgit-cli` chunk (reusing the same long-lived
stage-2 session from probes 31-33), a single push took **over 10
minutes** with no result — the first time in this project that stage-2
itself (which should report `COMPILE_OK`/`COMPILE_FAIL` quickly) seemed
to hang. A fresh reboot was done to rule out session degradation, and
the same push (now via a single unpaced `sendall()` of the whole file)
appeared to succeed based on a `tail` check — but that check read stale
output from an *earlier* push, and the actual chunk's compile was still
in progress. Immediately pushing the next payload (`test_driver.hc`)
while that was true produced a **combined, garbled compile**: warnings
from functions early-to-mid in the cli chunk (`Paths.HC` through
`See.HC`), followed immediately by `test_driver.hc`'s own first
statement failing as `ERROR: Undefined identifier at "("` on the
`Hgit(...)` call — with no `COMPILE_OK`/`COMPILE_FAIL` for the cli
chunk in between. This means the cli chunk's own trailing EOT byte
(`0x04`) was never received by the guest; its bytes and the next
push's bytes were treated as one continuous stream.

The 46KB file itself was confirmed clean (no stray `0x04` byte inside
it - checked directly). The likely cause: a single large unpaced
`sendall()` over the emulated serial line, under the same host memory
pressure logged elsewhere this session, can have bytes dropped somewhere
in the QEMU chardev/guest UART path before they reach the guest's
software FIFO - a real, distinct reliability gap from probe 31's
compile-error-capture finding, not a re-diagnosis of it.

**Fix, now standard practice for any push over ~10KB:**
`experiments/01-temple-repl/paced_push.py` - sends the file in small
(2KB) pieces with a short delay between each, rather than one call.
Re-pushing the identical 46KB cli chunk with this script produced a
clean, fast `COMPILE_OK` on the very next attempt.

## Not yet done

- Wiring "current path" into `offer`/`status`/`history`/`see`/`undo`/
  `redo`/`operation history` so switching paths actually changes what
  those commands see - currently they all still operate on `main`
  regardless of the current path.
- `PathClose` doesn't delete the closed path's orphaned `.head.<name>`
  sidecar file (real `Del()` exists per prior research but wasn't
  exercised here - kept out of scope).
- No merge/reconciliation between paths - this is pure bookkeeping,
  no notion yet of what it means to bring two paths' work together.

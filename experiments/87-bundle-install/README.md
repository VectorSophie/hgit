# Probe 87 — a real, self-contained TempleOS+hgit bundle, and two real bugs found building it

Status: **PASS**, plus two genuine, previously-undiscovered findings
about running hgit *outside* this project's own dev daemon session -
every prior probe in this entire project tested exclusively through
that daemon, which (as it turns out) was silently doing two real
prerequisites for hgit that a truly bare TempleOS session doesn't get
for free.

## What was built

A completely fresh TempleOS 5.03 install (`qemu-img create` + the
official ISO + the same scripted install-answer sequence
`experiments/00-qemu-boot/`/`01-temple-repl/` first proved), separate
from this project's own long-lived dev disk - no accumulated probe
cruft, no daemon pre-bootstrapped. `packaging/HgitAll.HC` (the current
release build) was saved onto it as a real file at
`C:/Home/HgitAll.HC`, using the exact same "combined push" technique
`experiments/28-hgit-package/` found necessary (append a small
`FileWrite`-from-a-stable-copy trailer to the same push, since a
follow-up push overwrites the daemon's own receive buffer before it
can be saved from) - confirmed byte-for-byte (`SAVED2 200370`, matching
the real local build's own size).

The disk was then compressed for distribution
(`qemu-img convert -c`, 64.5 MiB → 43.2 MiB) and re-verified booting
and running hgit correctly *after* compression - not assumed safe.

## Two real bugs found, only visible once daemon-inherited setup was removed

Every single probe before this one tested hgit exclusively through
this project's own dev daemon (`experiments/01-temple-repl/`'s
`D()`/`D2()`), whose own bootstrap sequence does several things a
plain, bare TempleOS session does not. Testing a genuinely bare
session - the actual real-user experience - surfaced two real,
reproducible problems `INSTALL.md`'s previous instructions didn't
account for:

### 1. Plain `#include` of `HgitAll.HC` fails partway through; `ExePutS` of the identical bytes does not

Typing `#include "::/Doc/Comm";` then `#include "C:/Home/HgitAll.HC";`
at a bare `C:/Home>` prompt produces a real compiler parse error
(`Compiler Parse Error at '\n'`, citing a line deep in the file) -
confirmed reproducible on a **completely fresh** boot (ruling out
session-state/redefinition fatigue, `experiments/28`'s own
previously-documented flaky-failure class): same error, same class,
on two independent fresh sessions.

Bisection: stripping all comments from the package (200,370 → 102,979
bytes) still fails via `#include`, just at a different, earlier line -
ruling out "cumulative comment volume" as the cause and pointing at a
real size-dependent limit in `#include`'s own file-loading path
specifically (not `ExePutS`'s). Both failing lines, in both file
variants, are long-established, previously-verified-correct code
(`ReconcileDoc.HC`'s own byte-append loops, unchanged since probes
55-59) - not a real syntax defect in hgit's own source.

**The fix**: `I64 sz;U8 *b=FileRead("C:/Home/HgitAll.HC",&sz);ExePutS(b);`
instead of `#include`. Confirmed working on a fresh boot: the entire
~200KB file compiles cleanly (only benign "using 64-bit register"/
"unused var" warnings, the same class `tools/lint-package.sh` already
tolerates), returns to a clean prompt.

Root cause not fully isolated (would need tracing `#include`'s own
compiler-internals path, `D:/Compiler/CMain.HC.Z` per probe 76's own
finding of readable compiler source - not attempted here, a real
concrete next step for whoever picks this up). Logged as a genuine,
reproducible discrepancy between two TempleOS source-loading
mechanisms, not glossed over.

### 2. Any real hgit command needs `CommInit8n1(1,115200);` first, or it GPFs

Once loaded (via the `ExePutS` workaround above), calling
`Hgit("version");` produced a **real kernel General Protection fault**
(`Fault:0x0D`, `RIP` inside `FifoU8Ins`) - because `comm_ports[1]`'s
FIFO was never initialized in this bare session. Every prior probe's
own daemon bootstrap always ran `CommInit8n1(1,115200);` (alongside
port 2, for its own COM2 injection channel) before ever calling
anything that used `CommPrint(1, ...)` - which is every single hgit
command's own output mechanism - masking this real prerequisite for
the whole project's history.

**The fix**: `CommInit8n1(1,115200);` once, before loading hgit.
Confirmed: with this one line added, the identical load-then-run
sequence works cleanly - `hgit version`/`hgit help` both correct, then
a full real `init`→`offer`→`history` sequence confirmed correct too
(`DISPATCH_OK`/`DISPATCH_OK`/`HISTORY_END shown=1`) on the same fresh,
bare, no-daemon session.

## The real, verified bare-session bootstrap (3 lines)

```c
#include "::/Doc/Comm";
CommInit8n1(1,115200);
I64 sz;U8 *b=FileRead("C:/Home/HgitAll.HC",&sz);ExePutS(b);
```

After this, `Hgit(...)` works exactly as documented in the main
README - verified with `version`/`help`/a real `init`/`offer`/`history`
sequence, all on one truly fresh boot with zero dev-daemon setup.

## The launcher

`packaging/bundle/hgit-launch.py` automates the boot-menu navigation
(select Drive C, dismiss "Take Tour?") and this exact 3-line sequence
via QEMU monitor keystroke injection (the same technique
`experiments/templeos-devkit/scripts/send.py` already uses, verified
compatible by cross-checking its own real `KEYMAP`/`SHIFT_MAP` tables
character-for-character rather than reconstructing from memory), then
hands the now-loaded, real QEMU window to the user - no host-side
wrapper pretending to be a native CLI, just real TempleOS with hgit
ready, which is what "runs on Windows/Linux independently" honestly
means for a TempleOS-native tool.

## Evidence

- `evidence/install-dance/shot1-5.png` — the scripted fresh-install
  sequence (blank disk + official ISO): "Install onto hard drive?",
  "installing inside a VM?", the freeze warning, real file copying,
  "Reboot Now?".
- `evidence/final-boot-and-save/boot1-5.png` — the first persistent-
  disk boot: bootloader drive-select, "Take Tour?", the daemon
  bootstrap that saved `HgitAll.HC` onto the disk as a real file.
- `v1.png` — a fresh reboot's own directory listing, showing
  `HgitAll.HC` really present on disk (not just compiled in memory).
- `v2.png` — bug 1's first symptom: plain `#include` fails on
  `CommPrint` being undefined (missing `::/Doc/Comm`).
- `v3.png`/`v4.png` — bug 1 itself, reproduced on two independent
  fresh boots: the real `Compiler Parse Error` deep in the file.
- `v6.png` — the fix for bug 1 working: the same ~200KB file compiling
  cleanly via `ExePutS(FileRead(...))`.
- `v7.png` — bug 2: the real kernel General Protection fault inside
  `FifoU8Ins` from calling `Hgit("version")` with COM1 uninitialized.
- `v8.png`/`verify-final-serial.log` — the complete real fix verified:
  `hgit version`/`hgit help` both correct on a fresh, bare session.
- `final-serial.log`/`diag-serial.log`/`diag3-serial.log`/
  `compcheck-serial.log` — the real COM1 output backing each step
  above, including the final real `init`→`offer`→`history` sequence
  and the post-compression re-verification.
- `v9.png` — a dead-end tangent (checking whether `Once` resolves to a
  real, discoverable startup-script file for auto-loading hgit at
  boot; it didn't turn up anything, not pursued further, not a
  blocker) - included for completeness, not because it shows anything
  conclusive.

## Not yet done

- The launcher's own boot-menu-timing/keystroke sequence was verified
  against the same disk on this Linux/QEMU host in headless
  (`-display none`) mode; the launcher itself omits that flag (a real
  visible window is the point) - QEMU's display backend choice doesn't
  affect the emulated boot sequence's own timing, but the launcher's
  end-to-end run *with a real window* wasn't itself re-verified in
  this probe (would need a real windowed test).
- Not tested on real Windows or macOS - this project's own environment
  is Linux-only. The project owner's own upcoming Windows test is the
  first real cross-platform verification.
- `#include`'s own real size limit wasn't pinned to an exact byte
  threshold, just narrowed (fails between ~103KB and ~200KB,
  content-position-dependent, not purely comment-volume-dependent).
- No Chocolatey/Homebrew/apt packaging yet - this probe is the
  bundle itself; wrapping it in each platform's own package manager
  format is separate, real follow-up work.

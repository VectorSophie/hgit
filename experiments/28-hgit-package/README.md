# Probe 28 — hgit as a single `#include`-able package, real TempleOS

Status: **PASS after two real debugging detours.** Every prior probe
manually concatenated ~16 source files by hand on the host before
pushing. This probe proves that's not required in the actual product:
one combined file, transferred to a real TempleOS disk once, is loadable
with a single `#include` — matching `Doc/CmdLineOverview.DD`'s own
stated convention ("To run a program, you typically `#include` it").

## Design

`tools/build-package.sh` concatenates every `src/hgit-core/` and
`src/hgit-cli/` file in dependency order into `packaging/HgitAll.HC`.
This is the actual distribution artifact this milestone was after — not
a test-only concatenation, a real, scripted, reproducible build step
(the first thing to live in the previously-empty `tools/`/`packaging/`
directories).

## Getting the file onto the TempleOS disk itself was its own small puzzle

The straightforward idea — push the combined package, then push a
follow-up `FileWrite(path, Db, len)` to save it — **failed silently**:
every push reuses the daemon's own receive buffer (`Db`) starting at
byte 0, so a follow-up push overwrites the very bytes it's trying to
save before the write happens. Fixed by copying `Db`'s content into a
separately-`MAlloc`'d, stable buffer *within the same push* that defines
everything, then `FileWrite`-ing from that stable copy.

The first attempt at *that* fix still failed (`Undefined identifier` on
the copy buffer) because the buffer's `U8 *hgit_pkg_saved = MAlloc(...)`
declaration came *after* the function that used it in the pushed
source — confirming (once more) that HolyC processes top-level
declarations sequentially, not via a two-pass "collect everything, then
check bodies" scheme.

After fixing the ordering, a **second, different failure** appeared:
compile errors inside `Canon.HC`'s `PutU32LE` — a function that has
compiled cleanly in dozens of pushes across probes 03–27. This was the
*fourth* consecutive redefinition of the entire ~54KB/16-file package
within one daemon session. Rebooting to a completely clean session and
pushing the identical, already-fixed source **once** worked immediately
(`SAVED`, file confirmed on disk at the exact expected size,
`54379` bytes). Whether this is redefinition-count fatigue in the JIT,
memory fragmentation from repeated large `MAlloc`s, or something else
wasn't further diagnosed — logged as an open question, not a resolved
one.

## The actual test, after landing the file on disk

Fresh VM reboot. Bootstrapped the daemon. Pushed **only**:

```
#include "C:/Home/HgitAll.HC";
Hgit("status C:/Home/OfferTestRepo.hgs C:/Home/OfferFile* C:/Home/");
```

Result:
```
STATUS_NEW OfferFileA.txt
STATUS_NEW OfferFileC.txt
STATUS_END
```

Correct output (matching the real state of those files from prior
probes) — proving the *entire* hgit toolchain loaded from one
`#include`, in a session that never directly pushed any of the
individual source files.

## Landed as real infrastructure

`tools/build-package.sh` (the build script) and `packaging/HgitAll.HC`
(its output, checked in as the current build so the repository always
has a ready-to-copy artifact, regenerated whenever `src/` changes).

## Not yet done

- Only tested loading via the QEMU COM2 injection channel, not by
  actually copying the file onto a disk image through some other
  transport and `#include`-ing it from the interactive keyboard/screen
  session a real user would use.
- No `.HC.Z` compression tested for the package (TempleOS's own
  convention for most shipped files) — plain `.HC` was sufficient here.
- The "redefinition fatigue after several large pushes" symptom is
  real but not explained — worth remembering if a future probe hits an
  unexplained compile error deep inside long-stable code: try a clean
  reboot before assuming new code is at fault.

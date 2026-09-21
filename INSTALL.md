# Installing hgit

TempleOS has no package manager, no installer, and no argv-based
executable convention (confirmed from primary source,
`Doc/CmdLineOverview.DD` — see `docs/research/01-templeos-holyc.md`
and `docs/research/09-packaging-and-releases.md`). A "program" is run
by loading its source file at the live TempleOS command line.
Installing hgit means getting one file, `HgitAll.HC`, onto your
TempleOS machine and loading it — see step 3 for the exact, real,
verified sequence (it's not a plain `#include` — that fails for a file
this size; `experiments/87-bundle-install/` has the full story).

> Want hgit on Windows, macOS or Linux **without** TempleOS? See the native port,
> [hgit-native](https://github.com/VectorSophie/hgit-native) (in development, not
> yet installable). This document covers the TempleOS version.

## Fastest path: the pre-built bundle

Don't have a TempleOS machine yet? `packaging/bundle/` (built from
this same repo) is a real, fresh TempleOS install with hgit already
saved onto it, plus `hgit-launch.py` — a small script that boots it and
runs the load sequence below automatically, landing you at a ready
`C:/Home>` prompt. See `packaging/bundle/README.md`. Requires QEMU and
Python 3 on your host; the disk image itself is TempleOS, so it runs
identically on Windows, Linux, and macOS.

The rest of this document is for loading hgit onto your *own* existing
TempleOS install instead.

## 1. Get the file

Download `HgitAll.HC` from the latest release:

<https://github.com/VectorSophie/hgit/releases/latest>

Each release attaches `HgitAll.HC` — a single self-contained
concatenation of every `hgit-core`/`hgit-cli` source file, in
dependency order (`tools/build-package.sh`; see
`experiments/28-hgit-package/` for the original verification that this
loads and runs correctly on real TempleOS — via the daemon-injection
mechanism that project used throughout; a plain `#include` of the
current, larger build does not work, see step 3 below).

## 2. Get it onto your TempleOS machine

This is the step TempleOS itself has no built-in answer for — there is
no package manager or network install path this project has verified
(ZealOS's own networking stack is still immature; see
`docs/research/03-zealos-and-networking.md`). What this project has
actually verified, end-to-end, repeatedly, across every one of its
probes:

**Serial (COM2) transfer** — the mechanism this whole project's own
QEMU-based development loop uses. From a host that can reach your
TempleOS machine's serial port (a real null-modem/USB-serial cable on
real hardware, or a QEMU `chardev` socket for a VM), pipe the file's
raw bytes to COM2 in small paced chunks, terminated with a single EOT
byte (`0x04`); TempleOS's own `ExePutS`/`D2()`-style receive loop reads
and compiles it. This project's own `experiments/01-temple-repl/paced_push.py`
is a working reference implementation — see its own README
(`experiments/01-temple-repl/README.md`) for the exact protocol and
the pacing rationale (an unpaced single send can silently drop bytes
under host memory pressure — a real bug this project hit and fixed,
`docs/research/failed-approaches.md`).

**Other real-hardware options that follow directly from TempleOS's own
disk model, but are not independently verified by this project**:
copying the file onto a real USB drive or burned CD/floppy and reading
it from whatever drive letter TempleOS assigns that media on your
machine, or mounting a shared/virtual drive if your hypervisor
supports one. `experiments/75-cd-media-attempt/` tried to verify a
QEMU-attached CD-ROM path specifically and did **not** get a
conclusive result (logged honestly as an open, unsolved finding, not
papered over) — so this document doesn't claim a specific drive letter
or a tested CD/USB procedure. If you get one of these working, the
project would welcome the write-up.

## 3. Run it

Once `HgitAll.HC` is on your TempleOS disk (say, `C:/Home/HgitAll.HC`),
type exactly this at the command line — **not** a plain `#include`,
which fails partway through for a file this size (a real, reproduced
finding, `experiments/87-bundle-install/`; root cause not fully
isolated, logged in `docs/research/failed-approaches.md`):

```c
#include "::/Doc/Comm";
CommInit8n1(1,115200);
I64 sz;U8 *b=FileRead("C:/Home/HgitAll.HC",&sz);ExePutS(b);
```

The first two lines are real prerequisites, not optional style: stock
TempleOS doesn't auto-load `CommPrint`/`comm_ports` (line 1), and every
hgit command prints through `CommPrint(1, ...)` — without `CommInit8n1`
initializing COM1 first (line 2), the very first hgit command you run
triggers a real kernel General Protection fault, not a graceful error.

hgit's reports go to the COM1 serial port by default (that is what its
test harness reads) - at the console you would see nothing. Turn on
on-screen output (and turn off AutoComplete, whose popup steals
digit/F-keys while typing) with:

```
Hgit("interactive");
```

Then use it like any other native TempleOS command:

```
Hgit("help");
Hgit("version");
Hgit("init C:/Home/MyRepo.hgs");
```

See `hgit help`'s own output for the full, current command list —
it's generated from the same dispatch table `Hgit.HC` actually runs,
kept in sync by hand (`experiments/73-hgit-help/`).

## What this document does not claim

- No installer, no dependency resolution, no uninstall step — none of
  these concepts apply on TempleOS (see `docs/research/09-packaging-and-releases.md`).
- No verified network-download path from inside TempleOS itself.
- No verified physical-media (USB/CD) procedure — see the CD-ROM
  attempt above for what was tried and why it wasn't pursued further.


## Package managers (v1.8.9+)

Each wraps the same bundle - QEMU + Python are the only dependencies, hgit
itself is the TempleOS disk image:

- **apt/dpkg (Debian/Ubuntu)**: `sudo apt install ./hgit_<version>_all.deb`
  (from the release page), then run `hgit`.
- **Homebrew**: `brew install VectorSophie/hgit/hgit` (tap: `VectorSophie/homebrew-hgit`).
- **Chocolatey**: `packaging/chocolatey/` holds the package sources
  (`choco pack`, then `choco install hgit -s .`); not yet published to the
  community feed.

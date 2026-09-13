# Installing hgit

TempleOS has no package manager, no installer, and no argv-based
executable convention (confirmed from primary source,
`Doc/CmdLineOverview.DD` — see `docs/research/01-templeos-holyc.md`
and `docs/research/09-packaging-and-releases.md`). A "program" is run
by `#include`-ing its source file at the live TempleOS command line.
Installing hgit means getting one file, `HgitAll.HC`, onto your
TempleOS machine and `#include`-ing it.

## 1. Get the file

Download `HgitAll.HC` from the latest release:

<https://github.com/VectorSophie/hgit/releases/latest>

Each release attaches `HgitAll.HC` — a single self-contained
concatenation of every `hgit-core`/`hgit-cli` source file, in
dependency order (`tools/build-package.sh`; see
`experiments/28-hgit-package/` for the original verification that this
loads and runs correctly via one `#include`).

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

Once `HgitAll.HC` is on your TempleOS disk (say, `C:/Home/HgitAll.HC`):

```
#include "C:/Home/HgitAll.HC";
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

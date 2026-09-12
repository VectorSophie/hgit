# Probe 00 — Does TempleOS actually boot under QEMU on this host?

Status: **PASS**. This resolves feasibility probe #6 (and the boot half of #7/#8)
from the research plan: the entire hgit project is dead on arrival if this
fails, so it went first.

## What was done

```
curl --http1.1 -C - --retry 5 -o TempleOS.ISO https://templeos.org/Downloads/TempleOS.ISO
# official mirror truncated the connection under plain curl/HTTP2 repeatedly
# (see docs/research/failed-approaches.md) — resumable-loop download worked.
sha256sum TempleOS.ISO
# 5d0fc944e5d89c155c0fc17c148646715bc1db6fa5750c0b913772cfec19ba26  (17,350,656 bytes)

qemu-system-x86_64 -cdrom TempleOS.ISO -boot d -m 512 -display none \
  -monitor telnet:127.0.0.1:4445,server,nowait \
  -serial file:serial.log -no-reboot
# then, over the HMP monitor socket: `screendump boot2.ppm`
```

QEMU version: `QEMU emulator version 8.2.2 (Debian 1:8.2.2+ds-0ubuntu1.18)`.

## Evidence

- `boot1.png` — ~8s into boot with 256MB RAM (below TempleOS's stated 512MB
  requirement banner). Shows RedSea drive detection (`B:`, `T:` = ATAPI),
  `MultiCore Start`, `Loading Compiler`. Proves the kernel boots and starts
  loading the HolyC compiler even under-provisioned.
- `boot2.png` — ~15s into boot with 512MB RAM. Shows the **fully booted live
  desktop**: two DolDoc windows, `T:/Home` directory rendered as a live
  DATE/TIME/SIZE table (not plain text — this is DolDoc doing double duty as
  a file browser), a real interactive command line
  (`T:/Home>Cd;#include "Once";`) matching `CmdLineOverview.DD.HTML`'s
  claim that the prompt is a live HolyC JIT REPL, an "Install onto hard
  drive (y/n)?" prompt (live-CD boot, as expected — no persistent disk was
  attached), and a second task showing the System Keys Quick Guide overlay
  (multitasking/windowing confirmed).

## Verified facts

- TempleOS 5.03, official ISO from templeos.org, boots correctly in
  QEMU/TCG (no KVM needed) on this Linux host with no patches.
- Minimum practical RAM is 512MB per the boot banner; 256MB boots the
  kernel but is off-spec — use 512MB+ for all future probes.
- No `-cpu`/`-machine` flags were needed; QEMU's defaults sufficed.
- Boot-to-desktop took well under 15s under emulation.

## Not yet probed (next steps for M0)

- Persistent HDD image (`qemu-img create -f qcow2 disk.qcow2 …`) + answering
  the install prompt, so state survives across runs.
- Source injection: TempleOS's own FAT32-on-secondary-IDE is documented as
  unreliable (per `templeos-devkit`'s README) — the working pattern there is
  streaming HolyC over a serial COM port into the live JIT rather than
  mounting a shuttle disk. Needs its own probe before M0 is closed out.
  A raw `-serial file:...` was attached above and left empty (nothing writes
  to COM1 by default) — next probe should attach `-serial pty` or a Unix
  socket and drive `ExePutS`-style injection plus a `Print`/pass-fail marker
  protocol from the spec's `HGIT_TEST_BEGIN`/`HGIT_TEST_EXIT` shape.
- No test harness / exit-code contract wired up yet — this probe only
  proves *boot*, not *automated test execution*.

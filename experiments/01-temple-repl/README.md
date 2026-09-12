# Probe 01 — Scripted install + COM2 source-injection round trip

Status: **PASS on the core question, one real quirk found and left open.**
This closes out the "automated QEMU control and observable test results"
half of M0 (probe 00 only proved *boot*; this proves *inject code, run it,
get a host-readable result*) — using a technique borrowed and reproduced
from `experiments/templeos-devkit` (see its `README.md`/`NOTES.md`), not
invented from scratch.

## What was done, in order

1. **Scripted install.** Blank `qcow2` + the same `TempleOS.ISO` from probe
   00, booted `-machine pc` (i440FX/IDE — TempleOS has no AHCI driver) with
   `-display none`. Drove the entire interactive installer — "Install onto
   hard drive?", "Are you installing inside QEMU?", the freeze warning,
   completion — headlessly via QEMU monitor `sendkey` + periodic
   `screendump`, no human at a console. See `evidence/01-*.png`,
   `evidence/02-*.png`.
2. **Confirmed persistence.** Rebooted from the qcow2 alone (no CD
   attached) — straight to the installed desktop. `evidence/03-*.png`.
   `sha256sum` of the post-install disk recorded in
   `evidence/disk-after-install.sha256`.
3. **COM2 wired**, matching `boot-temple.sh dev` exactly: COM1 → host file
   (`serial.log`), COM2 → Unix chardev socket (`com2.sock`) for injection.
4. **First bootstrap attempt failed** — typed the daemon ~6s after
   reaching the desktop prompt and got real TempleOS Debugger faults
   ("Still in boot phase", "Undefined identifier"). Waiting ~45–60s
   longer before typing anything made the identical commands compile
   clean. See "Quirks found" below — this isn't in the devkit's own docs.
5. **Stage-1 daemon confirmed alive**: typed `temple-run.py`'s
   `BOOTSTRAP_CMDS` verbatim via monitor `sendkey`, then `D();`. Got a
   real `D_OK` in the host's `serial.log` — evidence/04-*.png shows the
   four bootstrap commands compiling with zero errors.
6. **Real source injection, executed, result round-tripped to host**:
   pushed `CommPrint(1,"PASS hgit_probe_canonical_encoding\n");` as raw
   bytes + EOT (`0x04`) over the COM2 socket. `serial.log` on the host
   immediately showed:
   ```
   D_OK
   PASS hgit_probe_canonical_encoding
   D_DONE
   ```
   This is the brief's `HGIT_TEST_BEGIN`/`PASS ...`/`HGIT_TEST_EXIT`
   protocol shape, demonstrated for real — HolyC source went in over a
   wire, ran natively inside TempleOS, and a host process read the
   result from a plain file with no OCR, no screen-scraping, no human.
7. **Stage-2 upgrade (compile-error capture) pushed and defined
   cleanly** (`_DRun`/`D2`, third `D_DONE`) — but the handshake to
   *switch over* to it did not complete; see quirk below. Left open
   rather than debugged further, since the core question (probe
   completion, not this specific script's full feature set) was already
   answered.

## Reproduction

```sh
qemu-img create -f qcow2 vendor/templeos/disk.qcow2 4G
qemu-system-x86_64 -machine pc -m 512 -vga std -display none \
  -serial file:build/serial.log \
  -monitor unix:build/qemu.sock,server,nowait \
  -boot d \
  -drive file=vendor/templeos/disk.qcow2,if=ide,index=0,format=qcow2 \
  -drive file=vendor/templeos/templeos.iso,if=ide,index=2,media=cdrom,format=raw
# drive the installer via shot.py (screendump) + monitor sendkey ("y", "y", enter)
# then reboot with COM2 wired:
qemu-system-x86_64 -machine pc -m 512 -vga std -display none \
  -serial file:build/serial.log \
  -chardev socket,id=com2,path=build/com2.sock,server=on,wait=off -serial chardev:com2 \
  -monitor unix:build/qemu.sock,server,nowait \
  -boot c -drive file=vendor/templeos/disk.qcow2,if=ide,index=0,format=qcow2
# select "1" (Drive C) at the bootloader, WAIT ~45-60s, then type the
# BOOTSTRAP_CMDS from templeos-devkit/scripts/temple-run.py via
# templeos-devkit/scripts/send.py (QEMU_SOCK=build/qemu.sock), call D();
# then push raw HolyC + \x04 straight into build/com2.sock.
```

`shot.py` in this directory is a minimal screendump-to-PNG helper
(`python3 shot.py <monitor.sock> <out.ppm> <out.png>`).

`templeos-devkit/scripts/send.py` and the `BOOTSTRAP_CMDS`/
`DAEMON_V2_SOURCE` strings are from
`git clone --depth 1 https://github.com/rshtirmer/templeos-devkit`,
cloned into `experiments/templeos-devkit/` (gitignored here — it's a
read-only reference clone, not a dependency of hgit; re-clone to
reproduce). Full credit for the injection technique belongs there — this
probe's contribution is reproducing it fresh, against a fresh install,
on Linux/headless rather than the devkit's native macOS/Cocoa target,
and documenting where it diverged.

## Quirks found (new, not in the devkit's own notes)

1. **Typing into the REPL too soon after reaching the desktop reproduces
   the "still in boot phase" failure mode**, even at the fully
   interactive `C:/Home>` prompt, well after the bootloader — not just
   during `MakeHome.ZC`/boot-phase proper as the devkit's `NOTES.md`
   describes for the *ZealOS* path. Waiting ~45-60s (background
   dictionary-decompression / first-run housekeeping settling) made the
   *identical* keystrokes compile cleanly. **Architectural implication for
   hgit's own QEMU test harness: build in a real idle/ready detection
   (poll for a quiescent screen or a specific marker) before driving any
   input — a fixed short sleep is not reliable.**
2. **A bare top-level statement pushed through a running `ExePutS` loop
   can fail to resolve a symbol that resolves fine inside a function
   body compiled through the same mechanism.** Concretely: `_D_exit`
   (declared `Bool _D_exit=FALSE;` at the interactive top level) compiled
   fine when *referenced inside* the pushed `D2()`/`_DRun()` function
   bodies, but pushing the bare statement `_D_exit=TRUE;` on its own hit
   `ERROR: Undefined identifier`. Net effect: the stage-1→stage-2
   handshake's "exit the loop" step never fired (no `D_EXIT` marker),
   even though the stage-2 source itself defined without error. Not
   investigated further — logged in `failed-approaches.md` rather than
   chased, since it's a refinement of an already-answered feasibility
   question, not the question itself. **Possible root cause worth
   revisiting**: different identifier-resolution rules for an immediately
   -executed top-level statement vs. a deferred function body, both
   reached via `ExePutS`.

## Not yet done

- The compile-error / `COMPILE_FAIL` capture path (stage-2's actual
  purpose) — defined but never exercised against a genuinely broken
  chunk, because the handshake to switch stage-1→stage-2 didn't
  complete. Worth a dedicated retry using the devkit's own fix (if one
  exists) or `--reset-daemon`-style full reboot between stages.
  (Retry cheaply — see next line.)
- **Snapshot-based fast iteration** (`qemu-img`/monitor `savevm`/`loadvm`,
  as the devkit's `vm-warmup`/`vm-revert` does): would remove the ~1
  minute "wait for idle" tax per boot for future probes. High-value next
  step before doing repeated HolyC experiments (BLAKE2b vectors, canonical
  encoding, etc.) against a real TempleOS target.
- Restart from a fresh boot and re-run the stage-1→stage-2 handshake with
  a full reboot between the two typed commands (sidestepping the
  in-place quirk above) to actually exercise `COMPILE_FAIL`.

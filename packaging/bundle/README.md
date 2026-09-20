# hgit bundle — TempleOS + hgit, ready to run

A real, fresh TempleOS 5.03 install with `hgit` already saved onto it
(`C:/Home/HgitAll.HC`) — no accumulated dev-probe clutter, no test
repos left lying around. Boot it and hgit is one short, scripted load
away from ready. Full build/verification writeup:
`experiments/87-bundle-install/` in the main repo.

The disk image is refreshed for each release with `tools/build-bundle.py`
(it verifies the package is saved intact inside the guest via size +
checksum before compressing). `templeos-hgit.qcow2` is a large binary
(45MB) and is deliberately NOT committed to this git repo (see `.gitignore`)
- it is attached as a downloadable asset on the release matching the
`HGIT_VERSION` it carries (`hgit-bundle-<version>.tar.gz`/`.zip` also bundle it
with the launcher scripts, for the package managers).

## Getting the disk image

Download `templeos-hgit.qcow2` from the
[latest release's assets](https://github.com/VectorSophie/hgit/releases/latest)
and put it in this same folder, alongside `hgit-launch.py`.

## What you need

- **QEMU** (`qemu-system-x86_64` on your `PATH`). It's the same
  emulator on every platform:
  - **Windows**: install from <https://qemu.weilnetz.de/w64/> (the
    official Windows builds page), or `choco install qemu` if you use
    Chocolatey.
  - **macOS**: `brew install qemu`.
  - **Linux**: your distro's `qemu-system-x86_64`/`qemu` package.
- **Python 3** (already on macOS/Linux; on Windows, from
  <https://python.org> or the Microsoft Store).

Neither hgit nor this bundle needs anything else installed — the disk
image *is* the operating system.

## Run it

```sh
python3 hgit-launch.py
```

This boots `templeos-hgit.qcow2` in a real QEMU window, navigates the
one-time boot menu, and types the exact three-line sequence a bare
TempleOS session needs to load hgit (found the hard way — see
`experiments/87-bundle-install/README.md` for what that took to
verify). After ~30 seconds you'll see:

```
Ready. Switch to the QEMU window - hgit is loaded.
Try: Hgit("version"); then Hgit("help");
```

The loader also runs `Hgit("interactive");` for you: hgit's reports
normally go only to a serial port (that's what the test harness reads),
so a person at the QEMU window would otherwise see **nothing** after a
command. `interactive` echoes them to the TempleOS screen and turns
off AutoComplete (its popup steals digit/F-keys while you type). If you
load hgit by hand, run `Hgit("interactive");` first.

From there, it's real TempleOS — type HolyC directly at the prompt.
Remember there is no shell syntax: the command is `Hgit("history
C:/Home/Repo.hgs");`, not `hgit history ...`.
See the main repo's `README.md` for the full command surface, or just
run `Hgit("help");`.

### If typing directly into the QEMU window doesn't work right

A real, seen issue (2026-09-16): on some Windows setups, Shift-key
characters (`(`, `"`, `;`, ...) don't register correctly when typed
live into the QEMU window — a host keyboard layout/IME/QEMU-focus
quirk, not a TempleOS or hgit problem (the loader script's own typing,
above, demonstrably works fine with exactly those characters). If this
happens, use `hgit-type.py` — the identical, reliable keystroke-
injection mechanism the loader itself uses, aimed at your own commands
instead. **Put your commands in a text file, one per line, and use
`--file`** — a second real, seen issue (2026-09-16, Windows only):
passing HolyC containing `"` as an inline command-line argument is
genuinely unreliable there, since PowerShell/cmd's own argument
reconstruction for native `.exe` programs can silently eat embedded
quotes no matter how they're escaped. A file sidesteps shell quoting
entirely:

```text
# commands.txt
Hgit("version");
Hgit("help");
```

```sh
python3 hgit-type.py <port> --file commands.txt
```

(Inline text still works for genuinely quote-free input - almost no
real HolyC command qualifies, since even `Hgit(...)` itself takes a
quoted string, so `--file` is the real, recommended default.)

`hgit-launch.py`'s own "Ready." message prints `<port>` for that
specific running session (each launch picks a fresh one).

## Doing it by hand instead

If you'd rather drive QEMU yourself:

```sh
qemu-system-x86_64 -machine pc -m 512 -boot c \
  -drive file=templeos-hgit.qcow2,if=ide,format=qcow2
```

Select "1" at the boot menu (Drive C), answer "n" to "Take Tour?",
then at the `C:/Home>` prompt type exactly:

```c
#include "::/Doc/Comm";
CommInit8n1(1,115200);
I64 sz;U8 *b=FileRead("C:/Home/HgitAll.HC",&sz);ExePutS(b);
```

(Not a plain `#include "C:/Home/HgitAll.HC";` — that fails partway
through for a file this size, a real, reproduced finding; see the
probe writeup.)

## What this is not (yet)

This is a real, working way to run hgit on Windows/Linux/macOS today —
it is **not** a native `hgit.exe`/`hgit` binary. hgit is written in
HolyC and only runs inside TempleOS; this bundle is that TempleOS
instance, pre-loaded, plus the script that gets you to a ready prompt
fastest. The same bundle is also wrapped as a `.deb`, a Homebrew
formula and a Chocolatey package - see the main `INSTALL.md`.

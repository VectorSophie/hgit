# hgit bundle — TempleOS + hgit, ready to run

A real, fresh TempleOS 5.03 install with `hgit`'s current release
already saved onto it (`C:/Home/HgitAll.HC`) — no accumulated dev-probe
clutter, no test repos left lying around. Boot it and hgit is one
short, scripted load away from ready. Full build/verification writeup:
`experiments/87-bundle-install/` in the main repo.

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

From there, it's real TempleOS — type HolyC directly at the prompt.
See the main repo's `README.md` for the full command surface, or just
run `Hgit("help");`.

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
it is **not** a native `hgit.exe`/`hgit` binary, and not (yet) a
Chocolatey/Homebrew/apt package. hgit is written in HolyC and only
runs inside TempleOS; this bundle is that TempleOS instance, pre-
loaded, plus the one script that gets you to a ready prompt fastest.
Wrapping this bundle in each platform's own package-manager format is
real, separate follow-up work, not done here.

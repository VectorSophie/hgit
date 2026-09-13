#!/usr/bin/env python3
"""hgit-launch.py — boot the bundled TempleOS+hgit disk image and load
hgit automatically, landing at a real, ready `C:/Home>` prompt.

Requires: Python 3, QEMU (`qemu-system-x86_64` on PATH - install it
separately; see README.md in this directory for per-platform notes).

Usage:
    python3 hgit-launch.py [path/to/templeos-hgit.qcow2]

What this does, and why (each step verified on real QEMU/TempleOS,
not assumed - see experiments/87-bundle-install/ in the main hgit repo
for the full writeup):

1. Boots the disk with a REAL, visible QEMU window (not headless) -
   once loaded, you interact with TempleOS directly, the way it's
   meant to be used; this script only automates the tedious one-time
   loading sequence.
2. Selects "Drive C" at TempleOS's own boot menu, dismisses the
   "Take Tour?" prompt.
3. Types the exact three-line sequence a bare TempleOS session
   actually needs (found the hard way, testing this exact bundle,
   not copied from assumption):
     - `#include "::/Doc/Comm";` - CommPrint/comm_ports aren't
       auto-loaded on stock TempleOS.
     - `CommInit8n1(1,115200);` - without this, any hgit command that
       calls CommPrint(1, ...) - which is all of them - hits a real
       kernel General Protection fault inside FifoU8Ins. Every prior
       hgit probe worked around this by inheriting an already-
       initialized COM port from the dev daemon's own bootstrap; a
       genuinely bare session doesn't have that for free.
     - `I64 sz;U8 *b=FileRead("C:/Home/HgitAll.HC",&sz);ExePutS(b);` -
       NOT a plain `#include "C:/Home/HgitAll.HC";`. A real, reproduced
       finding: plain `#include` of hgit's own package file (~200KB)
       hits a genuine TempleOS compiler parse error partway through
       that does not occur when the identical bytes are read and run
       via `ExePutS` instead - a real discrepancy between the two
       loading paths, not a bug in hgit's own source (the exact same
       code compiles cleanly via ExePutS at this size, and via
       `#include` at smaller sizes). Root cause not fully isolated;
       logged in docs/research/failed-approaches.md. This is the real,
       verified workaround.
4. From there, the window is yours - type `Hgit("init C:/Home/MyRepo.hgs");`
   and go. See the main README.md's own "Try it" section for the
   command surface.
"""
import socket
import subprocess
import sys
import time
import tempfile
import os

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_DISK = os.path.join(HERE, "templeos-hgit.qcow2")


def monitor_cmd(sock_path, cmd, wait=0.5):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(sock_path)
    time.sleep(0.2)
    s.recv(4096)
    s.send((cmd + "\n").encode())
    time.sleep(wait)
    s.recv(4096)
    s.close()


def send_text(sock_path, text, enter=True):
    """Sends text as real keystrokes via the QEMU monitor, matching the
    same technique this project's own send.py (experiments/templeos-devkit/)
    uses - typed one key at a time (TempleOS has no bare paste)."""
    KEYMAP = {
        " ": "spc", "\n": "ret", "\t": "tab", "`": "grave_accent",
        "-": "minus", "=": "equal", "[": "bracket_left", "]": "bracket_right",
        "\\": "backslash", ";": "semicolon", "'": "apostrophe", ",": "comma",
        ".": "dot", "/": "slash",
    }
    SHIFTED = {
        "!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7",
        "*": "8", "(": "9", ")": "0", "_": "minus", "+": "equal",
        "{": "bracket_left", "}": "bracket_right", "|": "backslash",
        ":": "semicolon", '"': "apostrophe", "<": "comma", ">": "dot",
        "?": "slash", "~": "grave_accent",
    }
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(sock_path)
    time.sleep(0.2)
    s.recv(4096)
    for ch in text:
        if ch in KEYMAP:
            key = KEYMAP[ch]
        elif ch in SHIFTED:
            key = "shift-" + SHIFTED[ch]
        elif ch.isupper():
            key = "shift-" + ch.lower()
        else:
            key = ch
        s.send(("sendkey " + key + "\n").encode())
        time.sleep(0.04)
        s.recv(4096)
    if enter:
        s.send(b"sendkey ret\n")
        time.sleep(0.3)
        s.recv(4096)
    s.close()


def main():
    disk = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_DISK
    if not os.path.isfile(disk):
        sys.exit(f"error: disk image not found: {disk}")

    tmpdir = tempfile.mkdtemp(prefix="hgit-launch-")
    monitor_sock = os.path.join(tmpdir, "qemu.sock")

    print(f"Booting {disk} ...")
    subprocess.Popen([
        "qemu-system-x86_64", "-machine", "pc", "-m", "512",
        "-monitor", f"unix:{monitor_sock},server,nowait",
        "-boot", "c", "-drive", f"file={disk},if=ide,format=qcow2",
    ])

    # Wait for the monitor socket, then the bootloader's own drive-select
    # menu, then dismiss "Take Tour?" - both confirmed by real timing on
    # this exact disk (experiments/87-bundle-install/), not guessed.
    for _ in range(50):
        if os.path.exists(monitor_sock):
            break
        time.sleep(0.2)
    time.sleep(3)
    monitor_cmd(monitor_sock, "sendkey 1")  # boot drive C
    time.sleep(15)
    monitor_cmd(monitor_sock, "sendkey n")  # decline Take Tour
    time.sleep(2)

    print("Loading hgit (this takes ~20s - compiling ~200KB of real HolyC)...")
    send_text(monitor_sock, '#include "::/Doc/Comm";')
    time.sleep(2)
    send_text(monitor_sock, "CommInit8n1(1,115200);")
    time.sleep(2)
    send_text(
        monitor_sock,
        'I64 sz;U8 *b=FileRead("C:/Home/HgitAll.HC",&sz);ExePutS(b);',
    )
    time.sleep(20)

    print(
        "Ready. Switch to the QEMU window - hgit is loaded.\n"
        'Try: Hgit("version"); then Hgit("help");\n'
        "See the main hgit README.md for the full command surface."
    )


if __name__ == "__main__":
    main()

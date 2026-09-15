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
import platform
import shutil
import socket
import subprocess
import sys
import time
import os

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_DISK = os.path.join(HERE, "templeos-hgit.qcow2")

# 2026-09-16: the monitor transport was originally a Unix domain socket
# (AF_UNIX) - works on Linux/macOS, and on Windows 10 1803+ WHEN Python's
# own build was compiled with AF_UNIX support, which is not guaranteed -
# a real user's Microsoft Store Python 3.13 build hit
# `AttributeError: module 'socket' has no attribute 'AF_UNIX'`
# immediately on the first monitor command. QEMU's monitor also speaks
# plain TCP (`-monitor tcp:host:port,server,nowait`) - switched to that
# instead, since AF_INET is unconditionally available everywhere Python
# runs, not just where the OS+build combination happens to support Unix
# sockets. Bound to 127.0.0.1 only (never exposed beyond this machine).

MONITOR_HOST = "127.0.0.1"


def free_tcp_port():
    """Picks a real, currently-free TCP port by asking the OS for one
    (bind to port 0, read back what it chose, close) rather than
    guessing a fixed number that might already be in use."""
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind((MONITOR_HOST, 0))
    port = s.getsockname()[1]
    s.close()
    return port


def monitor_connect(port, tries=50):
    """Connects to the QEMU monitor's TCP port, retrying while QEMU is
    still starting up (there's no socket-file-exists check possible
    with TCP the way there was for the old Unix-socket path, so this
    retries the connection itself instead)."""
    last_err = None
    for _ in range(tries):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.connect((MONITOR_HOST, port))
            return s
        except OSError as e:
            last_err = e
            time.sleep(0.2)
    sys.exit(f"error: could not connect to the QEMU monitor on {MONITOR_HOST}:{port}: {last_err}")


def monitor_cmd(port, cmd, wait=0.5):
    s = monitor_connect(port)
    time.sleep(0.2)
    s.recv(4096)
    s.send((cmd + "\n").encode())
    time.sleep(wait)
    s.recv(4096)
    s.close()


def send_text(port, text, enter=True):
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
    s = monitor_connect(port)
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


def find_qemu():
    """Locates qemu-system-x86_64 (`.exe` on Windows - shutil.which
    resolves that via PATHEXT automatically) and exits with a real,
    actionable message instead of a raw traceback if it's missing -
    a real gap found 2026-09-15: a Windows user whose QEMU install
    hadn't updated that terminal's own PATH (a genuine, common
    Windows installer quirk - the installer can add itself to the
    system PATH, but an already-open terminal doesn't see it until
    reopened) got a bare `FileNotFoundError` from `subprocess.Popen`
    with no indication of what was actually missing or why."""
    exe = shutil.which("qemu-system-x86_64")
    if exe:
        return exe
    system = platform.system()
    if system == "Windows":
        hint = (
            "Install it from https://qemu.weilnetz.de/w64/ (or "
            "`choco install qemu`), then **close and reopen this "
            "terminal** - a terminal already open when QEMU installs "
            "doesn't pick up the updated PATH until restarted, a real "
            "and common cause of this exact error. If you just did "
            "reopen it and this still fails, check the install added "
            "its own folder (typically `C:\\Program Files\\qemu`) to "
            "your PATH."
        )
    elif system == "Darwin":
        hint = "Install it with `brew install qemu`, then try again."
    else:
        hint = "Install it via your distro's `qemu-system-x86_64`/`qemu` package, then try again."
    sys.exit(
        "error: qemu-system-x86_64 not found on PATH.\n\n" + hint
    )


def main():
    disk = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_DISK
    if not os.path.isfile(disk):
        sys.exit(f"error: disk image not found: {disk}")

    qemu = find_qemu()
    port = free_tcp_port()

    print(f"Booting {disk} ...")
    subprocess.Popen([
        qemu, "-machine", "pc", "-m", "512",
        "-monitor", f"tcp:{MONITOR_HOST}:{port},server,nowait",
        "-boot", "c", "-drive", f"file={disk},if=ide,format=qcow2",
    ])

    # Give QEMU a moment to start before the first monitor connection
    # attempt (monitor_connect itself retries too, but this avoids
    # spamming connection refused errors during the earliest moment).
    time.sleep(1)
    # Then the bootloader's own drive-select menu, then dismiss "Take
    # Tour?" - both confirmed by real timing on this exact disk
    # (experiments/87-bundle-install/), not guessed.
    time.sleep(3)
    monitor_cmd(port, "sendkey 1")  # boot drive C
    time.sleep(15)
    monitor_cmd(port, "sendkey n")  # decline Take Tour
    time.sleep(2)

    print("Loading hgit (this takes ~20s - compiling ~200KB of real HolyC)...")
    send_text(port, '#include "::/Doc/Comm";')
    time.sleep(2)
    send_text(port, "CommInit8n1(1,115200);")
    time.sleep(2)
    send_text(
        port,
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

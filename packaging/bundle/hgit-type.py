#!/usr/bin/env python3
"""hgit-type.py — send one line of HolyC into an already-running
hgit-launch.py session, via the same QEMU monitor keystroke injection
`hgit-launch.py` itself uses to load hgit in the first place.

Exists for a real, seen problem (2026-09-16): typing directly into the
QEMU window sometimes doesn't work right on some Windows setups -
Shift-key characters (`(`, `"`, `;`, ...) not registering, usually a
host keyboard layout/IME/QEMU-focus quirk, not a TempleOS or hgit
problem. Since `hgit-launch.py`'s own monitor-based typing demonstrably
works (it just loaded and ran ~200KB of real HolyC full of exactly
those characters), this gives you the identical, reliable mechanism
for your own follow-up commands instead of fighting the live keyboard.

Usage:
    python3 hgit-type.py <port> "<holyc code>"

<port> is printed by hgit-launch.py's own "Ready." message - the
monitor port for that specific running session (each launch picks a
fresh one, so this only works against the session that printed it).

Example:
    python3 hgit-type.py 54321 "Hgit(\\"version\\");"
"""
import socket
import sys
import time

MONITOR_HOST = "127.0.0.1"

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


def send_text(port, text, enter=True):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect((MONITOR_HOST, port))
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
    if len(sys.argv) != 3:
        sys.exit(f"usage: {sys.argv[0]} <port> \"<holyc code>\"")
    try:
        port = int(sys.argv[1])
    except ValueError:
        sys.exit(f"error: <port> must be a number, got {sys.argv[1]!r}")
    text = sys.argv[2]
    try:
        send_text(port, text)
    except OSError as e:
        sys.exit(
            f"error: could not reach the QEMU monitor on "
            f"{MONITOR_HOST}:{port}: {e}\n"
            f"Is the hgit-launch.py session still running, and is this "
            f"the port IT printed (each launch picks a fresh one)?"
        )
    print(f"sent: {text}")


if __name__ == "__main__":
    main()

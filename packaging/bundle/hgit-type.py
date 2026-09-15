#!/usr/bin/env python3
"""hgit-type.py — send HolyC into an already-running hgit-launch.py
session, via the same QEMU monitor keystroke injection `hgit-launch.py`
itself uses to load hgit in the first place.

Exists for a real, seen problem (2026-09-16): typing directly into the
QEMU window sometimes doesn't work right on some Windows setups -
Shift-key characters (`(`, `"`, `;`, ...) not registering, usually a
host keyboard layout/IME/QEMU-focus quirk, not a TempleOS or hgit
problem. Since `hgit-launch.py`'s own monitor-based typing demonstrably
works (it just loaded and ran ~200KB of real HolyC full of exactly
those characters), this gives you the identical, reliable mechanism
for your own follow-up commands instead of fighting the live keyboard.

**Use --file, not inline text, for anything with a `"` in it.** A real,
seen problem (2026-09-16): passing HolyC containing double quotes as an
inline command-line argument on Windows is genuinely unreliable -
PowerShell/cmd's own argument reconstruction for native .exe programs
can silently eat embedded `"` characters no matter how they're escaped
(`\\"`, doubled `""`, single-quote wrapping - all real, all tried, all
still lost the quotes before Python ever saw them). Writing the command
to a plain text file sidesteps shell quoting entirely.

Usage:
    python3 hgit-type.py <port> --file <path>      # one real command
                                                      per line
    python3 hgit-type.py <port> "<holyc code>"      # inline - fine for
                                                      quote-free text
                                                      only, see above

<port> is printed by hgit-launch.py's own "Ready." message - the
monitor port for that specific running session (each launch picks a
fresh one, so this only works against the session that printed it).

Example (recommended - put this in commands.txt):
    Hgit("version");
    Hgit("help");
Then:
    python3 hgit-type.py 54321 --file commands.txt
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


def usage():
    sys.exit(
        f"usage: {sys.argv[0]} <port> --file <path>   (recommended - "
        f"see this script's own header comment for why)\n"
        f"   or: {sys.argv[0]} <port> \"<holyc code>\"   (inline - "
        f"quote-free text only)"
    )


def main():
    if len(sys.argv) < 3:
        usage()
    try:
        port = int(sys.argv[1])
    except ValueError:
        sys.exit(f"error: <port> must be a number, got {sys.argv[1]!r}")

    if sys.argv[2] == "--file":
        if len(sys.argv) != 4:
            usage()
        path = sys.argv[3]
        try:
            with open(path, "r", encoding="utf-8") as f:
                lines = [ln.rstrip("\n").rstrip("\r") for ln in f]
        except OSError as e:
            sys.exit(f"error: could not read {path}: {e}")
        lines = [ln for ln in lines if ln.strip() != ""]
        if not lines:
            sys.exit(f"error: {path} has no real lines to send")
        for i, line in enumerate(lines, 1):
            try:
                send_text(port, line)
            except OSError as e:
                sys.exit(_conn_error(port, e))
            print(f"sent ({i}/{len(lines)}): {line}")
            time.sleep(0.3)
    else:
        if len(sys.argv) != 3:
            usage()
        text = sys.argv[2]
        try:
            send_text(port, text)
        except OSError as e:
            sys.exit(_conn_error(port, e))
        print(f"sent: {text}")


def _conn_error(port, e):
    return (
        f"error: could not reach the QEMU monitor on "
        f"{MONITOR_HOST}:{port}: {e}\n"
        f"Is the hgit-launch.py session still running, and is this "
        f"the port IT printed (each launch picks a fresh one)?"
    )


if __name__ == "__main__":
    main()

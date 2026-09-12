#!/usr/bin/env python3
"""Host-side BLAKE2b reference oracle for hgit.

This is NOT hgit's hash implementation - it's the known-good baseline a
future native-HolyC BLAKE2b (feasibility probes #2/#3 in the research
plan) gets diffed against. Both vectors below are from primary sources,
fetched and cross-checked in this session, not transcribed from memory:

  - vector 1: RFC 7693 Appendix A worked example (unkeyed BLAKE2b-512
    of "abc"), fetched from https://www.rfc-editor.org/rfc/rfc7693
  - vector 2: first entry of the official BLAKE2 KAT file
    (https://github.com/BLAKE2/BLAKE2/blob/master/testvectors/blake2b-kat.txt),
    which is a *keyed* hash of the empty string with the standard KAT
    key = bytes 0x00..0x3f (64 sequential bytes) - not unkeyed. Getting
    this key wrong is the actual failure mode worth guarding against
    (this session first mis-transcribed an unkeyed empty-string vector
    from memory and it failed - see failed-approaches.md).
"""
import hashlib
import sys

KAT_KEY = bytes(range(64))

VECTORS = [
    ("abc", 64, b"", b"abc",
     "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6"
     "fdbffa2d17d87c5392aab792dc252d5de4533cc9518d38aa8dbf192"
     "5ab92386edd4009923"),
    ("kat[0] (keyed, empty input)", 64, KAT_KEY, b"",
     "10ebb67700b1868efb4417987acf4690ae9d972fb7a590c2f0287179"
     "9aaa4786b5e996e8f0f4eb981fc214b005f42d2ff4233499391653df"
     "7aefcbc13fc51568"),
]


def check():
    ok = True
    for label, size, key, data, expected in VECTORS:
        got = hashlib.blake2b(data, digest_size=size, key=key).hexdigest()
        status = "PASS" if got == expected else "FAIL"
        if got != expected:
            ok = False
        print(f"{status} {label}")
        if got != expected:
            print(f"     got:      {got}")
            print(f"     expected: {expected}")
    return ok


if __name__ == "__main__":
    sys.exit(0 if check() else 1)

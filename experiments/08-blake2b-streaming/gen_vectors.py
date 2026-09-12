#!/usr/bin/env python3
"""Regenerates the ground-truth digests for the 200/300-byte multi-block
BLAKE2b streaming test, using Python's hashlib as the oracle (same
approach as experiments/02-blake2b-oracle/)."""
import hashlib

def gen(n, mult, add):
    data = bytes([(i*mult+add) % 256 for i in range(n)])
    return data, hashlib.blake2b(data, digest_size=64).hexdigest()

if __name__ == "__main__":
    for n, mult, add in [(200, 7, 3), (300, 13, 1)]:
        data, digest = gen(n, mult, add)
        print(f"len={n} digest={digest}")

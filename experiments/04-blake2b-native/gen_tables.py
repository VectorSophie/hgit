#!/usr/bin/env python3
"""Generates the B2Init() body (IV constants + SIGMA permutation table)
for Blake2b.HC as individual assignment statements, to avoid
hand-transcription errors across 8 IV words and 192 SIGMA entries.
Run and paste output into src/hgit-core/Blake2b.HC's B2Init() if the
tables ever need regenerating (they shouldn't - BLAKE2b's constants are
fixed by RFC 7693)."""

SIGMA = [
 [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15],
 [14,10,4,8,9,15,13,6,1,12,0,2,11,7,5,3],
 [11,8,12,0,5,2,15,13,10,14,3,6,7,1,9,4],
 [7,9,3,1,13,12,11,14,2,6,5,10,4,0,15,8],
 [9,0,5,7,2,4,10,15,14,1,11,12,6,8,3,13],
 [2,12,6,10,0,11,8,3,4,13,7,5,15,14,1,9],
 [12,5,1,15,14,13,4,10,0,7,6,3,9,2,8,11],
 [13,11,7,14,12,1,3,9,5,0,15,4,8,6,2,10],
 [6,15,14,9,11,3,0,8,12,2,13,7,1,4,10,5],
 [10,2,8,4,7,6,1,5,15,11,9,14,3,12,13,0],
 [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15],
 [14,10,4,8,9,15,13,6,1,12,0,2,11,7,5,3],
]
IV = [0x6A09E667F3BCC908, 0xBB67AE8584CAA73B, 0x3C6EF372FE94F82B, 0xA54FF53A5F1D36F1,
      0x510E527FADE682D1, 0x9B05688C2B3E6C1F, 0x1F83D9ABFB41BD6B, 0x5BE0CD19137E2179]

if __name__ == "__main__":
    print("U0 B2Init()")
    print("{")
    for i, v in enumerate(IV):
        print(f"  B2_IV[{i}] = 0x{v:016X};")
    idx = 0
    for row in SIGMA:
        for val in row:
            print(f"  B2_SIGMA[{idx}] = {val};")
            idx += 1
    print("}")

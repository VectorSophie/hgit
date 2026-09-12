# Probe 25 — hex string ↔ raw hash conversion, real TempleOS

Status: **PASS, first try.** Closes the last thing standing between
`hgit see` and a real cmd-line invocation: everything so far takes a
commit as a raw 64-byte hash, but a human can't type 64 raw bytes at a
prompt.

## What was tested

Against the real HEAD hash of the persisted repository from probes
18–24:

1. `HashToHex` on the real HEAD hash → a 128-character lowercase hex
   string, printed and visually cross-checked against probe 19's own
   debug output (`AC5D5CE6...` prefix) — same hash, same session
   history, independently confirmed twice now.
2. `HexToHash` on that string → round-tripped back to the exact original
   64 bytes (`roundtrip_match=1`).
3. **A deliberately invalid hex string** (one character replaced with
   `'z'`) → `HexToHash` correctly returns `FALSE` rather than silently
   producing garbage bytes (`bad_hex_rejected=1`).
4. The round-tripped hash was then fed straight into `HgitSee` — proving
   the *whole* hex-string-in, real-commit-detail-out path works, not
   just the byte conversion in isolation.

## Landed as real hgit-cli source

`src/hgit-cli/Hex.HC` (`HexDigit`/`HexToHash`/`HashToHex`) — logic
identical to the tested version (comment wording only differs).

## Not yet done

- `HexToHash` assumes exactly 128 characters — no length check on the
  input string itself (a too-short string would read past its own end
  before hitting an invalid character, if it happened to contain 128+
  valid-looking hex characters in adjacent memory). Not yet a problem
  in practice (invalid characters are usually hit immediately for
  non-hash-shaped input, as probe 26 shows), but a real gap worth
  closing before this handles untrusted input.

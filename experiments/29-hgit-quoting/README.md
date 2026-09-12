# Probe 29 — quoted-argument support in the dispatcher, real TempleOS

Status: **PASS after finding and fixing a real incompleteness in the
first fix.** Closes the last M1-adjacent polish item from doc 10.

## Design

`ExtractToken` now recognizes a token that starts with `"`: it reads
until the matching closing quote (allowing spaces inside) and strips
the quotes from the output, instead of stopping at the first space.
Plain unquoted tokens are unaffected.

Confirmed from primary source before testing: RedSea's own filename
character bitmap (`Doc/RedSea.DD`, `char_bmp_filename[1] = 0x03FF73FB`)
has bit 0 set — ASCII 32 (space) is a valid RedSea filename character —
so testing against a real spaced path is a legitimate real-world case,
not a contrived one.

## What was tested, in stages

1. **`ExtractToken` in isolation**: an unquoted token still extracts and
   positions identically to before (`tok1=plain_token pos1=12`); a
   quoted token containing a space extracts the space-containing
   content with quotes stripped; a **real file** created at that exact
   spaced path via `FileWrite`/`FileRead` round-tripped correctly
   (`spaced_file_exists=1 spaced_file_size=5`).
2. **Through the real dispatcher, `status`**: unaffected, matches prior
   probes exactly.
3. **Through the real dispatcher, `init` — found a real bug**: `Hgit`'s
   `init` branch calls `HgitInit(rest)` directly, never through
   `ExtractToken` at all (unlike `status`/`history`/`see`/`offer`,
   which all tokenize their arguments). A quoted path was passed
   through with its quote characters literally intact, so `HgitInit`
   tried to create a file whose name included the quote characters
   themselves — silently the *wrong* file, not an error.
4. **Fixed**: `init`'s branch now extracts its path via `ExtractToken`
   too. Verified against the real, final, committed `Hgit()` (not a
   standalone copy): `Hgit("init \"C:/Home/RealQuotedRepo.hgs\"");`
   correctly created `C:/Home/RealQuotedRepo.hgs` (`size=16`, a valid
   empty repo header), and a follow-up `status` call still worked
   exactly as before (regression check).

## A transient hang, and a self-inflicted red herring, both set aside honestly

- One push (the rebuilt package plus a test tail, ~55KB combined) never
  produced `D_OK`/`D_DONE` and didn't respond even to a trivial ping —
  a genuine hang, distinct from every prior compile-error case (which
  always at least produced *some* output). Recovered with a clean
  reboot; re-pushing the identical package **alone** worked immediately
  and quickly, and the test code worked fine as a separate follow-up
  push. Not root-caused — logged as an open, unexplained data point,
  not a resolved one.
- A separate attempt at testing the `init` fix produced confusing
  cascading errors that, on inspection, were self-inflicted: manually
  escaping HolyC string-literal quotes inside a Python triple-quoted
  string produced the wrong bytes. Switched to writing a plain `.hc`
  file and pushing its raw bytes (this project's normal, safer
  pattern) and the confusion disappeared. Not a HolyC quirk — a
  reminder to prefer real files over manually-escaped inline strings
  when a test itself needs to contain quote characters.

## Landed as real hgit-cli source

`src/hgit-cli/Hgit.HC` (`ExtractToken`'s quoting logic, and the `init`
branch's fix) — logic byte-for-byte identical to the tested versions.
`packaging/HgitAll.HC` rebuilt via `tools/build-package.sh` and
re-verified end to end after the rebuild.

## Not yet done

- Only double-quote wrapping is supported — no escaped quotes *within*
  a quoted token (e.g. a filename containing a literal `"`), no
  single-quote alternative.
- `offer`'s message field was already free-text (everything after the
  first two tokens) and untouched by this change — not re-verified
  here since its behavior didn't change, but worth a quick sanity check
  in a future probe if it's ever refactored.

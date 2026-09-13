# Probe 78 — `hgit logo`: project branding in the CLI

Status: **PASS**. Not a milestone-plan item - a real, user-provided
design contribution (logo PNGs + ASCII art), wired into the actual
product.

(Numbered 78, not 77, to avoid colliding with a concurrent peer
session's own `experiments/77-fossil-checksum-isolation/` - both this
directory and the real serial-log evidence below were captured while
this was still locally "probe 77," hence the `P77_LOGO_*` markers in
`serial-log-passing-run.txt` and the test driver's own internal
function name predates the rename to `P78LogoTest`; the marker text in
the evidence file is real, unedited captured output, kept as-is rather
than rewritten to match.)

## What was built

The project owner provided two PNG logos and two ASCII-art renderings
of the same mark (a flame/tree motif in a diamond). Moved into
`docs/brand/` (`hgitlogo.png`, `hgitlogowithtext.png`,
`ascii-hgit.txt`, `ascii-hgit2.txt` - the wider `ascii-hgit.txt` kept
for reference/larger-format use; the narrower `ascii-hgit2.txt`,
79 columns wide, fits a standard 80-column terminal and is the one
actually wired into the CLI). `README.md` now shows the logo image at
the top (`hgitlogowithtext.png`, GitHub renders it directly).

`src/hgit-cli/Logo.HC` embeds the trimmed 26-line ASCII art as string
literals and adds `HgitLogo()`, wired into the dispatcher as `hgit
logo` and listed in `hgit help`. **Each line is passed through
`CommPrint`'s own `"%s"` format argument, never as the format string
itself** - the art is full of literal `%` glyphs (its block-shading
characters), which `CommPrint` would otherwise parse as real format
specifiers, corrupting the output or worse.

## Verified

`test_driver.hc` (`P77LogoTest`): `Hgit("logo")` prints all 26 lines
of the ASCII art correctly, `%` glyphs intact, no corruption or
misinterpreted format specifiers - confirmed by reading the real
serial-log output byte-for-byte (`serial-log-passing-run.txt`).

**Regression**: re-ran `experiments/65-head-deletion/test_driver.hc`
(the project's standing full command-surface regression) immediately
after - all still correct, `PASS p65_head_deletion_regression`.

`tools/lint-package.sh` clean before pushing (only the 3 known
built-in-manifest gaps). Package rebuilt to include `Logo.HC` in
`tools/build-package.sh`'s dependency order (after `Offer.HC`, before
`Hgit.HC`, since `Hgit.HC` calls `HgitLogo`).

## Not yet done

- No corresponding `hgit help`-style detail text for `logo` itself
  beyond the one listing line - not needed, it's a self-explanatory
  command.
- The wider `ascii-hgit.txt` (100 columns) isn't wired into the CLI -
  kept in `docs/brand/` for reference/future use (e.g. a larger
  terminal, or non-CLI display) rather than discarded.

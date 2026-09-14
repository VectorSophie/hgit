# Probe 113 — a real `format_version` bump, and a real "you can now see it" fix

Status: **PASS**. Follows directly from a real gap found while doing a
`FORMAT.md` doc-accuracy sweep: `format_version` had never actually
been bumped despite at least three real, explicitly-labeled breaking
changes since it was introduced (ADR 0004's entity-ID field, ADR
0010's recursive trees, ADR 0011's multi-parent commits) - `Init.HC`
still hardcoded version 1 for every new repo. A second, related gap
found along the way: no real command ever actually SHOWED
`format_version` to a user - it was read internally (every command
that opens a repo calls `HgsReadHeader`) but never printed anywhere.

## What was built

- `Init.HC` now writes `format_version` **2** for every new repo - a
  real, deliberate line drawn under the version-1-era changes above.
  Confirmed by direct search first: no reader anywhere branches on the
  literal version number, so this is purely a correction to what gets
  WRITTEN, not a new migration mechanism - no real evidence yet that
  one is needed (no released users, no repo has ever had to survive
  across one of these format changes).
- `hgit check` now prints `format_version=%d` in both its `CHECK_OK`
  and `CHECK_FAIL` lines - the version was always readable internally,
  never actually shown to a user by any real command until now.
- `FORMAT.md` updated throughout: the header table, the top-level
  "Status" line, and a new, honest "Versioning policy" section
  documenting exactly what was found and what was corrected (see that
  file's own git history / this commit for the fuller writeup - not
  duplicated here).

## Verified

`test_driver.hc` (`P113CheckFormatVersionTest`): a fresh repo's own
`hgit check` shows `CHECK_OK objects=0 format_version=2` immediately
after `init` - confirms the new version is written correctly and
`check` surfaces it. A real offer afterward, then `check` again -
`CHECK_OK objects=3 format_version=2`, confirming the repo works
completely normally at the new version, not just a header change with
everything else silently broken.

**Backward compatibility confirmed, not assumed**: the standing
regression (`experiments/65-head-deletion/test_driver.hc`) runs
against a real, already-existing version-1 repo (`P65Repo.hgs`,
persisted from earlier probes in this same long-lived session) and
passes completely unaffected - version 1 and version 2 repos are
read identically by every command, exactly as the "no reader branches
on the version" search predicted.

`tools/lint-package.sh` clean (only the 3 known built-in-manifest
gaps). Full command-surface suite (`tests/full-regression.hc`)
re-run clean - every fresh repo it builds correctly shows
`format_version=2` in its own `CHECK_OK` output.

## What this does not do

- Does not add any real version-aware reading/migration logic - if a
  future format change genuinely needs one (a reader that behaves
  differently for version 1 vs version 2), that's real, separate,
  not-yet-needed work.
- Does not retroactively rewrite any existing on-disk version-1 repo's
  header - none needed migrating (no evidence any real repo has ever
  needed to survive across one of the version-1-era changes).

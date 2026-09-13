# Probe 74 — `hgit version`: a real embedded version string

Status: **PASS** — closes a gap `docs/research/09-packaging-and-releases.md`
already flagged explicitly: "No version string is embedded in the
packaged file itself yet — a real release should probably print its
own version via a real command (e.g. `Hgit("version");`)... Not built
yet — real follow-up work."

## What was built

`Hgit.HC` gains `#define HGIT_VERSION "0.13.0"` and a new `version`
dispatch branch (`hgit version` -> `HGIT_VERSION <version>`).
`hgit help` (probe 73) also now prints `HELP_VERSION <version>` as its
first line, so a user checking the command list sees what they've
loaded without a separate call.

This is a real, human-maintained string, not generated: it must be
bumped by hand alongside each real GitHub release tag, the same
"truthful, not automated" discipline this project already applies to
keeping the dispatch table and `hgit help`'s own text in sync (probe
73). **This probe's own version, `0.13.0`, is the release this exact
change ships as** - the first real test of that discipline: the tag
this probe's work gets released under must match what `hgit version`
itself reports on that same package.

## Verified

`test_driver.hc` (`P74VersionTest`): calls `Hgit("version")` -
`HGIT_VERSION 0.13.0`. Calls `Hgit("help")` - confirms `HELP_VERSION
0.13.0` appears as the very first line of the listing, followed by the
same 26 `HELP_CMD` lines probe 73 already verified, now with a new
`HELP_CMD version` line at the end too.

**Regression**: re-ran `experiments/65-head-deletion/test_driver.hc`
(the project's standing full command-surface regression) immediately
after - all still correct, `PASS p65_head_deletion_regression`.

`tools/lint-package.sh` clean before pushing. Only `Hgit.HC` needed
pushing - the new `version` branch and the `HGIT_VERSION` macro are
both self-contained in the one file no other module calls into for
this.

## Not yet done

- No automated check that `HGIT_VERSION` actually matches the git tag
  a given package was released under - a human step (this README is
  itself part of that human step, this time), same as every other
  hand-synced pairing already in this project (`Hgit.HC`'s own dispatch
  table vs. `hgit help`'s text).
- Doesn't distinguish a build from a dirty/modified checkout (no
  git-describe-style suffix) - not needed yet at this project's own
  release cadence (one tag per real, verified change).

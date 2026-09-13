# Probe 73 — `hgit help`: real command discoverability

Status: **PASS** — a real "modern CLI" gap this project otherwise had:
`DISPATCH_ERR unknown_command` told a user something was wrong, but
never what to try instead, and there was no way to list the full
command surface short of reading `Hgit.HC`'s own source.

## What was built

`HgitHelp()` (`src/hgit-cli/Hgit.HC`) prints one `HELP_CMD` line per
real dispatched command, each with its literal argument shape -
written by hand to match exactly what `Hgit`'s own dispatcher parses
for it (verified against the dispatcher's real code while writing
this, not guessed from memory: the `correct`/`revert`/`reconcile`
shape in particular turned out to be `<repo_path> <target_hex>
<entity_hex> <find_mask> <message>`, not the `<find_mask> <message>
<target_hex>` order a first guess assumed - checked against
`HgitOfferRelatedCmd`'s real parameter order and several real prior
test drivers' own command strings before writing the help text, so the
help text wouldn't itself be wrong).

Wired into the dispatcher two ways:
- `hgit help` (an explicit command).
- A bare/empty command string (`Hgit("")` - what a user gets by typing
  nothing) also shows help, rather than silently doing nothing or
  erroring.
- `DISPATCH_ERR unknown_command <cmd>` now also prints a
  `DISPATCH_HINT try 'help' for a full command list` line.

## Verified

`test_driver.hc` (`P73HelpTest`): calls `Hgit("help")`, `Hgit("")`, and
`Hgit("notarealcommand ...")` in sequence. All three real dispatcher
paths produce the expected real output - `HELP_BEGIN`/`HELP_CMD ...`/
`HELP_END` (identical for both the explicit and bare-string case,
confirming both routes hit the same code), and the unknown-command
case shows both its existing `DISPATCH_ERR` and the new
`DISPATCH_HINT` line. Full serial-log capture in
`serial-log-passing-run.txt`.

**Regression**: re-ran `experiments/65-head-deletion/test_driver.hc`
(the project's standing full command-surface regression) immediately
after - all still correct, `PASS p65_head_deletion_regression`.

`tools/lint-package.sh` clean before pushing (only the 3 known
built-in-manifest gaps). Only `Hgit.HC` needed pushing - `HgitHelp` is
a new, standalone function with no other file calling it yet, so
probe 58's own JIT-redefinition gotcha (re-push every caller) doesn't
apply here.

## Not yet done

- The help text is maintained by hand, not generated from the
  dispatcher's own parsing code - same maintenance burden as the
  dispatcher's own `if`/`else if` chain already has (every prior probe
  that added a command edited both the dispatch branch and, now, this
  list); a real risk if the two silently drift apart over time, not
  automated away here.
- No per-command `hgit help <command>` (detail view) - just the one
  flat listing.

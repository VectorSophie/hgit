# Probe 117 — `Ignore.HC`: the `.hgitignore` matching primitive, verified standalone

Status: **PASS**. v1.8.0's first real piece, per `docs/ROADMAP-v1.8.md`
and `docs/adr/0014-ignore-rules.md` (read that ADR first - this probe
only verifies what it already decided). Built and verified standalone
before being wired into any real command - the same "primitive first,
then a real CLI decision" pattern this project used for
`TreeBuildRecursive` (ADR 0010) and `FindMergeBase` (ADR 0011).

## What was built

`src/hgit-core/Ignore.HC`: `IgnoreLoad` (parses a real `.hgitignore`
file into three parallel MAlloc'd arrays - patterns/negation-flags/
kind-tags, sized from the real file's own byte length, no guessed
cap), `IsIgnored` (checks one candidate against the loaded rules, last
match wins), `IgnoreGlobMatch` (a real, minimal single-`*`-wildcard
matcher), `IgnoreFree`.

## Verified

`test_driver.hc` (`P117IgnorePrimitiveTest`), against the roadmap's own
real example grammar (`*.tmp`, `*.bak`, `build/`, `generated/*`,
`!important.hc`) plus a comment, a blank line, and one deliberately
unsupported line (`a/b.txt`, an internal slash with no `/*`/trailing
`/`):

- `IGNORE_UNSUPPORTED_LINE a/b.txt` printed and that line excluded -
  5 real patterns loaded, not 6.
- NAME patterns (`*.tmp`/`*.bak`) match at any depth (root and
  `SubA/SubB` both `=1`).
- The DIR pattern (`build/`) matches a directory named `build` at any
  depth too (root and `SubA` both `=1`) - matching by name only,
  depth-independent, per ADR 0014.
- The DIR_CONTENTS pattern (`generated/*`) is correctly anchored: a
  direct child of `generated` is ignored (`=1`), a deeper descendant
  (`generated/sub/x.txt`) is not (`=0`), and a directory literally
  named `generated` found somewhere else entirely is not caught by
  this pattern at all (`=0` - that would need a separate `generated/`
  DIR rule, not present in this rule set).
- Negation (`!important.hc`) correctly leaves `important.hc` un-ignored
  even with no earlier rule that would have caught it anyway (a real,
  honest edge case, not assumed).
- A real override-precedence case (`*.hc` then `!important.hc`,
  loaded separately): `other.hc` ignored (`=1`), `important.hc`
  rescued by the later negation (`=0`) - confirms "last matching line
  wins," not "first."
- A missing `.hgitignore` file loads a real, empty rule set
  (`count=0`), not an error.

`tools/lint-package.sh` caught a real HolyC quirk before this ever
reached QEMU: two loop variables named `pi` collided with TempleOS's
own reserved `pi` constant (this project's own previously-documented
quirk) - renamed to `li`/`ppi`, confirmed clean on the next lint pass.
Full regression re-run clean afterward.

## What this does not do

- Not yet wired into `offer`/`offertree`/`status`/`statustree` - real,
  immediate next step in this same v1.8.0 release, not a separate
  later one.
- No `**`/`?`/character-class support - a real, named grammar
  limitation (ADR 0014), not built speculatively.

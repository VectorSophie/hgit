# Probe 119 — `Attrs.HC`/`Commit.HC` primitive (ADR 0015)

Status: **PASS**. Standalone verification of the ADR 0015 machinery
before it's exercised through the CLI (`Offer.HC` wiring is already
done, mirroring the exact "primitive first" order probe 117 → 118
used for `Ignore.HC`).

## What was verified

- `IsContentBinary`: a plain text buffer is not binary; a buffer with
  an embedded NUL byte is - Git's own real `is_binary` heuristic.
- `AttrsRulesLoad`/`GetEffectiveMode` against a real
  `.hgitattributes` with all three attribute kinds plus one
  unsupported token:
  - `*.png binary` forces binary mode even with no auto-detection.
  - `*.HC text,executable` forces text (clears auto-detected binary)
    *and* executable - rule always wins over auto-detection.
  - `build/* binary` (DIR_CONTENTS) correctly anchors to a real
    root-level `build/` directory (`rel_dir="build"`).
  - `*.weird frobnicate` reports `ATTR_UNSUPPORTED frobnicate` and is
    excluded from the loaded rule set (3 real rules loaded, not 4).
  - A name matching no rule falls straight through to auto-detection
    in both directions (auto-text and auto-binary).
- `AttrsListEncode`/`AttrsListFindMode`: a real `[U64 entity_id][U8
  mode]` list round-trips two distinct entities correctly and
  reports "not found" for a third, unlisted entity ID.
- `Commit.HC`'s new `has_attrs`/`attrs_hash` field: a commit encoded
  with `has_attrs=FALSE` reports `CommitHasAttrs=FALSE`; one encoded
  with `has_attrs=TRUE` reports `TRUE` and `CommitAttrsHash` returns
  the exact 64 bytes given. A commit buffer truncated to end exactly
  at `CommitAttrsOffset` (simulating a real pre-ADR-0015 commit with
  no room for the field at all) correctly reports `FALSE` via the
  real bounds check - no crash, no garbage read.

## A real, honest test-authoring bug found and fixed here

First run used `*.hc text,executable` (lowercase) against a real
file named `Offer.HC` (uppercase, matching this project's own actual
naming) - `IgnoreGlobMatch` (reused from `Ignore.HC`) is
case-sensitive by design (ADR 0014 never claimed otherwise), so the
rule silently didn't match and the candidate fell through to
auto-detection instead, which happened to also produce a binary
result given the `TRUE` auto_binary argument passed in - a
plausible-looking wrong pass, not a real bug. Caught by checking the
returned mode value against what the rule should have produced
(`text,executable` → mode 2, not "binary" → mode 1) rather than just
checking the probe printed something. Fixed by correcting the test's
own pattern to `*.HC`.

`tools/lint-package.sh` clean throughout (only the 3 known
built-in-manifest gaps).

## What this does not do

- Does not exercise the real `Offer.HC` wiring end-to-end (that's
  already probe 118's own successor scope - a future probe, or the
  standing regression, once `Status.HC`/`Diff.HC`/`Check.HC` also
  know about attrs).
- Does not test mode changes across multiple commits (mode
  transitions, e.g. a file becoming executable) - real v1.8.2 (status/
  diff integration) scope.

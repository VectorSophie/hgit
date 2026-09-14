# Probe 120 — mode changes surfaced in `status`/`diff`, and a real `Check.HC` gap closed

Status: **PASS**. Closes two more items from `docs/ROADMAP-v1.8.md`'s
v1.8.1 scope: "mode/type changes surfaced in status and diff" and
"metadata participates in tree identity and integrity checking."

## What was built

- `Status.HC` (`HgitStatus` flat, `StatusTreeWalk` recursive): both
  now load `.hgitattributes` (same directory-derivation convention as
  `.hgitignore`) and resolve HEAD's own `OBJ_ATTRS` list (if
  `CommitHasAttrs`). For every already-tracked candidate, HEAD's
  stored mode (looked up by entity ID) is compared against the
  candidate's current effective mode (rules + auto-detection, same
  resolution `Offer.HC` itself uses) - a mismatch prints
  `STATUS_MODE_CHANGED <path> <old> -> <new>` alongside (never instead
  of) the existing UNCHANGED/MODIFIED line, since content and mode are
  independent dimensions - a file can change mode with no content
  edit at all, which the flat `hgit status`'s own previously-silent
  UNCHANGED case now needs to still surface.
- `Diff.HC` (`DiffPrintTreeChanges`): both commits' own `OBJ_ATTRS`
  lists are resolved once in `HgitDiff` and threaded through
  recursion unchanged (entity IDs are unique repo-wide, not
  per-directory - no re-resolution needed per level). For every
  same-identity blob entry, mode is compared the same way, printing
  `DIFF_MODE_CHANGED <path> <old> -> <new>` independently of whether
  `DIFF_MODIFIED` also printed.
- **A real, separate gap found and fixed along the way**:
  `Check.HC`'s `CheckMarkReachable` (the reachability walk that
  drives `CHECK_DANGLING`) didn't know about `has_attrs`/`attrs_hash`
  at all - a commit's own attrs object was a real, live reference
  with nothing walking it, so `hgit check` reported every attrs
  object as `CHECK_DANGLING blob <hash>` (mislabeled as a blob too -
  `OBJ_ATTRS` fell through to the default `"blob"` kind label).
  Found by this probe's own final `hgit check` call, not assumed -
  fixed by adding the same `CommitHasAttrs`/`CommitAttrsHash` walk
  the relation-target/parent/tree edges already get, in both the
  reachability pass and the separate missing-object
  (`CHECK_BROKEN_REF`) pass, plus a real `"attrs"` kind label.

## Verified

`test_driver.hc` (`P120ModeChangeTest`): two tracked files, no
`.hgitattributes` at first (both mode 0). A rule is added marking one
of them executable with **no content edit at all** - `hgit status`
correctly still reports `STATUS_UNCHANGED` for its content AND a
separate `STATUS_MODE_CHANGED ... 0 -> 2` line. Re-offering persists
this as a real second commit; `hgit diff` against it reports
`DIFF_MODE_CHANGED ... 0 -> 2`. The rule is then removed again (mode
back to 0) - `status`/`diff` correctly report the reverse
`2 -> 0` after a third offer. `hgit check` on the final repo:
`CHECK_OK objects=13 format_version=2`, `CHECK_REFS_OK`,
`CHECK_DANGLING_NONE` - the real `OBJ_ATTRS` object created by the
second offer (mode 0 -> 2) is correctly reachable via its commit's
own `attrs_hash`.

A real, honest housekeeping note: a stray file left on disk from an
earlier, interrupted run of this same probe (this is a long-lived
session; plain files persist across separate script pushes) shared
this probe's own `C:/Home/P120*.txt` mask and got silently offered
alongside the probe's real files on the first run - harmless to the
result being verified here (it never had a mode), but it's why the
probe was rerun once after an explicit cleanup pass, and why the
probe's own cleanup step now also deletes it by name.

`tools/lint-package.sh` clean throughout (only the known
built-in-manifest gaps).

## What this does not do

- Does not surface a mode-only change on a RENAMED file (a file that
  changed both name and mode in the same offer) - the rename pass in
  both `Status.HC` and `Diff.HC` reports the rename, but mode
  comparison there is scoped to the exact-identity (`found_by_name`)
  path only, not yet threaded through the rename-match branches. A
  real, separate follow-up if it turns out to matter in practice.
- Does not change what `hgit merge` does with mode - still real,
  deliberately deferred scope (see `Merge.HC`'s own comment, ADR
  0011's narrower-slices precedent).

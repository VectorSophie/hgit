# Probe 94 — `hgit diff` recurses into nested trees

Status: **PASS** (with one real, honestly-logged dead end found along
the way - `DirTreeDel`, see `docs/research/failed-approaches.md`'s
2026-09-14 entry). Closes the `Diff.HC` half of ADR 0010's own
remaining "rendering-command awareness of nested trees" item (probe
93 already closed the `See.HC` half).

## What was built

`DiffPrintTreeChanges` (`Diff.HC`): the same NEW/MODIFIED/DELETED/
RENAMED two-pass-plus-rename-detection logic `hgit diff` already had,
refactored into a recursive helper, generic per-object-type (the same
pattern this project already established in `Check.HC`'s
`CheckMarkReachable` and `See.HC`'s `SeePrintTreeEntries`):

- A subdirectory entry present in both old and new trees, same type,
  different hash - recursed into (old and new subtree content resolved
  via `IndexLookup`, same as every other real command), one directory
  level deeper, its own real changes reported with the real full path
  prefixed (e.g. `SubA/inner.txt`).
- A subdirectory entry with no match by name in the old tree - a
  wholly new subtree, recursed against an EMPTY old tree so every real
  nested entry gets its own `DIFF_NEW <path>` line, not just one line
  naming the directory.
- Symmetrically, an old-tree subdirectory entry with no match in the
  new tree - recursed against an EMPTY new tree, `DIFF_DELETED <path>`
  per real nested entry.
- A same-name entry that changes KIND (file <-> directory) - reported
  as a new, honest `DIFF_TYPE_CHANGED <path>` signal rather than
  silently mis-diffed as a content change or guessed at either side.
  Deliberately out of scope to handle further, same as ADR 0010's own
  deferred cross-directory-rename item.
- Rename detection (exact-hash and fuzzy) stays blob-only, exactly as
  before - a tree's own serialized content isn't meaningful to compare
  byte-for-byte this way.

A real HolyC gotcha hit immediately on first push: the classic
"duplicate member" sibling-block-same-local-name collision (documented
since probe 5) - `sub_new_content`/`sub_prefix`/`same`, each declared
in more than one sibling `if`/`else` branch within the same function.
Fixed by giving every branch's own locals a unique suffix (`_a`/`_b`/
`_c`), confirmed via a clean re-push before moving on.

## Verified (real QEMU runs, not fabricated)

A real 2-level-deep repo (`SubA/inner.txt`, `SubA/SubB/deep.txt`,
`top.txt`), offered via `hgit offertree`, then a second offer that
modifies `inner.txt` and adds `SubA/SubB/deep.txt` as a brand-new file:

```
DIFF_NEW SubA/SubB/deep.txt
DIFF_MODIFIED SubA/inner.txt
DIFF_END
```

Both correctly recursed and path-prefixed - `deep.txt` genuinely new
two levels deep, `inner.txt`'s modification correctly attributed
inside `SubA` rather than reported as one opaque "`SubA` changed"
line.

A third offer, with both nested files individually deleted (see "A
real dead end" below for why not via a whole-directory delete):

```
DIFF_DELETED SubA/SubB/deep.txt
DIFF_DELETED SubA/inner.txt
DIFF_END
```

Both correctly reported as deleted, with full nested paths, via the
"found by name, hash now differs" recursion branch (since the now-
empty `SubA`/`SubB` directories still exist on disk and so still
appear as real, now-empty `OBJ_TREE` entries) - **not** the
not-found-by-name "wholly vanished directory" branch, which remains
untested by direct evidence (see "Not yet done").

**Regression**: `experiments/65-head-deletion/test_driver.hc` re-run
clean after the whole incident and recovery, confirming the persistent
disk's full repo history survived intact (`CHECK_OK objects=150` -
correctly grown from before the incident).

## A real dead end found along the way

The original test design called `DirTreeDel` to remove `SubA` entirely
from disk (a genuine "whole directory vanished" case, exercising the
not-found-by-name DELETED-recursion branch directly). This **hung the
shared daemon** - confirmed, via a separate, minimal, zero-hgit-code
isolation test, to be `DirTreeDel` itself, not this probe's own new
code. Recovered twice (a second incident happened during the first
recovery attempt, a self-inflicted undersized-bootstrap-buffer GPF -
both fully described in `docs/research/failed-approaches.md`). Fixed
the test by deleting each real file individually instead of the whole
directory - `TreeBuildRecursive` handles an emptied-but-present
directory correctly (a real, empty `OBJ_TREE`), giving real, if
slightly different, coverage of the same DELETED-reporting logic.

## Not yet done

- The not-found-by-name "wholly vanished directory" branches (both
  NEW and DELETED sides) are exercised for NEW (a brand-new `SubA`
  itself, not just its contents, in the very first `offertree` of this
  same test) but not directly for DELETED, since `DirTreeDel` isn't
  usable yet. The code is structurally symmetric between the two
  sides, giving real, if indirect, confidence - not the same as a
  direct test.
- `DirTreeDel`'s own real behavior is unexplored - a real, separate
  follow-up if this project ever needs a recursive on-disk delete.
- `Status.HC` (comparing a live directory against nested trees) is
  still the one remaining item on ADR 0010's own "rendering-command
  awareness of nested trees" list.
- Cross-directory rename detection, and `DIFF_TYPE_CHANGED` recursing
  into either side rather than just reporting the change - both
  deliberately deferred, matching ADR 0010's own established scope.

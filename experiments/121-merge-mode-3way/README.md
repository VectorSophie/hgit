# Probe 121 — `hgit merge`'s own real 3-way mode merge

Status: **PASS**. Closes the "mode-only changes" gap
the removed v1.8 roadmap's section 3 ("Complete three-way merge") lists,
and satisfies its own required experiment #5 ("Mode-only change round
trip"). `Merge.HC`'s own header comment used to document this
explicitly as deferred (citing ADR 0011's own precedent for shipping
merge in narrower slices) - closed here, not silently.

## What was done

Mode is now a wholly separate 3-way decision from content inside
`MergeTreesRecursive` - a file's bytes and its mode (ADR 0015,
`Attrs.HC`) can each change independently, so each surviving tree
entry gets its own base/ours/theirs mode resolved via
`AttrsListFindMode` against each side's own commit-level `OBJ_ATTRS`
object (resolved once, up front, in `HgitMerge` via the new
`MergeResolveCommitAttrs`, then threaded through the recursion the
same way `base_tree`/`ours_tree`/`theirs_tree` already are). The
merge's own conflict decision is now `is_conflict || mode_conflict` -
a genuine mode-only conflict (both sides changed mode, differently) is
reported and aborts the whole merge exactly like a content conflict
always has, not silently guessed either way. On success, a real
`OBJ_ATTRS` object is built from every winning mode and wired into the
merge commit via `CommitEncode`'s existing `has_attrs`/`attrs_hash`
fields - no format change needed, this is the same mechanism ADR 0015
already defined, just a second real writer of it.

Two cases, matching probe 99's own two-case shape for the original
content-only merge:

1. **Clean mode-only round trip.** Two files offered together (a
   `P121D_*.txt` wildcard mask, same reason probe 99 uses one - a
   single-file mask would silently drop the other file from every
   later commit). `feature` sets `P121D_file.txt` executable via
   `.hgitattributes` (content untouched); `main` independently edits
   the *other* file's content (so `main`'s own HEAD genuinely diverges
   from the merge base too - otherwise this would be a trivial
   fast-forward, never exercising the real 3-way merge code at all)
   and resets `.hgitattributes` first (a live filesystem input, not
   branch-scoped - the same working-directory gotcha probe 99 already
   documented for file content, now hit for attrs too). Real result:
   `MERGE_OK`, then `hgit diff` on the merge commit (compares against
   its own first parent, `ours`/`main`) shows
   `DIFF_MODE_CHANGED P121D_file.txt 0 -> 2` - reusing probe 120's
   already-proven diff-mode-surfacing output as the verification tool,
   rather than re-parsing objects by hand. `hgit check` on the result:
   `CHECK_OK objects=17 format_version=3`, `CHECK_REFS_OK`,
   `CHECK_DANGLING_NONE` - the merge commit's own new `attrs_hash`
   validates cleanly through `Check.HC`'s existing generic commit-edge
   walk, no code changes needed there.
2. **Genuine mode-only conflict.** One file, content never changes at
   all across the whole probe - `feature` sets it executable,
   `main` independently sets it binary (two different, real
   `.hgitattributes` rules on the same file, same base). Real result:
   `MERGE_CONFLICT P121C_file.txt` / `MERGE_ABORTED conflicts=1`,
   `HEAD` provably unchanged (byte-compared before/after, matching
   probe 99's own "zero side effects" verification), and `hgit check`
   after the aborted merge still comes back completely clean
   (`CHECK_OK objects=11`) - the abort left no corruption or partial
   state behind, same non-destructive stance every other real conflict
   already has.

## Real evidence

Full transcript in `serial-log-evidence.txt`. The two lines that
matter most:

```
DIFF_MODE_CHANGED P121D_file.txt 0 -> 2
```
```
MERGE_CONFLICT P121C_file.txt
MERGE_ABORTED conflicts=1
```

## Honest, documented limitation (not fixed here)

A mode-only change on the side a file gets **deleted** from is not
itself detected as a conflict - the existing edit-vs-delete decision
in `MergeTreesRecursive` only ever consults content equality, never
mode, to decide whether "only one side changed." The file is gone
from the merged tree either way (nothing is silently lost), but a real
chmod-vs-delete race across a merge isn't flagged as a conflict the
way a real content edit vs. delete already is. Noted in `Merge.HC`'s
own header comment; not attempted here - a real, narrower follow-up if
it ever matters in practice.

## Not this probe's job

`Merge.HC`'s own header comment already documents the wider,
unrelated remaining merge gaps from the roadmap's own list (add/add,
rename-vs-edit, rename-vs-rename, cross-directory moves, binary
content conflicts) - this probe is scoped to mode only, the one gap
its own prior TODO comment named directly.

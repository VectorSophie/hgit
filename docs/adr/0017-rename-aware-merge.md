# ADR 0017: Rename-aware three-way merge (v1.8.5)

## Status
Adopted, implemented in `Merge.HC`, verified on real QEMU (probe 123).

## Context
`merge` (ADR 0011) keyed everything by entry NAME. A file renamed on one side
and edited on the other therefore looked like edit-vs-delete plus an unrelated
new file - a spurious conflict - and a file renamed differently on both sides
silently produced two entries sharing one entity ID.

## Decision
Entity IDs already survive renames (ADR 0004/0009: `offer` carries the ID
across an exact or fuzzy rename). Use them as evidence:

1. Per tree level, each side is NORMALIZED against the base: a blob entry
   whose entity ID appears in the base under a different name, unambiguously
   (exactly one match on each side, target name absent from the base, base
   name absent from that side), is renamed back to its base name in a scratch
   copy. The existing name-keyed logic (content, mode, conflicts, resolution
   lookup) then runs unchanged, and the merged entry is written under the new
   name.
2. Normalization applies only when the other side still has the base name, or
   made the identical rename.
3. Two sides renaming one entity to DIFFERENT names is REFUSED
   (`MERGE_RENAME_RENAME` / `MERGE_REFUSED`), with no side effects - never
   guessed, never merged into two entries sharing an identity.

## Not done (honest)
- Cross-directory moves: `offer`'s rename detection is within-directory, so no
  identity evidence survives a move; nothing to merge on.
- Rename-vs-delete: the renamed file survives (unchanged behavior).
- Rename/rename is refused rather than persisted as a resolvable conflict.
- Merge reads only committed trees, so differing ignore/attribute rules
  between sides cannot affect it (attribute MODES are already 3-way merged).
- Criss-cross bases remain out of scope (ADR 0011).

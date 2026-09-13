# Probe 90 — a real, tested recursive tree-building primitive (ADR 0010)

Status: **PASS**, after a real incident along the way (a test bug hung
the shared dev daemon - see `docs/research/failed-approaches.md`'s
matching entry, and below). `TreeBuildRecursive` (`src/hgit-cli/Offer.HC`)
is ADR 0010's first slice: a standalone, working, entity-ID-aware
recursive tree builder over a real on-disk directory structure - **not
wired into `hgit offer`'s own live dispatch**, a deliberate, separate
decision (see the ADR).

## What was built

`TreeBuildRecursive(dir_path, archive, alen, rbuf, idx_hashes,
idx_offsets, idx_count, old_tree_content, old_tree_content_len,
tree_content_out, tree_content_len_out)`: recursively walks a real
directory (`FilesFind` + `CDirEntry.attr & 16`, probe 88's own
primitive), storing each plain file as a real `OBJ_BLOB` and each
subdirectory as a real nested `OBJ_TREE` (built depth-first - probe
89's own confirmed-safe object model), and carries entity IDs forward
- exact name, then exact content hash, then fuzzy similarity (ADR
0009) - independently at *each* directory level, resolving the
matching old subtree (if any) by name before recursing into it.

## Verified

`test_driver.hc` (`P90RecursiveTreeTest`): builds a real 3-level
directory (`P90Root/top.txt`, `P90Root/SubA/a1.txt`,
`P90Root/SubA/SubAA/deep.txt`), builds a tree from it with no old tree
(root commit) - confirms every level's entries resolve with the right
type (`SubA`/`SubAA` are `type=2`, i.e. `OBJ_TREE`; the files are
`type=1`, `OBJ_BLOB`) by walking *into* each nested tree via ordinary
`TreeFindEntry`, recursively, the same way probe 89 first confirmed
was possible. Then edits **only** the deepest file (`deep.txt`) and
rebuilds against the first build's own root tree:

```
P90_B2_TOP_ID_SAME=1
P90_B2_SUBA_ID_SAME=1
P90_B2_A1_ID_SAME=1
P90_B2_SUBAA_ID_SAME=1
P90_B2_DEEP_ID_SAME=1 (expect 1 - same name, edited content, ADR 0004 by-name carry)
P90_B2_DEEP_HASH_CHANGED=1 (expect 1 - content really did change)
```

Every entity ID at every level - including both nested-tree entries
(`SubA`, `SubAA`) and the untouched files - carries forward correctly;
the edited file keeps its own identity too (by-name match, exactly
ADR 0004's own original rule, now proven at real nesting depth), while
its content hash genuinely differs, confirmed by direct byte
comparison, not just trusting the ID logic.

**Regression**: `experiments/65-head-deletion/test_driver.hc` re-run
clean after the daemon's own recovery (see below) - `CHECK_OK`/
`CHECK_REFS_OK`/`CHECK_DANGLING_NONE`, full history, all correct.

## A real incident: this hung the shared dev daemon, twice-removed from the actual bug

The **first** version of this test built its two synthetic archives
without a real `.HGS` header (objects starting at byte 0), while
`TreeBuildRecursive`'s own offset math (`16 + off_rel`) assumes the
real convention every actual command's own `rbuf` follows. Pushing it
caused the shared main daemon (`experiments/01-temple-repl/build/com2.sock`
- used throughout this entire project's history, and by a peer Claude
session working concurrently) to stop responding - almost certainly a
real infinite loop from garbage bytes read 16 positions off, not a
HolyC or `TreeBuildRecursive` bug. Full account, including the real
recovery steps (a monitor `system_reset`, the standard reboot dance,
a full stage-1/stage-2 re-bootstrap, and a regression re-run
confirming the persistent disk's own repo state survived completely
intact) in `docs/research/failed-approaches.md`'s matching entry. The
fix was entirely in the *test* (give the synthetic archives a real
16-byte header, call `IndexBuild` on `buf+16`) - `TreeBuildRecursive`
itself needed no changes, since it was already correct for its one
real intended use.

Re-verified cautiously afterward: a minimal single-build check first
(lower risk, confirmed no hang), then the full two-build test above -
both completed cleanly.

## Not yet done (see ADR 0010's own full scope)

- Wiring into `hgit offer`'s live dispatch - a real, separate CLI-
  semantics decision, not made here.
- `Check.HC`'s referential integrity recursing into nested trees.
- `Status.HC`/`Diff.HC`/rendering-command awareness of nested trees.
- Cross-directory rename/move detection.

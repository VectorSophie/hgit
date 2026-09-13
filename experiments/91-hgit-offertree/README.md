# Probe 91 — `hgit offertree`: real subdirectory support, wired in as a new command

Status: **PASS.** ADR 0010's real CLI-semantics decision, made once
probe 90 proved the standalone `TreeBuildRecursive` primitive solid: a
**new, separate command**, `hgit offertree <repo> <dir_path> <message>`,
not a change to plain `hgit offer` - zero regression risk to the
existing, heavily-relied-on flat-offer code path.

## What was built

`HgitOfferTree` (`Offer.HC`): the same outer shape as
`HgitOfferWithRelation` (load repo, size the archive, resolve the
parent's tree if any, build a commit, update HEAD, log the operation)
but with one real substitution - `TreeBuildRecursive` replaces the
flat `FilesFind` loop, recursing into real subdirectories instead.
Object counting couldn't reuse the flat loop's simple per-file tally
(recursion appends an unpredictable number of blob *and* tree objects
at arbitrary depth), so the final header count comes from re-scanning
what actually landed in the archive via `IndexBuild` - the same
machinery every real command already trusts, sized from a real
computed bound (`alen/73 + 1`, the smallest possible object record
size) rather than a guessed headroom number, matching this project's
own hard-won ADR 0007 lesson about fixed caps.

Wired in as `hgit offertree`, listed in `hgit help`. No relation-tag
support yet (a plain offering only, matching `HgitOffer`'s own
original scope before ADR 0005 added relations) - real, separate
follow-up if needed.

## Verified

`test_driver.hc` (`P91OfferTreeTest`): a real `hgit init`, then a real
`hgit offertree` over a directory with one top-level file and one
subdirectory holding a nested file:

```
SEE_COMMIT ts=1028133 parents=0 msg=first_recursive_offer
SEE_TREE entries=2
  entry type=2 id=859f9270f5c8bde9 name=SubA
  entry type=1 id=591254ca6e3e2a39 name=top.txt
SEE_END
```

`SubA` is a real `type=2` (`OBJ_TREE`) entry - a genuinely nested tree,
created and committed through the real command surface, not a
synthetic in-memory test. `hgit check` on the resulting repo:
`CHECK_OK objects=5, CHECK_REFS_OK, CHECK_DANGLING_NONE`. Re-reading
`Check.HC` itself while writing this up showed this is a REAL, deep
check, not a shallow one: `objects=5` counts commit + top-level tree +
`top.txt` blob + `SubA`'s own nested tree + `inner.txt` blob;
`CHECK_REFS_OK` means the referential-integrity pass's flat scan (over
every archive record, generic per-object-type - not commit-tree-only)
visited `SubA`'s own tree record and validated its child hash;
`CHECK_DANGLING_NONE` means the recursive reachability walk
(`CheckMarkReachable`) actually reached `inner.txt`'s blob through
`SubA`'s own tree entry - it would show dangling otherwise. Neither
pass is depth-aware, so a nested tree gets the exact same treatment as
a top-level one automatically - not a documented gap after all (ADR
0010 corrected accordingly). Still a real, low-risk follow-up: the
adversarial case (deliberately breaking a reference *inside* a nested
tree, to directly observe the failure path fire on nested content, not
just this positive case) hasn't been run yet.

A second `offertree`, editing only the nested file:

```
SEE_COMMIT ts=1034650 parents=1 msg=second_recursive_offer
SEE_TREE entries=2
  entry type=2 id=859f9270f5c8bde9 name=SubA
  entry type=1 id=591254ca6e3e2a39 name=top.txt
SEE_END
```

Both entity IDs (`SubA`'s own tree entry, `top.txt`) are **identical**
to the first commit - real entity-ID continuity, through the real
command surface, confirmed by direct string comparison of the two
`SEE_TREE` outputs.

**Regression**: `experiments/65-head-deletion/test_driver.hc` (the
project's full command-surface test) re-run clean immediately after -
`offertree` being a new, additive command, no interference with the
existing flat `offer` path was expected, and none was found.

`tools/lint-package.sh` clean before every push. Package rebuilt to
213,071 bytes.

## Not yet done (see ADR 0010's own full scope)

- An adversarial `Check.HC` test against nested trees (deliberately
  breaking a reference inside one) - the positive case above is real,
  verified evidence that the check is already deep, not shallow.
- `Status.HC`/`Diff.HC`/rendering-command awareness of nested trees.
- Cross-directory rename/move detection.
- `offertree` doesn't support `correct`/`revert`/`reconcile` relations
  yet - a plain offering only.

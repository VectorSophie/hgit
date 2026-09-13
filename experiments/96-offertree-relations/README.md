# Probe 96 — `offertree` gains relation-tag support (`correcttree`/`reverttree`/`reconciletree`)

Status: **PASS.** Closes ADR 0010's own last remaining deferred item:
`offertree` didn't support the `correct`/`revert`/`reconcile` relation
tags flat offerings already had (ADR 0005/0006).

## What was built

`HgitOfferTreeWithRelation` (`Offer.HC`): `HgitOfferTree`'s own body,
parameterized with `relation_tag`/`relation_target`/
`relation_entity_id` and threaded into `CommitEncode` - exactly the
same relationship `HgitOffer` already has with
`HgitOfferWithRelation` (a thin `REL_NONE` wrapper over the
parameterized version). No change to `TreeBuildRecursive` or the tree-
building logic itself - only the commit's own relation fields differ.

Three new commands (`Hgit.HC`): `correcttree`/`reverttree`/
`reconciletree`, each taking `<repo> <target_hex> <entity_hex>
<dir_path> <message>` (same shape as flat `correct`/`revert`/
`reconcile`, with `dir_path` replacing `find_mask`), dispatching
through a shared `HgitOfferTreeRelatedCmd` helper - the same
relationship `HgitOfferRelatedCmd` already has with the flat
`correct`/`revert`/`reconcile` commands.

## Verified (real QEMU run, not fabricated)

A real nested repo (`top.txt`, `SubA/inner.txt`) offered via
`hgit offertree`, then a real `correcttree` editing the nested file
and relating it back to the first commit (unscoped - entity hex all
zeros):

```
SEE_COMMIT ts=1310928 parents=1 msg=correcting_nested_offer
SEE_RELATION tag=2 target=f681c2e1... entity=0000000000000000
SEE_TREE entries=2
  entry type=2 id=a712b9208adf4ceb name=SubA
    entry type=1 id=f5560f057f1ab34b name=inner.txt
  entry type=1 id=381d28b574ab0b0a name=top.txt
SEE_END
```

`tag=2` is `REL_CORRECTS` (`Commit.HC`'s own constant), correctly
recorded and read back; the nested tree structure is unaffected by
carrying a relation - `hgit check` on the result: `CHECK_OK objects=10,
CHECK_REFS_OK, CHECK_DANGLING_NONE`.

**Regression**: `experiments/65-head-deletion/test_driver.hc` (the
project's full command-surface test) re-run clean immediately after.

## Not yet done

With this, ADR 0010's full scope (real prerequisites, the recursive
primitive, real CLI wiring as a separate command, referential
integrity, and every rendering command's own nested-tree awareness
including relations) is complete. The one item ADR 0010 explicitly
keeps deferred, unchanged by this probe: cross-directory rename/move
detection (a file moved between directories keeping its identity).

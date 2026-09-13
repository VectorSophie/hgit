# Probe 93 — `hgit see` recurses into nested trees

Status: **PASS.** Closes one item on ADR 0010's own "not yet done"
list: `See.HC`/`HistoryDoc.HC`/`ReconcileDoc.HC`/`Graph.HC` awareness
of nested trees. This probe does the `See.HC` part - a real,
user-visible gap `hgit offertree` (probe 91) left open: before this,
`hgit see` only ever printed one flat level of a commit's tree, so a
subdirectory's own contents (built by `offertree`) were invisible
short of some other, not-yet-built command.

## What was built

`SeePrintTreeEntries` (`See.HC`): a recursive helper, generic
per-object-type - the same pattern `Check.HC`'s own `CheckMarkReachable`
already established for this project. Prints one tree's own entries,
and for any entry typed `OBJ_TREE`, looks up its child object (via the
same `IndexLookup` every other real command uses) and recurses into
it at one more level of indentation (two spaces per depth). A missing
child object prints a real, honest `(missing nested tree object)`
marker instead of silently stopping or crashing - the same
"don't hide a broken reference" stance `Check.HC`'s own
referential-integrity pass takes. `HgitSee`'s own inline flat loop was
replaced with one call to this helper at depth 0 - additive only, no
change to the flat (non-nested) case's own output.

## Verified (real QEMU run, not fabricated)

A real 2-level-deep nested repo (`SubA/SubB/deep.txt`, `SubA/mid.txt`,
`top.txt`) offered via `hgit offertree`, then `hgit see` on the
resulting commit:

```
SEE_TREE entries=2
  entry type=2 id=e64001523af35e4d name=SubA
    entry type=2 id=07135df1bd12036c name=SubB
      entry type=1 id=ed3d308e9080296e name=deep.txt
    entry type=1 id=8da3c08054028bfd name=mid.txt
  entry type=1 id=bf6223585c9e81eb name=top.txt
SEE_END
```

Both nesting levels render correctly, indented one level deeper each
time, with `deep.txt` genuinely reached through two real, recursive
`OBJ_TREE` lookups - not a synthetic/in-memory test, a real commit
built through the real `offertree` command surface.

**Regression** (both re-run clean immediately after, real QEMU runs):
- `experiments/91-hgit-offertree/test_driver.hc` - its own 1-level
  nested case now additionally shows `inner.txt` nested under `SubA`
  (the new, correct, additive behavior - previously invisible), with
  both entity IDs unchanged across the second commit, and `hgit check`
  still `CHECK_OK`.
- `experiments/65-head-deletion/test_driver.hc` (the project's full
  command-surface regression) - unaffected: a flat, non-nested tree's
  `SEE_TREE` output is byte-identical to before, since no entry in it
  is typed `OBJ_TREE`, so `SeePrintTreeEntries` never recurses.

**Real HolyC-caller gotcha applied again** (documented since probe 58):
redefining `See.HC` alone wasn't enough - `Hgit.HC`'s own dispatcher
(the caller of `HgitSee`) had to be re-pushed too, or it would keep
calling the previously-compiled version. Standard practice, applied
here without incident.

## Not yet done

- `HistoryDoc.HC`/`ReconcileDoc.HC`/`Graph.HC` still render only flat,
  one-level tree information (where they show tree entries at all) -
  real, separate follow-up work per ADR 0010's own scope, one command
  at a time.

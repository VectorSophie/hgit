# Probe 88 — real subdirectory support: the primitive question, answered (not the full feature, yet)

Status: **Research probe, PASS on the primitive question.** Confirms
recursive directory walking is real and buildable in HolyC on
TempleOS - a genuine prerequisite for ever lifting hgit's own "flat,
single-level tree only" limitation (`Tree.HC`'s own header comment,
`FORMAT.md`'s "No recursive-tree test" note). Does **not** implement
real subdirectory support in `hgit offer`/the object model - that
remains a separate, larger, real decision, scoped honestly below.

## What was found

**`FilesFind` is confirmed non-recursive**: a single wildcard call
(`FilesFind("C:/Home/P88*", 0)`) lists a directory's own immediate
entries only - a subdirectory shows up as one entry (size 0), not its
contents. Not a guess - directly observed: creating `P88SubTest/` with
a real file inside it, `FilesFind("C:/Home/P88*", 0)` returned exactly
two entries (`P88SubTest` itself, `P88Outer.txt`), never
`P88SubTest/inner.txt`.

**`CDirEntry` has a real, working `attr` field for telling a directory
apart from a file**: `attr & 16` is set for a directory, `0` for a
plain file - confirmed directly (`attr=16` for `P88SubTest`, `attr=0`
for `P88Outer.txt`), not assumed from a DOS-attribute-bit convention
guess. `file_attr` (a first guess at the field name) does not exist -
a real "Invalid member" compile error, corrected before running
anything.

**A real recursive walker, built on these two primitives, works
correctly**: `P88RecursiveWalk` (depth-tracked, straightforward
function recursion - no special HolyC quirk hit building it) correctly
descends into nested subdirectories and returns.

## Verified

`test_driver.hc` (`P88RecursiveWalkTest`): builds a real 3-level
directory structure (`P88Root/` with a top-level file, `SubA/` with
its own file plus a further-nested `SubAA/` with one more file, and a
sibling `SubB/` with its own file) and walks it:

```
P88_DIR depth=0 name=C:/Home/P88Root/SubA
P88_DIR depth=1 name=C:/Home/P88Root/SubA/SubAA
P88_FILE depth=2 name=C:/Home/P88Root/SubA/SubAA/deep.txt size=13
P88_FILE depth=1 name=C:/Home/P88Root/SubA/a1.txt size=7
P88_DIR depth=0 name=C:/Home/P88Root/SubB
P88_FILE depth=1 name=C:/Home/P88Root/SubB/b1.txt size=7
P88_FILE depth=0 name=C:/Home/P88Root/top.txt size=9
```

All four real files found, at the correct depth, in the correct
nesting - `.`/`..` correctly skipped (no infinite recursion), no
crash, no HolyC quirk hit.

## What this does NOT settle - real, separate, remaining work

This is a **research probe for one primitive**, not a design decision
to add subdirectory support. Actually supporting real directory trees
in hgit's own object model would need, at minimum:

- **Nested `OBJ_TREE` objects**: `Tree.HC`'s entry format already
  reserves a `child_type` byte that can be `OBJ_TREE` (not just
  `OBJ_BLOB`) - the byte layout was designed for this from the start
  (ADR 0001/0004) but no code has ever actually built or read a nested
  tree. This is real, not-yet-exercised format surface, per `FORMAT.md`'s
  own "No recursive-tree test" note.
- **Every tree-consuming command updated to recurse**: `Offer.HC` (tree
  building), `Status.HC`/`Diff.HC` (both rename-detection passes),
  `Check.HC` (referential integrity's own tree-child walk),
  `See.HC`/`HistoryDoc.HC`/`ReconcileDoc.HC`/`Graph.HC` (anything that
  prints or renders a tree's own entries) - all currently assume a flat,
  single-level entry list and would need real changes, not just this
  one new walker function.
- **A real product decision on scope**: does entity-ID/rename tracking
  (ADR 0004/0009) need to work *across* directory moves (a file moved
  between subdirectories, not just renamed in place)? That's a bigger
  question than this probe answers.

This probe closes the narrower, real question "can HolyC/TempleOS even
walk a directory tree recursively at all" (yes, cleanly) - it
deliberately does not attempt the much larger feature.

## Not yet done

- Nested `OBJ_TREE` object construction/parsing - genuinely untested
  format surface, not just unimplemented in the CLI layer.
- Wiring any of this into `Offer.HC` or any other real command.
- A real design decision on rename/entity-ID semantics across
  directory moves.

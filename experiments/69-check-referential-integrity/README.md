# Probe 69 — `hgit check` gets real referential integrity checking, plus a genuine test-harness limit found and fixed

Status: **PASS** — closes the gap probe 64's own README explicitly
flagged ("doesn't check anything beyond hash integrity... a real,
separate check, out of scope for this first slice"), modeled directly
on real `git fsck`'s own "missing object" check. Also found and fixed
a real, previously-unhit test-harness limit along the way: the
package had organically grown past the QEMU injection daemon's own
receive-buffer capacity.

## What was added

`src/hgit-cli/Check.HC`'s `HgitCheck` now does a second pass after the
existing hash-integrity check: builds the same `Index.HC` hash→offset
table every real command uses, then walks every commit and tree object
in the archive and confirms each of its own outgoing references
actually resolves to a real object in the same store:

- a commit's `tree_hash`
- every one of a commit's `parent_hash` entries
- a commit's `relation_target` (ADR 0005/0006), if it has one
- every tree entry's own child hash (blob or sub-tree)

This is a direct, scoped-down analogue of real `git fsck`'s own
"missing object" check (confirmed via `git-scm.com/docs/git-fsck`,
not assumed) - hgit's simpler model (no refs/reachability graph) means
this only needs "does every object currently in the store reference
other objects also in the store," not the fuller
dangling/unreachable-from-refs analysis real `git fsck` also does.

## A real test-harness limit found and fixed along the way

Pushing the rebuilt package (now 133,804 bytes) produced a
reproducible compile error (`Missing ';' at "T:0"`, cutting off
mid-source) on two separate attempts with identical output each time -
not random corruption (which would differ between attempts), a
genuine fixed-point truncation. Root-caused directly:
`experiments/01-temple-repl`'s own stage-1/stage-2 daemon receive
buffer (`Db`) has always been `MAlloc(131072)` (128KB, with a matching
`Di<131071` bound) - the package now exceeds that by 2,732 bytes,
silently truncating every push past that point. This project's own
package has simply grown past a limit nobody had reason to hit before
today. Fixed by rebootstrapping with a 512KB buffer (`Db=MAlloc(524288)`,
bound `Di<524287`) - confirmed the exact same package now compiles
cleanly (`COMPILE_OK`) with no other change. Also found and fixed a
real, separate build-order bug while wiring `hgit check`'s new code:
`Check.HC` was ordered before `Hex.HC` in `tools/build-package.sh`
(from probe 64, before `Check.HC` needed `HashToHex`) - moved it after
`Hex.HC`, matching real HolyC's no-forward-declarations rule.

## Verified

- A real, valid repo (`init`→`offer`→`offer`→`correct`) reports
  `CHECK_OK objects=9` and `CHECK_REFS_OK` - no false positives on
  genuinely correct data.
- Deliberately corrupted a real commit's `tree_hash` bytes directly in
  the raw `.hgs` file (flipping 8 bytes) and confirmed `hgit check`
  catches it via **both** independent mechanisms: `CHECK_FAIL
  objects=9 ok=8 corrupt=1` (the hash-integrity pass, since changing
  the tree_hash also changes the commit's own content, no longer
  matching its stored hash) and `CHECK_BROKEN_REF
  commit_tree_missing <hash>` / `CHECK_REFS_FAIL broken=1` (the new
  referential-integrity pass, since that mangled hash no longer
  resolves to any real object). Both fire correctly and independently
  - not a lucky coincidence of one corruption happening to trip both,
  each check's own logic is genuinely distinct.
- Re-ran a normal small-repo regression (`init`/`offer`/`status`/
  `historydoc`) afterward - unaffected.
- `tools/lint-package.sh` was run before every QEMU push this probe
  did - correctly reported no real errors each time (the ordering bug
  above was a *build-order* mistake the linter's own cross-file
  resolution doesn't model across a single already-concatenated file
  the same way it does across separate files - a real, honest gap in
  what `lint-package.sh` catches, noted for the record).

## Not yet done

- The fuller `git fsck` model (dangling/unreachable objects, which
  need a real reachability walk from every path's own HEAD) - this
  probe only checks "do stored references resolve," not "is every
  stored object actually reachable." A real future extension, not
  built here.
- `Object.HC`'s own `tagged[4096]` buffer (flagged as a lower-priority
  risk in probe 67) wasn't touched by this probe either.

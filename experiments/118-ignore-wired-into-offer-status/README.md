# Probe 118 — `.hgitignore` wired into `offer`/`offertree`/`status`/`statustree`

Status: **PASS**. Closes v1.8.0's own 3 required experiments
(`docs/ROADMAP-v1.8.md`), building on probe 117's standalone
primitive. Per ADR 0014 (`docs/adr/0014-ignore-rules.md`): ignore
rules are consulted per-candidate, only for names NOT already tracked
by exact name in the parent tree - never for already-tracked names.

## What was built

- `HgitOfferWithRelation` (flat `hgit offer`): derives `.hgitignore`'s
  path from `find_mask`'s own directory portion, loads it once, and
  skips (`OFFER_IGNORED <path>`) any matched candidate that isn't
  already tracked and matches a rule.
- `HgitStatus` (flat `hgit status`): same check, in the `!in_tree`
  branch only - an ignored, untracked candidate is never buffered as a
  `STATUS_NEW` candidate at all.
- `TreeBuildRecursive` (`offertree`) and `StatusTreeWalk`
  (`statustree`): both gained a real `rel_dir` parameter, threaded
  through every recursive call, empty at the discovery root and grown
  one segment per level - this is what lets the DIR_CONTENTS pattern
  kind (`generated/*`) correctly anchor to the true repository root
  rather than matching at arbitrary depth. An ignored, untracked
  subdirectory is skipped entirely - never recursed into, so nothing
  inside it can ever be reported as new either.
- **A real, separate gap found and fixed along the way**: a
  subdirectory whose entire real content got ignore-filtered away
  used to still leave a pointless EMPTY tree entry behind pointing at
  an empty tree object. Git's own real, well-known convention (never
  track an empty directory) is now matched generally in
  `TreeBuildRecursive` - a child tree with zero real entries after
  recursion gets no object stored and no entry encoded, not just for
  the ignore case.

## Verified

`test_driver.hc` (`P118IgnoreWiredTest`), two parts:

**Part A** (flat `offer`/`status`): a file tracked BEFORE any ignore
rule existed, then a rule added that would match its own name if it
were new (`*Tracked.txt`) - it survives a real edit and a re-offer
completely unaffected (`SEE_TREE` still shows it, `status` reports
`STATUS_UNCHANGED`, never hidden). A genuinely new file matching the
same rule is correctly skipped (`OFFER_IGNORED`), never entering the
tree.

**Part B** (`offertree`/`statustree`), the roadmap's own real example
grammar (`*.tmp`, `*.bak`, `build/`, `generated/*`, `!important.hc`)
against a real directory structure: `x.tmp` (NAME pattern),
`build/output.o` (DIR pattern - the whole subtree, never even
recursed into), `generated/direct.txt` (DIR_CONTENTS, a direct child
of the root-level `generated`) all correctly ignored and absent from
the final tree (confirmed via `hgit see` - `generated` itself doesn't
even appear as an entry anymore, thanks to the empty-tree fix above).
`SubA/generated/nested.txt` - a DIFFERENT directory that merely
happens to also be named `generated`, nested under `SubA` - correctly
SURVIVES, confirming `generated/*`'s own root anchoring (not matched
at arbitrary depth). `important.hc` survives via negation.
`.hgitignore` itself is tracked as an ordinary file (ADR 0014's own
decision - not special-cased). `statustree` afterward (unchanged)
reports nothing at all. `hgit check` confirms real integrity:
`CHECK_OK objects=8` (4 blobs, 3 trees, 1 commit - exactly matching
the surviving real structure), `CHECK_REFS_OK`, `CHECK_DANGLING_NONE`.

A real, honest debugging note: an earlier run of this exact probe
appeared to show a genuinely new file surviving ignore filtering
unexpectedly. Root-caused via direct diagnostics (not assumed): a
stale file left on disk from an EARLIER run of this same probe (this
is a long-lived session; plain files persist across separate script
pushes, unlike the repo files this probe already `Del`'d) had already
been committed as tracked content during THIS run's own first offer,
before the ignore rule was even added - `already_tracked` correctly
protected it, exactly as ADR 0014 requires, but that meant the test
itself was checking the wrong thing. Fixed by cleaning up every real
plain file/directory this probe creates, not just its repo files, at
the very start - a real, generalizable lesson for any future probe
that writes plain files with fixed names in this same session.

`tools/lint-package.sh` clean throughout (only the 3 known
built-in-manifest gaps). Both the standing regression and the full
command-surface suite (`tests/full-regression.hc`) re-run clean.

## What this does not do

- Does not yet handle `.hgitattributes`/file modes - real, separate
  v1.8.1/v1.8.2 scope.
- Does not affect `hgit merge`'s own tree comparison - a real, later
  item in this same v1.8.x series ("merge behavior when ignore or
  attribute rules differ between sides").
- The empty-tree-entry fix is general (not ignore-specific) but was
  only actually exercised by an ignore-filtered case here - a
  genuinely empty directory on disk (never had any files) was not
  separately, directly tested, though the same code path handles it
  identically.

# hgit — project status (as of 2026-09-14)

This is a snapshot, not a replacement for `docs/research/10-product-proposal.md`'s
own dated, probe-by-probe narrative log (still the authoritative
chronological record) or the ADRs in `docs/adr/`. It exists because
that log is now long enough that "where do things actually stand"
deserves its own answer, separate from "what happened in what order."

## The one-paragraph version

hgit is a real, working, TempleOS-native version control tool: content-
addressed objects, nested-tree subdirectories, multi-parent merge
commits with a real three-way merge, typed relations, named paths with
undo/redo, and a DolDoc-rendered reconciliation view - all implemented
in native HolyC, verified on real (QEMU-hosted) TempleOS, not
simulated or assumed. 19 tagged releases exist (v0.10.0 through
v1.7.7), 13 ADRs document real, evidence-backed architectural
decisions, and 115 numbered probes (`experiments/`) each pair one
concrete question with a real, captured answer. M0 through M4 are
functionally complete by their own original acceptance criteria; M5
was never concretely scoped and remains an open bucket of flagged-but-
undesigned candidates (see below).

## Milestone status

**M0 (bootstrapping the environment) — done, all 7 acceptance boxes
checked** (see doc 10's own M0 section): TempleOS boots and can be
driven/tested automatically via QEMU + COM2 injection; canonical
encoding, BLAKE2b-512, a tiny object archive, and a versioned `.HGS`
header all work natively.

**M1 (core command surface) — done**: `init`/`offer`/`status`/
`history`/`see` all real, wired, and tested against real persisted
repos across QEMU reboots.

**M2 (operation log, undo/redo) — done**: every offer/correct/revert/
reconcile logs a real prev→new HEAD transition; `undo`/`redo`/
`operation history`/`operation restore` all real and verified,
including against real merge commits (probes 114/115).

**M3 (stable entity identity, typed relations) — done**: a random
8-byte entity ID per tree entry, carried forward across exact-content
AND fuzzy (edited) renames (ADR 0004/0009); a real relation vocabulary
(CONTINUES/CORRECTS/REVERTS/RECONCILES, ADR 0005) scoped to a specific
entity (ADR 0006).

**M4 (executable DolDoc reconciliation) — done**: `historydoc`,
`reconciledoc`, `reconcileoverview`, and `graph` all render real
DolDoc documents from real repo state, confirmed to actually display
correctly in TempleOS's own `Ed()` (not just byte-correct output).

**M5 — never concretely scoped.** No fixed milestone definition exists
for "M5" in any doc. What exists instead is a real, honestly-logged
list of flagged candidates for "whatever comes after M4," none
designed or started:
- Sapling-style cascading `amend`/rebase (a real, different-in-kind
  departure from hgit's own "nothing is ever rewritten" stance -
  `docs/research/04-vcs-comparison.md`).
- GitButler-style simultaneous multi-path file assignment.
- Mercurial-style "phases" (protecting shared history).
- A real conflict-resolution mechanism for `hgit merge` (currently: a
  real conflict aborts the whole merge, zero side effects, by design -
  ADR 0011's own central open decision, deliberately not designed
  further without real evidence of need).
- Real criss-cross merge-base handling (`FindMergeBase`'s own
  documented remaining limitation, distinct from the real bug it *did*
  fix - see below).

## What's solid (real, verified, low remaining risk)

- **The whole object model**: blobs, trees (flat and recursive, ADR
  0010), commits (single- and multi-parent, ADR 0011), all
  content-addressed, all round-tripping through `hgit check`'s
  hash-integrity/referential-integrity/dangling-detection passes (ADR
  0013), confirmed to handle nested trees and multi-parent commits
  generically with zero special-casing.
- **File size**: no known object-content or per-file size ceiling
  remains anywhere in the write path (`ObjectPut`'s own shared cap,
  `Offer.HC`'s flat AND recursive per-file caps, `Status.HC`'s own
  separate cap - all found and fixed this session, v1.7.2-v1.7.4).
- **Merge**: a real, working three-way merge, flat and recursive,
  fast-forward and already-up-to-date shortcuts, honest conflict
  detection. `FindMergeBase` itself had a real, confirmed correctness
  bug (parent[0]-only chain walk silently returning a stale, wrong
  base once a real merge commit existed in either side's ancestry) -
  found via a deliberate, real reproduction and fixed (v1.7.5, a real
  ancestor-set BFS over every parent). `undo`/`redo`/`operation
  restore` all confirmed safe against real merge commits afterward.
- **Format versioning**: a real, honest gap (the policy said bump
  `format_version` on a breaking change; practice never did, across
  three real breaking changes) found and corrected (v1.7.7) - new
  repos now write version 2, and `hgit check` actually shows it.
- **Packaging**: `packaging/HgitAll.HC` is the real release artifact,
  attached to every tagged GitHub Release; `tools/build-package.sh`/
  `tools/lint-package.sh` catch real errors (including HolyC's own
  reserved-name quirks) before anything reaches QEMU.

## What's genuinely still open (real, not hypothetical)

- **No conflict-resolution mechanism for `hgit merge`** - a real
  conflict still aborts the whole merge. The single most consequential
  open design question in the whole project (ADR 0011's own words),
  deliberately not designed without real evidence a total abort is a
  practical burden.
- **Genuine criss-cross merge-base ambiguity** (multiple real lowest
  common ancestors, no single correct answer) - `FindMergeBase`'s
  fixed version is a real ancestor-set BFS, a genuine improvement, but
  still doesn't attempt Git's own "recursive"/virtual-merge-base
  strategy for a genuinely ambiguous case. Not yet observed in any
  real workflow this project has built.
- **`hgit graph` doesn't render merge commits as a real DAG rejoin** -
  a merge commit shows as one plain line on its own branch's trunk,
  not a visually connected join between two branch groups. A real,
  substantially bigger feature, not scoped.
- **`Status.HC`'s fuzzy-rename buffer stays a fixed 512-byte-per-slot
  array** - a large file can't be the source or target of a
  similarity-based rename match (exact-content matching is
  unaffected). Fixing this needs a jagged/variable-offset layout, a
  real, bigger structural change, not attempted.
- **Index is still a linear scan in every real command** - a real,
  verified, O(1)-expected hash table exists standalone
  (`experiments/104-index-hash-table/`) but is deliberately unwired,
  no evidence yet that hgit's real scale (low hundreds of objects per
  repo) needs it.
- **Entity IDs and rename detection don't share information** - a file
  ADR 0009's own rename detector correctly identifies as renamed still
  gets a brand-new, unrelated entity ID under ADR 0004's own scope.
  Surfaced by the Breezy comparison (doc 04); no real workflow has
  needed them to agree yet.
- **Author/identity** on commits remains deliberately deferred -
  single-user, single-machine usage throughout this project's own real
  history so far.
- **Content-defined chunking, object-store compression** - both
  remain deliberately undecided, no real evidence of need at hgit's
  current scale.

## How this project works, if picking this up cold

Read `docs/research/00-research-index.md` first (a status table over
every research doc), then `docs/adr/` for the real decisions, then
`docs/research/10-product-proposal.md`'s own narrative log for the
dated, probe-by-probe story of how each decision was reached. Every
real claim in this file traces back to a numbered probe under
`experiments/` with its own README and captured serial-log evidence -
nothing here is asserted without one.

# hgit — project status (as of 2026-09-14)

This is a snapshot, not a replacement for `docs/research/10-product-proposal.md`'s
own dated, probe-by-probe narrative log (still the authoritative
chronological record) or the ADRs in `docs/adr/`. It exists because
that log is now long enough that "where do things actually stand"
deserves its own answer, separate from "what happened in what order."

**The active phase of work is `docs/ROADMAP-v1.8.md`** - the project
owner's own scoped brief for a v1.8.x "usability series" (ignore
rules, minimal attributes/modes, a complete three-way merge, conflicts
as persistent repository data, and the CLI/DolDoc UX to use all of
it). v1.8.0 (ignore rules, ADR 0014) and v1.8.1 (tracked file
attributes/modes, ADR 0015, including status/diff integration) are
released; merge's own mode 3-way handling (ADR 0011/0015, probe 121)
is done and pending its own v1.8.2 release. Read that file before
picking the next v1.8.x item.

## The one-paragraph version

hgit is a real, working, TempleOS-native version control tool: content-
addressed objects, nested-tree subdirectories, multi-parent merge
commits with a real three-way merge, typed relations, named paths with
undo/redo, a DolDoc-rendered reconciliation view, a real `.hgitignore`
mechanism (v1.8.0), and (as of v1.8.1) a real `.hgitattributes`/file-
mode mechanism surfaced in status/diff and validated by check - all
implemented in native HolyC, verified on real (QEMU-hosted) TempleOS,
not simulated or assumed. Tagged releases exist from v0.10.0 through
v1.8.1 (v1.8.2, merge's own mode 3-way handling, pending its own
release), 15 ADRs document real,
evidence-backed architectural decisions, and 120+ numbered probes
(`experiments/`) each pair one concrete question with a real, captured
answer. M0 through M4 are functionally complete by their own original
acceptance criteria; M5 was never concretely scoped, and its own real
candidates are being absorbed into the more concretely-scoped v1.8.x
usability series instead (see `docs/ROADMAP-v1.8.md`).

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
- **Ignore rules** (v1.8.0, ADR 0014): a small, deterministic
  `.hgitignore` grammar (name/directory/anchored-directory-contents
  patterns, negation) wired into `offer`/`offertree`/`status`/
  `statustree`. The one safety property that matters most - ignore
  only ever hides discovery of untracked material, never an
  already-tracked file - is enforced structurally (checked before any
  ignore lookup happens at all), not bolted on. Found and fixed a real
  related gap along the way: a subdirectory whose entire content got
  ignore-filtered away used to leave a pointless empty tree entry -
  now matches Git's own real convention of never tracking an empty
  directory, generally, not just for the ignore case.
- **Tracked file attributes/modes** (v1.8.1, ADR 0015, `format_version`
  bumped 2 -> 3): a `.hgitattributes` grammar (`text`/`binary`/
  `executable`, reusing `.hgitignore`'s own pattern engine) plus
  Git's real NUL-byte auto-binary-detection heuristic, wired into
  `offer`/`offertree`. Mode is a commit-level side-channel
  (`OBJ_ATTRS`, entity-ID-keyed) rather than embedded in tree entries
  - a deliberate choice after measuring the alternative's real blast
  radius (8 files hand-parse tree-entry bytes; only 3 call
  `CommitEncode`). `status`/`statustree` and `diff` both surface a
  pure mode change (no content edit) independently of the existing
  UNCHANGED/MODIFIED verdict. Found and fixed a real related gap along
  the way: `check`'s own reachability walk didn't know about
  `attrs_hash` at all, so every repo's own attrs object showed up as a
  false `CHECK_DANGLING` (mislabeled as a blob, too) - closed by
  wiring the same commit-edge walk every other reference already
  gets.
- **Merge mode 3-way merge** (v1.8.2 pending release, ADR 0011/0015,
  probe 121): `hgit merge` now resolves file mode as a wholly separate
  3-way decision from content - a file's bytes and its mode can each
  change independently, each surviving entity's mode resolved
  base/ours/theirs the same way content already is, and a genuine
  mode-only conflict (both sides changed mode, differently) is
  reported and aborts the whole merge exactly like a content conflict,
  not silently guessed. Closes `docs/ROADMAP-v1.8.md`'s own
  "mode-only changes" gap and the real TODO `Merge.HC`'s own header
  comment used to carry. One real, honest, narrower limitation
  remains: a mode-only change on the side a file gets DELETED from
  isn't itself detected as a conflict, since the existing edit-vs-
  delete decision only ever consults content - not attempted.
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

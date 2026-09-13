# VCS comparison

Started (jj + Fossil + Sapling + Mercurial + GitButler + Pijul, the
closest analogues to hgit's stated goals per the product thesis
itself); Darcs/Breezy still unstarted.

## Verified documentation — Jujutsu's operation log

Source: `docs.jj-vcs.dev/latest/operation-log/`. An "operation" is any
repo-changing action; each one captures a complete "view" snapshot of
repo state (bookmarks, tags, Git refs, heads, working-copy commit), plus
parent-operation references and metadata (timestamp, user, host,
description). `jj op log` shows the history of operations, distinct from
commit history: **commits track what code changed; operations track how
the repository (as a whole, including refs/working-copy) changed.**
`jj undo` removes operations one at a time; `jj op revert` reverts a
specific non-recent operation; `jj op restore` jumps the whole repo back
to an earlier operation's view.

**Direct match to the product thesis's own operation-log design** (`hgit
operation history` / `hgit operation restore` / `hgit undo`/`redo`) —
this isn't a novel design hgit is inventing, it's adopting jj's proven
one. Nothing here contradicts the brief's plan; if anything it's
reassuring that a shipped, well-regarded VCS made the same architectural
bet.

## Verified documentation — Fossil's delta format

Source: `fossil-scm.org/.../delta_format.wiki`. A delta is
`<header>\n<segments><trailer>`: header is just the target length in
bytes as decimal text; trailer is a checksum (sum of the target's bytes
as 32-bit big-endian words, mod 2^32-1) followed by `;`. Segments are
either `N:bytes` (insert N literal bytes) or `N@M,` (copy N bytes from
offset M in the source; N=0 means "copy to end"). All integers use a
base-64-like encoding (6 bits/char, MSB-first, alphabet
`0-9A-Za-z_~`) — not the same as normal base64.

**This is about as simple and human-auditable as a binary-diff format
gets** — a real, shipped alternative to the brief's own
"prefer readable algorithms over marginal compression" instinct, worth
weighing seriously against a from-scratch design once hgit needs delta
compression (not yet — doc 06 notes compression/chunking is still
unstarted). The text-based, self-describing structure (length-prefixed,
checksummed, ASCII-safe) is a good fit for the brief's "small auditable
native format over maximal ratio" preference, and for RedSea's
contiguous-file constraint (doc 01) since it's a flat byte stream, not a
structure needing random-access mutation.

## Verified documentation — Mercurial's obsolescence markers

Source: `wiki.mercurial-scm.org/ChangesetEvolution`,
`mercurial-scm.org/help/topics/evolution`. An obsolescence marker
records four things: the predecessor changeset, its potential
successor(s), a timestamp, and the user who performed the rewrite.
Successors aren't fixed to exactly one: **zero successors marks a
prune** (the changeset is just gone, no replacement), **multiple
successors marks a split** (one changeset became several), and a
single successor covering multiple predecessors marks a fold. An
obsolete changeset is neither deleted nor mutated in place - it stays
in the repository, just hidden from normal view (recoverable, not
gone), and markers themselves "can be exchanged without any of the
precursor changesets" over push/pull, so a repo can learn "commit X
was superseded by Y" without ever holding X's own full content. A real
constraint the docs are explicit about: **only draft and secret-phase
changesets can be altered this way - public changesets are immutable**
once shared, specifically to prevent divergent rewrites of the same
history across collaborators.

**Comparison to hgit's own model**: structurally close to what hgit
already has, via a different mechanism. hgit's own non-destructive
history (ADR-driven: `undo`/`redo`, ADR 0004's rename-preserving entity
IDs, and `Check.HC`'s own `CHECK_DANGLING` reachability report, probe
72) already treats "no longer on any real path's own history" as the
same kind of soft, recoverable state Mercurial calls "hidden" -
neither approach ever destroys the underlying object. The one real gap
this comparison surfaces: hgit has no concept matching Mercurial's
**phases** (draft/public/secret) - nothing currently distinguishes
"freely rewritable" history from "already shared, should stay
immutable." This doesn't matter yet, because hgit's own `export`/
`import` (probe 45) is a whole-repo file copy, not a real distributed
push/pull with independently-evolving copies of the same repo - the
scenario phases exist to protect against (two collaborators rewriting
the same shared history differently) can't currently happen. A real,
concrete flag for **if** hgit ever grows a real multi-remote
push/pull model: revisit whether some phase-like distinction becomes
necessary then, rather than guessing at one now with no evidence it's
needed - the same "don't design ahead of real, evidenced need" stance
this project already takes toward, e.g., object-store compression
(see the Fossil section above) and cross-directory rename detection
(ADR 0010).

## Verified documentation — Sapling's undo/absorb/stacks model

Source: `sapling-scm.com/docs/overview/undo/` and
`sapling-scm.com/docs/commands/absorb`. Sapling keeps "a full record of
the mutation history of commits"; `sl undo` reverts the commit graph to
its state before the last graph-changing command (repeatable, walking
further back each time), `sl redo` reverses an undo. Its own docs draw
a real distinction hgit's own design already independently matches:
undo is scoped to **the commit graph**, not the working copy - separate
commands (`sl uncommit`/`sl unamend`) handle undoing a commit or amend
back into pending working-copy changes, rather than one undo command
covering everything. An interactive mode (`sl undo -i`) previews the
consequence before committing to it, color-coding commits that would
be removed vs. kept - a real, concrete safety-UX idea (preview before
acting), not implemented anywhere in hgit yet.

`sl absorb` is a distinct, more novel feature with no equivalent in
hgit today: given uncommitted working-copy changes, it automatically
figures out *which prior commit in the current stack* each changed
hunk actually belongs to, and amends it into place there rather than
appending a new commit - "fixing up" earlier history automatically
instead of asking the user to pick a target. Real limits: an
ambiguous hunk (no single clear owning commit) is left untouched in
the working copy rather than guessed at; it refuses to touch public,
merge, or otherwise immutable commits (a real safety boundary against
rewriting shared/pushed history); commits that end up empty after
absorbing are deleted automatically.

Source: `sapling-scm.com/docs/overview/stacks/`. A "stack" is Sapling's
own name for a linear sequence of dependent commits worked on
together - editing one in the middle (`sl goto` to it, edit, `sl
amend`) automatically rebases every commit above it in the same stack
to keep the whole sequence consistent, rather than leaving later
commits pointing at a now-stale parent. Real navigation commands
(`sl prev`/`next`/`top`/`bottom`) move through a stack without
remembering hashes. Sapling's own docs don't spell out whether this
automatic cascading rebase uses the identical obsolescence-marker
machinery `sl undo` itself relies on (both draw on the same underlying
"full record of the mutation history of commits," per Sapling's own
phrasing, but the exact mechanism tying `amend`'s own cascade to that
record isn't detailed in the fetched page) - not verified further here,
flagged honestly rather than guessed at.

**Relevance to hgit**: a real, structurally different concept from
anything hgit has - hgit has no `amend`/rebase of any kind. A
committed object is immutable; the closest analogues are `correct`
(ADR 0005/0006, names a NEW commit relating to an old one, doesn't
rewrite it) and `hgit merge` (ADR 0011, also only ever adds new
commits). Automatically cascading a mid-stack edit through every real
descendant commit would mean hgit committing to real, in-place history
rewriting for the first time - a substantial, real departure from this
project's own "nothing is ever deleted or rewritten, only added to or
pointed away from" stance (the same stance ADR 0011's own total-abort-
on-conflict decision and the non-destructive `undo`/`redo` model both
already rest on). Not adopted, no evidence yet hgit's real usage needs
it - a real, well-scoped M5-or-later candidate if the brief's own
future scope calls for it, distinct in kind (not just scope) from every
other item already flagged on this list.

**Relevance to hgit (undo/absorb, unchanged from before)**: the graph/
working-copy undo split is already how hgit's own design works by
construction (`hgit undo`/`redo` operate on `Meta.HC`'s operation log,
entirely separate from what `hgit offer` does to the working
directory) - Sapling's docs are confirming an existing choice, not
suggesting a change. `absorb`'s idea - automatically routing a change
to the right prior commit instead of always appending - is a genuinely
new concept relative to anything hgit has built (M0-M4's own
`correct`/`revert`/`reconcile` all name an explicit target commit; none
infer one from content). Real candidate for real M5-or-later feature
work if the brief's own future scope wants it - not attempted here, no
evidence yet that hgit's object model needs to change to support it (a
`correct` already targets an arbitrary prior commit; the missing piece
would be *picking* that target automatically from a diff, not the
storage underneath it).

## Verified documentation — GitButler's virtual branches

Source: `docs.gitbutler.com/features/virtual-branches/virtual-branches`,
`docs.gitbutler.com/overview`. A **target branch** is the workspace's
own reference point - "whatever your concept of 'production' is"
(typically `origin/main`) - and every virtual branch exists relative to
it. Real Git allows exactly one `HEAD`/one index at a time; GitButler
instead shows several virtual branches ("lanes") applied to the SAME
working directory simultaneously, each with its own staging area -
uncommitted changes across different files (or, per other GitButler
material, individual hunks) get assigned to different lanes, then each
lane commits independently. Committing a lane isn't a partial/patch
commit: GitButler "calculates what that branch would have looked like
if the changes you dragged onto it were the only things in your
working directory and commits a file tree that represents that work"
- a real, full synthetic tree, computed fresh per lane at commit time,
not a diff-of-a-diff. Merges are guaranteed conflict-free between
lanes precisely because they all originate from one real working-
directory snapshot - "you're essentially starting from the merge
product and extracting branches of work from it."

**Comparison to hgit's own model**: a real, structural difference, not
just a naming one. hgit's own named paths (`Paths.HC`, `path new`/
`path go`) are sequential - exactly one path is "current" at a time
(the same shape real Git branches have: one `HEAD`, switch to work on
another), and `hgit offer`/`offertree` always commits the WHOLE
current working directory against whichever path is active. There is
no mechanism for assigning different uncommitted files (or parts of
one file) to different paths from a single working-directory snapshot
the way GitButler's lanes do - that would require hgit's own commit-
building code (`Offer.HC`/`TreeBuildRecursive`) to filter which real
on-disk files count as "this path's own change" per offer, a real,
substantial redesign, not a small addition. No evidence yet that
hgit's own real usage needs this (every probe and real workflow this
project has actually built has one clear "what am I working on right
now" context) - flagged as a real, well-scoped candidate for M5-or-
later feature work if the brief's own future scope calls for it, not
designed now.

## Verified documentation — Pijul's patch theory (comparison only, per the brief's own caution)

Source: `pijul.org/manual/theory.html`. Pijul represents a repository
not as a sequence of snapshots but as a directed graph of TEXT LINES:
each vertex is a line of content, each edge (labelled with the
change/patch that created it) is either "alive" or "deleted" - a
delete is a real edge relabeling, never a destructive removal. A patch
is the graph operation that adds vertices/edges or relabels existing
ones; two patches that touch independent parts of the graph provably
commute (applying either order gives the same result), because every
vertex's own identity (the hash of the change that introduced it, plus
a position within that change) never depends on when or in what order
a patch was applied.

**The one detail most relevant to this project's own just-finished
merge work (ADR 0011)**: Pijul's own conflicts are not a special state
requiring immediate resolution - they're real, well-defined GRAPH
conditions the theory itself already models (two alive vertices with
no path between them either way; alive vertices with paths in both
directions, a cycle; or "zombie" vertices) and the repository can
represent and carry them forward as real, valid, non-destructive
state, without forcing an immediate all-or-nothing resolution.

**Comparison to hgit's own model**: a real, instructive contrast, not
a design hgit adopts outright (the brief itself warns against adopting
patch theory without real evidence, and hgit's own object model -
content-addressed blob/tree/commit - is nothing like Pijul's line-level
graph; adopting the theory itself would be a from-scratch rewrite, not
a feature). What IS worth naming honestly: ADR 0011's own real decision
sits at the opposite extreme from Pijul's - a real conflict in `hgit
merge` aborts the WHOLE operation with zero side effects, forcing an
immediate, all-or-nothing resolution outside hgit, rather than
representing the conflict itself as real, recoverable, inspectable
state the way Pijul's model does. This is a real, legitimate design
point for "what would justify revisiting" ADR 0011's own current
stance (already flagged there: "real usage where a genuine conflict is
common enough that a total abort is a real practical burden") - if
that ever happens, Pijul's own idea (represent an unresolved conflict
as a real, first-class, inspectable object rather than only either a
full commit or nothing) is a real, concrete alternative shape to
consider, distinct from Git's own file-level conflict-marker approach
already noted in `docs/research/05-git-internals-and-product-practice.md`.
Not designed further here - flagged, matching this project's own
"don't design ahead of evidenced need" stance.

## Architectural implications so far

- Adopt jj's operation-log/commit-history separation as designed in the
  product thesis — this comparison found no reason to deviate.
- ~~When hgit-core needs delta compression... prototype Fossil's delta
  format~~ **Done** (ADR 0008, `experiments/68`/`77`/`79`/`80`/`82`/`83`):
  byte-level mechanics, a real root-cause reliability fix, a real diff
  algorithm, and a similarity measure all built and verified - wired
  into `hgit offer`/`status` for fuzzy rename detection (ADR 0009,
  probes 84/85), not (yet) for object-store compression itself, which
  remains a separate, undecided question.
- Sapling's graph/working-copy undo split confirms hgit's own existing
  design rather than suggesting a change - no action needed.
- Sapling's interactive undo preview (color-coded before/after) is a
  real UX idea worth borrowing for a future `hgit undo` improvement -
  not built, no evidence yet it's worth the interactive-API cost this
  project's own `Ed()`/`DocForm()` findings (probes 54/63) show comes
  with any interactive TempleOS call.
- `absorb`'s auto-target-selection idea is a real candidate for future
  scope beyond M4, not required by anything currently built - flagged,
  not designed.
- Mercurial's obsolescence markers confirm hgit's own existing
  reachability/dangling model (probe 72) rather than suggesting a
  change - both treat "no longer on any real history" as recoverable,
  not destroyed. The one real gap surfaced (no phase-like distinction
  between rewritable and already-shared history) is flagged as a
  future concern IF hgit ever grows real multi-remote push/pull, not
  designed now - no current evidence it's needed, since `export`/
  `import` (probe 45) doesn't create independently-evolving copies of
  the same repo.
- GitButler's per-file/hunk-to-lane assignment from one working
  directory is a real, structurally different feature from hgit's own
  sequential named-path model (one active path at a time, the whole
  working directory committed against it) - not adopted, no current
  evidence any real workflow needs simultaneous multi-path assignment;
  flagged as a real, well-scoped M5-or-later candidate, same treatment
  as `absorb`'s auto-target-selection above.
- Pijul's own patch theory isn't adopted (a from-scratch object-model
  rewrite, not a feature - the brief's own caution against adopting
  patch theory without evidence applies directly), but its
  conflicts-as-real-recoverable-state idea is now a real, named
  alternative for ADR 0011's own "what would justify revisiting this"
  list - not designed, just flagged as a concrete shape distinct from
  Git's own conflict-marker approach, should real usage ever make
  ADR 0011's current total-abort stance a practical burden.
- Sapling's own "stacks" (cascading a mid-stack `amend` through every
  real descendant commit) isn't adopted - it's a different KIND of
  departure from anything else on this list, since it would mean hgit
  committing to real, in-place history rewriting for the first time,
  a substantial break from this project's own "nothing is ever
  rewritten, only added to or pointed away from" stance. Flagged as a
  real, well-scoped M5-or-later candidate distinct in kind (not just
  scope) from the others, not designed further here.

## Not yet done

Darcs (patch theory, same family as Pijul — comparison only, brief
explicitly warns against adopting without evidence) and Breezy. Lower
priority now that the seven most load-bearing comparisons (operation
log, delta format, undo/absorb, obsolescence markers, virtual
branches, patch theory, stacks) are done.

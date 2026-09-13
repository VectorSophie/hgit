# VCS comparison

Started (jj + Fossil + Sapling, the closest analogues to hgit's stated
goals per the product thesis itself); Pijul/Darcs/GitButler/Mercurial/
Breezy still unstarted.

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

## Verified documentation — Sapling's undo/absorb model

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

**Relevance to hgit**: the graph/working-copy undo split is already
how hgit's own design works by construction (`hgit undo`/`redo`
operate on `Meta.HC`'s operation log, entirely separate from what
`hgit offer` does to the working directory) - Sapling's docs are
confirming an existing choice, not suggesting a change. `absorb`'s
idea - automatically routing a change to the right prior commit
instead of always appending - is a genuinely new concept relative to
anything hgit has built (M0-M4's own `correct`/`revert`/`reconcile`
all name an explicit target commit; none infer one from content). Real
candidate for real M5-or-later feature work if the brief's own future
scope wants it - not attempted here, no evidence yet that hgit's
object model needs to change to support it (a `correct` already
targets an arbitrary prior commit; the missing piece would be
*picking* that target automatically from a diff, not the storage
underneath it).

## Architectural implications so far

- Adopt jj's operation-log/commit-history separation as designed in the
  product thesis — this comparison found no reason to deviate.
- When hgit-core needs delta compression (post-M1, per the milestone
  plan), prototype Fossil's delta format specifically before inventing a
  new one — it's simple enough to implement in HolyC without much risk,
  and self-describing enough to debug by eye.
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

## Not yet done

Pijul/Darcs (patch theory — comparison only, brief explicitly warns
against adopting without evidence), GitButler (virtual branches),
Mercurial/Breezy, and Sapling's own "stacks" feature (still unread).
Lower priority now that the three
most load-bearing comparisons (operation log, delta format) are done.

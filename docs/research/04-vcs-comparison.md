# VCS comparison

Started (jj + Fossil, the two closest analogues to hgit's stated goals
per the product thesis itself); Sapling/Pijul/Darcs/GitButler/Mercurial/
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

## Architectural implications so far

- Adopt jj's operation-log/commit-history separation as designed in the
  product thesis — this comparison found no reason to deviate.
- When hgit-core needs delta compression (post-M1, per the milestone
  plan), prototype Fossil's delta format specifically before inventing a
  new one — it's simple enough to implement in HolyC without much risk,
  and self-describing enough to debug by eye.

## Not yet done

Sapling (undo/absorb/stacks — informs `hgit undo` UX beyond the
operation-log mechanics), Pijul/Darcs (patch theory — comparison only,
brief explicitly warns against adopting without evidence), GitButler
(virtual branches), Mercurial/Breezy. Lower priority now that the two
most load-bearing comparisons (operation log, delta format) are done.

# ADR 0014 — `.hgitignore`: a small, deterministic ignore grammar

## Status

**Implemented.** Per the removed v1.8 roadmap's v1.8.0 scope. Written
before implementation (unlike most of this project's ADRs, which
followed real probes) because the roadmap itself demands the semantics
be defined and documented first - there is no ambiguity to resolve
from prior experiments here, only a real design choice to make and
record before writing `Ignore.HC`.

## Context

hgit's own `offer`/`offertree`/`status`/`statustree` all discover files
via `FilesFind(find_mask)` with no notion of "don't look at this." A
real ignore mechanism is table stakes for a usable local VCS - build
artifacts, backup files, and generated output shouldn't need to be
manually excluded from every `find_mask` by hand. Git's own
`.gitignore` grammar is large (glob classes, `**`, per-directory
files, negation interacting with directory exclusion in subtle ways);
this project's own standing discipline (ADR 0007's "no guessed cap,"
generalized) argues against copying all of it speculatively. The
roadmap's own example set is the real scope:

```text
*.tmp
*.bak
build/
generated/*
!important.hc
```

## Decision

**File**: `.hgitignore`, one per repository, read from the same
directory `find_mask`'s own directory portion names (matching how
`dir_prefix`/`find_mask` already work elsewhere - `Status.HC`'s own
`dir_prefix` convention). Read fresh from disk on every discovery call
- no caching, no staleness risk, matching hgit's own "no working-
directory checkout, read the real filesystem state at the moment of
the operation" design throughout.

**Grammar** (deliberately smaller than `.gitignore`, named explicitly):

- Blank lines and lines starting with `#` are comments - skipped.
- A line ending in `/` is a **directory-name pattern**: matches a
  directory with exactly that name, at ANY depth, and everything under
  it (recursively). Example: `build/` ignores `build/` and
  `SubA/build/` alike.
- A line ending in `/*` is a **directory-contents pattern**: the part
  before `/*` is a literal path, ANCHORED to the repository root (not
  matched at arbitrary depth) - it matches only DIRECT children of
  that exact directory, not its own subdirectories' contents. Example:
  `generated/*` ignores `generated/x.txt` but not
  `generated/sub/y.txt` or a `generated/` directory found elsewhere in
  the tree.
- Any other line with no `/` at all is a **name pattern**, matched
  against a candidate's own basename at ANY depth, supporting a single
  wildcard class: `*` matches any run of characters except `/` within
  that one name (no multi-segment `**`, no `?`, no character classes -
  not needed by the real scope above, not built speculatively).
- A leading `!` **negates** a pattern (of either of the two forms
  above minus the `!`): a name/path that an earlier rule would ignore
  is re-included if a LATER line's negated pattern also matches it.
  Patterns are evaluated top-to-bottom; the LAST matching line (negated
  or not) wins - the same real precedence rule `.gitignore` itself
  uses, kept because it's the one part of git's own grammar simple
  enough to implement exactly right rather than approximate.
- Any other slash-containing, non-`/*`-suffixed line (e.g. a literal
  `a/b.txt`) is **rejected as unsupported syntax** at read time
  (`IGNORE_UNSUPPORTED_LINE`, printed once per offending line) rather
  than silently guessed at - matching the roadmap's own explicit
  instruction to name the supported grammar and diagnose the rest,
  not attempt full compatibility.

**Matching happens per newly-discovered candidate, not as a blanket
pre-filter over `FilesFind`'s raw result list** - this is the
mechanism behind the safety rule below. For each name `FilesFind`
returns during `offer`/`offertree`/`status`/`statustree`'s own
discovery:

1. If the name is already present in the relevant OLD tree (by exact
   name, at this directory level) - it is **always** included,
   regardless of any ignore rule. Ignore rules are never consulted for
   an already-tracked name.
2. Only if the name is NOT already tracked is it checked against
   `.hgitignore`'s own rules; if ignored, it is treated exactly as if
   `FilesFind` had never matched it at all (absent from the new tree,
   absent from a `STATUS_NEW` report, invisible to rename-detection
   candidacy on the "new" side).

**The safe rule, stated plainly (per the roadmap's own explicit
preference): ignore affects discovery of untracked material. It never
silently removes or conceals an already-tracked entity.** Adding a
`build/` rule after `build/output.txt` was already committed does
NOT make `output.txt` disappear from status or a future commit's tree
- the user must explicitly delete it (the same real deletion detection
every other hgit command already has) for it to leave the tree. This
was the single most important safety property the roadmap itself
named, and it is enforced structurally (rule 1 above always wins over
rule 2), not by a separate special-case check bolted on afterward.

**The ignore file itself is an ordinary trackable file, not special
metadata.** `.hgitignore` is read fresh from disk at the moment of
discovery (rule above), but it is not automatically added to any tree
- a user who wants `.hgitignore` itself version-controlled includes it
in their own `find_mask` like any other file, same as every other
hgit file. No new persisted format field, no `Meta.HC` involvement -
this is a real, deliberate minimalism: the ignore file is an input to
a discovery-time decision, not repository state.

**No `format_version` bump.** Nothing about the on-disk object model,
tree-entry shape, or commit shape changes - ignore rules only affect
which candidate names ever reach `TreeBuildRecursive`/
`HgitOfferWithRelation`'s own tree-building loop in the first place.
`FORMAT.md` needs no update for this ADR.

## Alternatives considered

- **Full `.gitignore` grammar** (`**`, character classes, per-directory
  ignore files, `.git/info/exclude`-style global excludes): rejected -
  real scope creep with no evidence hgit's own real usage needs more
  than the roadmap's own five-line example set covers.
- **Treat `.hgitignore` as tracked, first-class repository metadata**
  (stored in `Meta.HC`, participating in the object model): rejected -
  it is real, ordinary file content a user can already track like
  anything else; inventing a second mechanism for the same real
  capability (persisting a file's content across commits) would be
  redundant with the object model that already exists.
- **Filter `FilesFind`'s raw result list up front, before any
  old-tree lookup**: rejected - this is exactly the shape of bug that
  would let an ignore rule silently hide an already-tracked file, the
  one behavior the roadmap explicitly named as unsafe. Checking
  old-tree membership FIRST, per candidate, is what makes the safety
  property structural rather than incidental.

## What this does not do

- No `**` recursive-glob support, no character classes, no `?`
  single-char wildcard - a real, named grammar limitation, not
  silently approximated.
- No per-directory `.hgitignore` files (only one, at the repository's
  own root/discovery-prefix level) - matches the grammar's own
  anchoring-to-root convention for `/*`-suffixed patterns.
- Does not affect `hgit merge`'s own tree comparison (which operates
  on already-committed trees, not live discovery) - ignore rules are
  purely a discovery-time filter for `offer`/`offertree`/`status`/
  `statustree`. Whether ignore/attribute rules should affect merge
  when they differ between the two sides being merged is real,
  separate scope for a later item in this same v1.8.x series (see
  the removed v1.8 roadmap's "merge behavior when ignore or attribute
  rules differ between sides").

## What would justify revisiting this

- Real usage where the five-pattern-class grammar above is
  insufficient for a real, encountered case (not a guessed future
  need).
- Real usage where per-directory ignore files would meaningfully help
  - not designed further here.

# ADR 0012 — Named paths: hgit's branch equivalent

## Status

**Implemented, written up retroactively.** This ADR documents a real
design this project already built and has relied on since M2 (probes
34/35/37, then re-platformed onto `Meta.HC` in probe 43) - it predates
this project's own ADR discipline (the first ADR, 0001, came later),
the same gap ADR 0011 itself noted in passing ("`Paths.HC`, ADR-less
since it predates this project's own ADR discipline") while building
`hgit merge` on top of it. Written now for the same reason ADR 0011
was: a real, substantial, still-live architectural decision deserves
one, whenever the gap is noticed, not just at the moment it's made.

## Context

The brief's own command vocabulary (`hgit path list/new/go/close`)
needed a real design for "what is a path, and how does the rest of the
command surface know which one is current." Two real constraints
shaped it:

- ADR 0003's own path-length lesson (a 33-character ceiling on any
  real file path `FileWrite`/`FileRead` will silently honor) meant a
  naive per-path sidecar-file scheme (one file per path's own HEAD,
  named using the path's own name) would eventually collide with real
  path names, not just hypothetically.
- No multi-parent commits existed at the time (that came later,
  probes 97-100/ADR 0011) - so "branch" here could only ever mean "a
  second named pointer sharing one object store," never a real
  divergent-then-reconciled DAG structure, until `hgit merge` closed
  that gap on top of this same design, unchanged.

## Decision

1. **A path is a name plus a HEAD pointer, nothing else.** No separate
   "branch object," no per-path metadata beyond its own HEAD hash and
   its declared existence. `"main"` is the one implicit, always-
   existing path - every repo has it from `init`, and it can never be
   closed (`PathClose` refuses).
2. **One "current path" pointer per repo**, stored alongside every
   other real piece of per-repo state. Every command that reads or
   writes "the" HEAD (`offer`, `offertree`, `status`, `history`, `see`,
   `undo`, `redo`, `merge`, ...) actually reads/writes **the current
   path's own HEAD** - `CurrentHeadRead`/`CurrentHeadWrite` are the one
   real seam every other file goes through, so switching paths
   (`path go`) transparently redirects every one of those commands
   without each needing its own path-awareness.
3. **`path new <name>` copies the CURRENT path's own HEAD at creation
   time** (all-zero if the current path has no offerings yet) - not an
   empty/independent history. This is a real, load-bearing design
   choice: it guarantees a real, findable fork point always exists on
   a direct ancestor path, which `Graph.HC`'s own fork-point search and
   `MergeBase.HC`'s own lowest-common-ancestor walk (ADR 0011) both
   depend on being true.
4. **Real platform migration, zero observable behavior change**
   (probe 43): the original scheme (probe 34) used one sidecar file
   per concern - `<repo_path>.paths` (a flat name list), `<repo_path>.head.<name>`
   (per-path HEAD), `<repo_path>.currentpath` (the current-path name) -
   directly vulnerable to ADR 0003's own path-length ceiling once a
   path's own NAME got folded into a real filename. Re-platformed onto
   `Meta.HC`'s combined per-repo file (ADR 0003) instead: every
   function's own signature and observable behavior is unchanged (verified
   directly - every real caller needed zero changes), but path names no
   longer affect any real filename at all, so the length constraint
   that used to apply to `repo_path + name` collapsed to just
   `repo_path` (`PathNameFits`'s own real, current implementation).
5. **Closing a path never destroys anything.** `PathClose` un-declares
   the name (it stops appearing in `path list`, and `path go` on it
   fails) - its own HEAD/operation-log records are left behind,
   orphaned but real, matching this project's own "nothing is ever
   deleted, only pointed away from" stance every other real command
   already takes. Closing the current path switches back to `"main"`.

## Alternatives considered

- **A real branch object, distinct from a plain HEAD pointer** (e.g.,
  something that could itself carry metadata, a description, protected
  status): rejected - no evidence any real hgit workflow needs more
  than "a name and where it points," and every real VCS this project
  has researched (`docs/research/04-vcs-comparison.md`) that has
  lightweight branches treats them the same minimal way.
- **`path new` starting an independent, empty history**: rejected -
  would need its own root-commit concept distinct from `main`'s, and
  would break the real guarantee (a findable fork point on a direct
  ancestor) `Graph.HC`/`MergeBase.HC` both now depend on.
- **Keep the original one-sidecar-file-per-concern scheme**: rejected
  once ADR 0003's own path-length lesson made clear it was a real,
  not just hypothetical, collision risk - re-platformed onto `Meta.HC`
  instead (Decision point 4).

## What this does not do

- No real multi-parent DAG existed when this was designed - `hgit
  merge` (ADR 0011) added that later, entirely on top of this same
  named-path model, unchanged.
- No protected/immutable paths (Mercurial's own "phases" concept,
  `docs/research/04-vcs-comparison.md`'s own comparison) - no evidence
  yet hgit's real usage (single-machine, `export`/`import` as whole-
  repo copies, not independently-evolving remotes) needs to distinguish
  "safe to rewrite" from "already shared."
- No branch descriptions, protection rules, or per-path configuration
  of any kind - a path is exactly a name and a HEAD pointer, nothing
  more.

## What would justify revisiting this

- Real usage needing a path to carry its own metadata beyond a name
  and a HEAD (a description, a protected/read-only flag) - no evidence
  of this yet.
- Real usage of a genuine multi-remote push/pull model, which is
  exactly the scenario that would make Mercurial-style phases (already
  flagged in `docs/research/04-vcs-comparison.md`) a real, evidenced
  need rather than a hypothetical one.

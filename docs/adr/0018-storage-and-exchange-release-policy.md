# ADR 0018 — 1.9.0: a scoped revision of the feature freeze

## Status

**Accepted for 1.9.0** (2026-09-27), working-session review pending.

## Context

`docs/STATUS.md` (as of 1.8.9) declared hgit "complete and feature-frozen":
no new features, contract fixes only, with `hgit-native` following the
contract from a pinned submodule. That policy was right for finishing the
1.8.x series and for letting a second implementation converge on a fixed
target.

Measured evidence now argues for a bounded exception. Both implementations
share three costs that grow with the number of commits and the number of
copies of a repository:

1. **Duplicate object storage.** Every `offer` appends a record for every
   file in the offered tree, changed or not (`ObjectPut` never asks whether
   the object already exists). Native benchmark, one file edited per commit:
   20 files x 2 KB reached 1.74 MB after 30 commits (32x the working set);
   2,000 files x 30 commits reached 101.9 MB holding 2,334 distinct objects
   (about 2.3 MB of distinct content, a 44x overhead).
2. **Whole-file work per command.** Every command reads and every writing
   command rewrites the entire archive; on TempleOS each lookup is also a
   linear scan comparing 64-byte hashes (`IndexLookup`).
3. **Whole-repository exchange.** `export`/`import` copy both files. A
   replica one commit behind is sent 835,650 bytes to receive 4,616 bytes of
   new objects (181x), and `import` overwrites the destination's mutable
   `.m` file (current path, undo/redo, in-progress merge).

Usage is shifting toward tools that commit far more often (tens of commits
per day per working copy), larger trees, and more replicas of one
repository. Those are exactly the workloads where the three costs above
compound.

## Decision

The feature freeze is **lifted for 1.9.0 only, and only for storage and
exchange**. The exception is deliberately narrow:

- In scope: writers that store each object once (ADR 0019); reader
  tolerances that make an interrupted write recoverable (ADR 0019); explicit
  maintenance (`compact`); a portable incremental exchange file (ADR 0020);
  the benchmarks and observability that justify them.
- Out of scope: new repository semantics, new object types in `.hgs`, new
  record tags in `.hgs.m`, commit identity/authentication, network transport,
  a daemon, and any automatic garbage collection or history truncation.
- After 1.9.0 the freeze resumes. Later work needs its own ADR.

`hgit` remains the owner of the canonical format and behavior. Any change
that alters what a conforming writer produces lands here first, with a
TempleOS implementation and golden fixtures generated on real TempleOS, and
only then is `hgit-native`'s contract pin advanced. Native-only accelerations
are allowed when they use rebuildable derived files and leave the canonical
bytes readable by TempleOS.

## Consequences

- `docs/STATUS.md` is revised to state the exception and its end.
- The 1.8.9 fixtures are preserved unchanged as legacy fixtures; 1.9 adds new
  fixtures for the revised writer behavior (ADR 0019).
- 1.9.0 is a minor version: `format_version` stays 4 (ADR 0019).

## What would justify revisiting this

If the exception grows into new semantics (rebase-like history editing,
partial replicas that promise absent objects, multi-writer operation
merging), that is a 2.0-scale decision and needs the freeze question asked
again from scratch, not an extension of this one.

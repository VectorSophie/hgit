# ADR 0020 — Incremental exchange with bundles

## Status

**Accepted for 1.9.0** (2026-09-27), working-session review pending.
Falls under ADR 0018's scoped exception. Byte-level spec: `BUNDLE.md`.

## Context

`export`/`import` copy both repository files. Measured (native benchmark): a
replica one commit behind is sent 835,650 bytes to receive 4,616 bytes of new
objects. `import` also overwrites the destination's `.hgs.m`, which holds its
current path, undo/redo logs and any in-progress merge: a whole-file copy is a
silent deletion of the recipient's mutable state. Neither file can be treated
as a sync unit.

## Decision

1. **A bundle is a separate, optional file** (`.hgb`), not a repository format
   change. It carries missing immutable objects plus a manifest of *proposed*
   path heads and *prerequisite* commits. `format_version` stays 4.
2. **Verify everything, then write.** Every record, the footer hash, all
   references and all prerequisites are checked before any byte of the
   recipient changes. Corrupt or incomplete input can never expose a head.
3. **Objects only; never `.hgs.m`.** Current path, undo/redo, merge state and
   closed-path markers stay local.
4. **Heads are proposals under the recipient's policy.** Fast-forward only when
   the local head is a proven ancestor. Divergent, closed-locally, or
   merge-in-progress paths are kept apart under `<path>@<label>`; nothing is
   overwritten, nothing is deleted, and every move is an operation-log entry
   that `undo` reverses.
5. **Deletion is never propagated.** Closed paths and undone commits are not
   announced. A recipient keeps them as it has them. (Advisory closed-path
   announcements are a reserved capability, not part of 1.9.)
6. **Idempotent and restartable.** Re-applying adds nothing. Interrupted
   applies leave at worst dangling objects that a re-run completes.
7. **Trust is stated, not implied.** A hash proves integrity, not origin. hgit
   has no identities; users compare the printed bundle id over a channel they
   trust. Nothing in the format claims otherwise.
8. **Prerequisites, not a Merkle protocol.** Incremental bundles name commit
   hashes the recipient must hold; a small `.hgh` have-file lets a sender pick
   them in one offline round trip. A second Merkle layer was rejected as
   unnecessary for a commit DAG whose frontier is already hash-addressed.
9. **Capability discipline.** Unknown required capabilities are refused;
   unknown optional ones ignored. None are defined in version 1.
10. **Native first.** Only `hgit-native` implements bundles in 1.9.0. TempleOS
    keeps `export`/`import`. A TempleOS reader is compatible by construction
    (an applied repository is an ordinary v4 `.hgs`); a TempleOS bundle
    implementation is deferred until it has a reason to exist.

## Rejected

- **Copying `.hgs`+`.hgs.m` as sync**: destroys local mutable state.
- **Auto-resolving divergence** (last-writer-wins by timestamp): timestamps are
  not comparable across replicas (ADR N-0001) and would silently drop history.
- **Promised/absent objects (partial replicas)**: would make `check` and
  offline guarantees misleading; design only, see the follow-up roadmap.
- **Directory-sharded history**: one honest logical history is a project
  invariant.

## Consequences

- The recipient can quantify savings: bundle bytes vs. whole-export bytes.
- `check` gains a non-`--serial` observability report (present/missing/corrupt/
  dangling), so applying a bundle is explainable; `--serial` output is
  unchanged.

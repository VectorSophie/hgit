# hgit v1.8.x — the usability series

**Status: in progress - v1.8.0 through v1.8.3 shipped, see this
document's own "Version sequence" section below for exactly what.**
This is the project owner's own written brief for this phase of work,
recorded here verbatim (reorganized only for headings) so it survives
across sessions and isn't reconstructed from memory. v1.5.0 through
v1.7.7 was real, verified internal work (see `docs/STATUS.md`), but for
hgit to be genuinely comparable to Jujutsu-like alternatives while
keeping its own identity, the owner scoped the following as v1.8.0's
real successor phase.

## Why this phase, and what it is not

M0–M4 built a real object model, undo/redo, entity identity, and a
DolDoc reconciliation view. What's missing for a genuinely usable local
VCS: knowing what NOT to track, knowing enough about a file to merge it
safely, handling every real merge outcome (not just the flat happy
path), and - the biggest structural gap - a merge conflict that
survives as real repository state instead of aborting the whole
operation. This phase is scoped tightly around exactly that: ignore
rules, minimal attributes/modes, a complete three-way merge, conflicts
as persistent data, and the CLI/DolDoc surface to use all of it. It is
explicitly NOT remotes, Git interop, GUIs, packfiles/GC, arbitrary
history rewriting, or semantic/AST merging - see "Out of scope" below.

## 1. Ignore rules

Implement a small, deterministic ignore system suitable for TempleOS.

Suggested file: `.hgitignore`

Initially support only rules that can be implemented clearly and tested
rigorously:

```text
*.tmp
*.bak
build/
generated/*
!important.hc
```

Define and document:

- whether patterns match names, paths, or both;
- directory-pattern behavior;
- negation precedence;
- slash normalization;
- whether the ignore file itself is tracked;
- interaction with `offer`, `offertree`, `status`, `statustree`, rename
  detection, and merge;
- whether an already-tracked file can become hidden merely by adding an
  ignore rule.

**Prefer the safe rule that ignore affects discovery of untracked
material but never silently removes or conceals an already tracked
entity.**

Do not attempt full `.gitignore` compatibility. Name the supported
grammar explicitly and reject or diagnose unsupported syntax where
reasonable.

## 2. Minimal attributes and file modes

Design the smallest useful tracked metadata model. At minimum
investigate: `text`, `binary`, `merge`, `diff`, `executable`.

A possible attributes file: `.hgitattributes`

Do not copy `.gitattributes` wholesale. Implement only semantics hgit
actually uses. Determine the real TempleOS filesystem semantics first
(what does RedSea/the real filesystem actually expose - permission
bits? an executable flag? nothing at all?), then define a portable
hgit representation rather than inventing Unix behavior TempleOS cannot
observe.

Required outcomes:

- deterministic text-versus-binary classification;
- explicit overrides through attributes;
- file mode/type stored in the repository where meaningful;
- mode/type changes surfaced in status and diff;
- binary files never fed blindly into a textual merge;
- unsupported filesystem types fail honestly;
- metadata participates in tree identity and integrity checking;
- persistent entity identity remains independent of content hash, path,
  and mode.

**Any persisted format change must bump the repository format version
and update `FORMAT.md`, readers, checks, fixtures, and compatibility
behavior.**

## 3. Complete three-way merge

Build on the existing real recursive merge implementation
(`Merge.HC`/`MergeBase.HC`, ADR 0011). Do not replace it. Close the
important remaining gaps:

- add/add;
- delete/delete;
- edit/delete;
- file/directory kind changes;
- mode-only changes;
- binary conflicts;
- rename-versus-edit;
- rename-versus-rename;
- moves across directories where identity provides enough evidence;
- multiple files competing for the same identity or destination;
- nested combinations of the above;
- merge behavior when ignore or attribute rules differ between sides.

Use persistent entity IDs where they provide stronger evidence than
path comparison. Do not silently invent identity or lineage when
candidates are ambiguous.

Keep criss-cross/multiple-best-base support out of scope unless it
naturally becomes necessary for correctness. If deferred, detect or
document it honestly (this is already ADR 0011's own documented
position - keep it that way unless real evidence changes it).

## 4. Conflict as repository data

Replace the current "detect conflict and abort everything" limitation
with a persistent, inspectable conflict model.

A conflict should preserve, at minimum: entity ID (if known), path or
competing paths, base state, current state, incoming state, conflict
kind, originating commits, applicable attributes, resolution state.

The representation must support file content, absence/deletion,
directories, modes, binary objects, and renames. Do not assume every
conflict consists of three text blobs.

A conflicted merge must become recoverable repository state, not
temporary marker text that can be lost.

Provide a coherent lifecycle such as:

```text
hgit merge <repo> <other-path>
hgit conflicts <repo>
hgit resolve <repo> <conflict> ...
hgit merge continue <repo>
hgit merge abort <repo>
```

The command grammar may be refined after inspecting the existing
dispatcher, but keep it concise and consistent with the rest of
`Hgit.HC`'s own dispatch style.

Required properties:

- unresolved conflicts survive restart;
- `hgit status` visibly reports them;
- `hgit check` validates all referenced objects;
- `undo` can return to the state before merge began;
- `redo` or operation restore behaves coherently;
- abort restores the exact pre-merge repository state;
- continuing is impossible while unresolved conflicts remain;
- resolving a conflict does not erase its base/ours/theirs evidence;
- the final merge commit has both real parents;
- resolution provenance remains inspectable afterward;
- imported/exported repositories preserve conflicted states;
- no conflict marker is written into source unless the user explicitly
  requests a textual materialization.

**Decide carefully whether conflict state belongs inside an immutable
commit/tree, operation state, repository metadata, or a combination.
Write an ADR before freezing the persisted representation** - matching
this project's own standing discipline (no ADR before its supporting
evidence exists; this is the one persisted-format decision in this
whole phase big enough to need one written before the freeze, not
retroactively).

## 5. Diff and merge UX

Make the new behavior usable from the real TempleOS interface.

Improve textual `status`, `diff`, `see`, and merge output so they
clearly distinguish: added, deleted, modified, renamed, moved, copied
(if supported), mode/type changed, binary changed, cleanly auto-merged,
unresolved conflict, resolved conflict.

Add a DolDoc conflict/reconciliation view that shows: base, current,
incoming, proposed or selected resolution, entity identity and
lineage, originating named paths and commits, conflict kind, relevant
attributes, live links to source or stored objects where feasible,
compilation/test results only when explicitly configured and actually
executed.

The interface may suggest consequences but must not silently decide
which side is correct.

For text conflicts, provide line-oriented three-way comparison or a
deliberately simpler readable presentation. For binaries, modes,
deletions, and renames, render structural choices rather than
pretending they are text.

Avoid building a large TUI framework. Improve the existing CLI and
DolDoc surfaces.

## Required experiments

Create small isolated probes before or alongside integration, same
`experiments/NNN-name/` + `test_driver.hc` + `README.md` +
`serial-log-evidence.txt` convention every prior probe in this project
has used:

1. Ignored untracked file does not appear or enter an offer.
2. Previously tracked file remains visible after becoming ignored.
3. Recursive ignore and negation behavior.
4. Text/binary classification and attribute override.
5. Mode-only change round trip.
6. Clean three-way text merge.
7. Edit/delete conflict.
8. Binary conflict.
9. Rename/edit merge preserving entity identity.
10. Cross-directory move conflict.
11. Conflict survives reload.
12. Resolve and continue produces a two-parent commit.
13. Abort restores the exact pre-merge state.
14. Undo/redo around conflicted and completed merges.
15. Export/import preserves conflicts and resolutions.
16. `hgit check` catches a missing conflict dependency.
17. DolDoc view renders a real unresolved and resolved conflict.

Add the stable cases to `tests/full-regression.hc` after their isolated
probes pass, same as every prior stable feature in this project.

## Engineering discipline

Work in small, coherent commits. Every v1.8.x release must:

- contain a meaningful user-visible or correctness improvement;
- be verified through real command-driven TempleOS execution under
  QEMU;
- include an isolated reproduction or acceptance test;
- pass the complete regression suite;
- preserve persistent entity identity and non-destructive history;
- update built-in help, README, relevant ADRs, `FORMAT.md`, and release
  notes;
- record remaining limitations honestly;
- bump the repository-format version whenever persisted semantics
  become incompatible;
- reject unsupported older/newer formats clearly or migrate them
  deliberately.

**A program-version patch bump and a repository-format bump are
separate decisions.** Do not assume `v1.8.3` implies repository format
3, or vice versa.

## Version sequence (provisional)

Keep this entire usability phase within the **v1.8.x series**. Each
version must be a real, tested vertical improvement, not merely a
version bump or documentation release.

```text
v1.8.0  ignore rules and recursive discovery behavior               [shipped]
v1.8.1  tracked attributes/modes, text/binary policy, AND status/    [shipped]
        diff integration (folded together - closely coupled enough
        to verify as one real release, per this section's own
        "don't force every release to exist" rule)
v1.8.2  merge's own mode 3-way handling (a real, separate slice of   [shipped]
        the "complete three-way merge" item below - the rest of
        that item, plus the persistent conflict model, still ahead)
v1.8.3  persistent conflict object/model + the resolve/continue/abort   [shipped]
        lifecycle's first slice (ADR 0016; take-ours/take-theirs only)
v1.8.4  conflict lifecycle: inspect, resolve, continue and abort
v1.8.5  remaining rename-, move-, delete-aware three-way merge gaps
v1.8.6  DolDoc and CLI diff/merge UX
v1.8.7  recovery, export/import, integrity and adversarial hardening
v1.8.8  full usability regression and documentation-accuracy sweep
```

This ordering is provisional. Move a feature earlier when it is a
genuine prerequisite, but keep the version series coherent:

- **v1.8.0–v1.8.2:** trustworthy filesystem inputs and metadata;
- **v1.8.3–v1.8.5:** complete conflict and merge semantics;
- **v1.8.6:** make those semantics understandable and usable;
- **v1.8.7–v1.8.8:** close correctness gaps exposed by real workflows.

Do not artificially force every release to exist. If two adjacent
items are too tightly coupled to verify independently, combine them and
renumber later versions. Conversely, do not split one implementation
into cosmetic releases merely to fill the sequence. **Update this
section's own version table in place if the real sequence changes** -
don't let it go stale the way other docs in this project have before.

## Out of scope for this whole phase

- remotes, push, fetch, or authentication;
- Git import/export;
- server protocols;
- GUI frameworks;
- packfiles, GC, or compression, unless a conflict-format dependency
  absolutely requires a small prerequisite;
- broad research unrelated to an immediate design decision;
- arbitrary history rewriting;
- full semantic/AST merging;
- perfect parity with Git or Jujutsu.

## For every release in this series

- run real TempleOS/QEMU tests;
- save command-output evidence (`serial-log-evidence.txt`, same as
  every prior probe);
- run the full regression suite (`tests/full-regression.hc`);
- update README, `FORMAT.md`, `docs/ARCHITECTURE.md`, `docs/STATUS.md`,
  built-in help, ADRs, and version strings;
- distinguish verified behavior from limitations, honestly;
- bump the repository format for incompatible persisted changes;
- confirm older repositories are rejected clearly or migrated
  deliberately;
- never silently reinterpret an older format.

## After v1.8.8

Do not immediately begin remotes or Git interoperability. First
evaluate whether hgit now satisfies the complete local workflow:

```text
discover
→ ignore/classify
→ offer
→ diverge
→ diff
→ merge
→ preserve conflict
→ inspect
→ resolve or abort
→ continue
→ undo/restore
→ export/import
→ check
```

If this workflow is genuinely complete and reproducible, treat v1.8.x
as the usable local-VCS series and only then propose the scope of
v1.9.0. Change this sequence if implementation dependencies demand it,
but do not publish patch releases for large new persisted models.

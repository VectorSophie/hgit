# ADR 0016: Conflict as repository data

## Status

Adopted. `docs/ROADMAP-v1.8.md`'s own "Conflict as repository data"
section (item 4) requires this ADR be written before the persisted
representation freezes - written here, before implementation, per that
rule and this project's own "no ADR before its supporting evidence
exists" standing discipline (the evidence here is ADR 0011's own real,
shipped merge implementation and its explicitly documented "total
abort" limitation, not speculation).

## Context

`hgit merge` (ADR 0011, extended for mode in the v1.8.2 follow-up)
currently has exactly one behavior on any real conflict, at any depth:
abort the whole merge with zero side effects. No commit is created, no
`HEAD` moves, nothing is written to the real repo file. This is
honest and non-destructive, but it means a conflict is never anything
a user can inspect, resolve piecemeal, or come back to later - the
entire evidence for *why* a merge failed (the base/ours/theirs state
that disagreed) exists only transiently, in memory, during the one
`hgit merge` invocation that found it, and is gone the moment that
process ends.

The roadmap requires replacing this with a persistent, inspectable
conflict model, with a specific list of required properties (survives
restart, `status`/`check` both understand it, `undo`/`redo` behave
coherently, abort still restores exact pre-merge state, resolving
doesn't erase evidence, the final commit has both real parents,
export/import preserve conflicted state, no textual conflict-marker
format is forced on the user).

## Decision

**Two real pieces, matching the split this project already uses
everywhere else between immutable content-addressed objects and
mutable per-repo metadata (`Meta.HC`, ADR 0003):**

### 1. `OBJ_CONFLICT` — a new immutable object type (tag 5)

One conflict's full evidence, content-addressed like every other
object, so it participates in `hgit check`'s existing referential-
integrity walk for free once wired in (the same generic
commit-edge-walk pattern `OBJ_ATTRS` already uses - see ADR 0015 and
`Check.HC`'s own `CheckMarkReachable`), gets included in `hgit
export`/`import` for free (the object archive is already copied
wholesale), and is never silently lost.

Content shape (flat, fixed-order fields - same style as `Tree.HC`/
`Commit.HC`'s own encodings):

```text
U8  conflict_kind      (bitmask: 0x01 = content differs, 0x02 = mode
                        differs, 0x04 = kind mismatch - a tree on one
                        side, a blob on another. Combinable: a real
                        file can conflict on content AND mode at once.)
U64 entity_id          (0 if no single shared identity applies - e.g.
                        a real add/add case, where each side minted
                        its own fresh entity ID per ADR 0004's own
                        "same name = same identity" scope note, not
                        this file's problem to reconcile)
U8  path_len
path_len bytes of path (the full, prefixed path at conflict time -
                        same convention Merge.HC's own conflict_names
                        list already uses)
For each of base/ours/theirs, in that fixed order:
  U8 present            (0 = absent on this side - a real, valid case:
                         deletion, or genuinely new on the other two)
  if present:
    U8  type            (OBJ_BLOB or OBJ_TREE)
    U8  mode             (ADR 0015 - 0 if not applicable/not a blob)
    64 bytes hash
```

No length limit beyond the format's own general one - a `path_len` up
to 255 covers every real path this project has ever produced (see
`docs/adr/0003-path-length-ceiling.md`'s own 33-character REAL
filename ceiling for a much tighter, unrelated constraint that does
NOT apply here, since paths live inside object content, not
filenames).

This one shape covers every real case the roadmap's own list names:
content conflicts (`conflict_kind & 0x01`), mode-only conflicts
(`0x02`, the v1.8.2 follow-up's own real gap - now given a real,
persistent representation instead of just aborting), a same-name
kind mismatch (`0x04`), and - by `present` being independently FALSE
on any side - absence/deletion on any side, including add/add
(`base.present == FALSE`, both `ours`/`theirs` present with different
content and no shared lineage) and delete/delete (never reaches this
object at all - `MergeTreesRecursive` already resolves that cleanly,
no conflict). Binary content is not special-cased at the format level
- a binary conflict is exactly a content conflict whose `ours`/
`theirs` blobs happen to be binary; nothing here assumes text.

### 2. In-progress merge state — `Meta.HC` (mutable, per current path)

An in-progress, not-yet-resolved merge is real, live, MUTABLE
operation state - not a permanent historical record - so it belongs
in `Meta.HC`'s combined per-repo metadata file (ADR 0003), the same
place `HEAD`/paths/undo-redo logs already live, not in the immutable
object graph. Two new tags, added the exact same way `META_TAG_OPLOG`/
`META_TAG_REDOLOG` were:

- `META_TAG_MERGE_STATE` (one record, keyed by the current path's own
  name, replaced-not-accumulated like `META_TAG_HEAD`): payload is
  `ours_head`(64) + `theirs_head`(64) + `base_head`(64) +
  `other_path_name` - everything needed to resume, complete, or abort
  the merge without re-deriving it. Its mere presence for a path IS
  the "a merge is in progress on this path" signal every other command
  below checks.
- `META_TAG_CONFLICT` (accumulates, one record per conflict, same
  shape as `META_TAG_OPLOG`'s append/pop-by-position pattern): payload
  is the `OBJ_CONFLICT` hash (64 bytes) + a resolution-state byte (0 =
  unresolved, 1 = resolved) + a resolution reference (64 bytes - the
  hash of the content the conflict was resolved to; meaningless while
  unresolved).

Both are plain `Meta.HC` records, so `hgit export`/`import`
(`Portable.HC`) preserve them automatically - `HgitCopyRepo` already
copies the whole `.m` file as opaque bytes, no per-tag awareness
needed there at all. This directly satisfies the roadmap's own
"imported/exported repositories preserve conflicted states"
requirement for free, as a consequence of the design already in place
for every other kind of repo metadata - not a new mechanism built for
this.

### Lifecycle, mapped onto the existing dispatcher

```text
hgit merge <repo> <other-path>   - unchanged surface; on a real
                                    conflict, now WRITES the
                                    META_TAG_MERGE_STATE +
                                    META_TAG_CONFLICT records (plus
                                    every real OBJ_CONFLICT object)
                                    instead of aborting with nothing
                                    persisted. Still zero side effects
                                    on the OBJECT tree/commit itself -
                                    only the in-progress metadata and
                                    the conflict evidence objects are
                                    new; HEAD does not move yet.
hgit conflicts <repo>             - lists every META_TAG_CONFLICT
                                    record for the current path's
                                    in-progress merge (if any),
                                    resolved and unresolved both -
                                    "resolving a conflict does not
                                    erase its base/ours/theirs
                                    evidence" falls out naturally
                                    since the OBJ_CONFLICT object is
                                    never deleted, only the metadata
                                    record's resolution-state byte
                                    changes.
hgit resolve <repo> <conflict> ...- marks one conflict resolved,
                                    recording which content it
                                    resolved to (take-ours/take-theirs
                                    to start - the common, unambiguous
                                    case; an explicit replacement
                                    content is a real, separate,
                                    well-scoped follow-up, not
                                    required for a real, useful first
                                    slice).
hgit merge continue <repo>        - only proceeds once every real
                                    conflict for the in-progress merge
                                    is resolved (roadmap: "continuing
                                    is impossible while unresolved
                                    conflicts remain"). Builds the
                                    final merged tree from every
                                    resolution plus every entry that
                                    never conflicted, creates the real
                                    two-parent merge commit (same
                                    `CommitEncode`/`OpLogAppend`/
                                    `CurrentHeadWrite` sequence
                                    `HgitMerge`'s own existing success
                                    path already uses), and clears the
                                    META_TAG_MERGE_STATE/
                                    META_TAG_CONFLICT records for this
                                    path - the OBJ_CONFLICT objects
                                    themselves stay in the archive
                                    forever (content-addressed,
                                    already referenced from nothing
                                    once cleared, but never deleted -
                                    matching this project's own
                                    "history is append-only" stance) -
                                    a real, separate follow-up question
                                    (not decided here) is whether the
                                    finished merge commit should ALSO
                                    reference them for permanent
                                    resolution provenance, the same way
                                    it already references `attrs_hash`
                                    - a real, small, additive
                                    `CommitEncode` extension if so, not
                                    a redesign.
hgit merge abort <repo>           - discards the META_TAG_MERGE_STATE/
                                    META_TAG_CONFLICT records for the
                                    current path (the OBJ_CONFLICT
                                    objects themselves are left in the
                                    archive, unreferenced - a real,
                                    honest `CHECK_DANGLING` afterward,
                                    the same already-accepted tradeoff
                                    `undo` leaves behind today,
                                    ADR 0013). Restores the exact
                                    pre-merge repository state, since
                                    nothing about the object tree or
                                    HEAD was ever touched by the
                                    conflicting merge attempt in the
                                    first place.
```

### `undo`/`redo` and an in-progress merge

An in-progress conflicted merge never calls `OpLogAppend` (matching
`HgitMerge`'s own existing behavior - that only happens on real
success, after `HEAD` actually moves). `hgit undo` therefore has
nothing operation-log-scoped to undo INTO a conflicted merge, and
nothing to undo A conflicted merge OUT OF either, since no operation
was ever logged for it - the roadmap's own "`undo` can return to the
state before merge began" is trivially, exactly satisfied by `merge
abort` doing that directly, not by overloading `undo`'s own existing,
narrower "pop the last logged operation" contract. `hgit merge
continue`'s own real success DOES call `OpLogAppend` (same as any
other completed operation), so `undo`/`redo` work exactly as they
already do once a merge actually finishes - no special case needed
there at all.

### `hgit status` and `hgit check`

`status` gains a real, early check (before its usual UNCHANGED/
MODIFIED/NEW/DELETED/RENAMED walk): if the current path has a
`META_TAG_MERGE_STATE` record, report it and how many conflicts remain
unresolved, so the roadmap's "`hgit status` visibly reports them" is
satisfied at the top of the existing output, not a separate command a
user has to know to run.

`check` gains a new referential-integrity pass (same pattern
`CheckMarkReachable` already uses, extended for a new commit-independent
root): for every real `META_TAG_MERGE_STATE`/`META_TAG_CONFLICT`
record found across every declared path, resolve its `OBJ_CONFLICT`
hash and confirm the object exists and its own base/ours/theirs hashes
each resolve too - a missing conflict dependency (roadmap's own
required experiment #16) is exactly the same "missing object" failure
mode `Check.HC`'s own header comment already describes for every other
real reference, not a new category.

## What this slice does not do (real, honest, deliberately scoped)

- **No textual conflict-marker format.** The roadmap explicitly
  requires this stay opt-in ("no conflict marker is written into
  source unless the user explicitly requests a textual
  materialization") - not built in this ADR's own first slice; a real,
  separate, well-scoped follow-up once there's real evidence a user
  wants to resolve conflicts by hand-editing marked text rather than
  via `hgit resolve`'s own take-ours/take-theirs.
- **No arbitrary replacement content at resolve time**, only take-
  ours/take-theirs to start - covers the common, unambiguous case
  honestly; a real follow-up if evidence shows users need to supply
  fresh content neither side had.
- **Whether the finished merge commit itself references its own
  resolved `OBJ_CONFLICT` objects** (permanent, inspectable
  provenance beyond `hgit conflicts`' own in-progress view) is left
  as a real, explicitly-flagged open question above, not decided here
  - a small, additive `CommitEncode` extension if adopted later,
  matching every prior extension's own bounds-check-driven
  compatibility approach (ADR 0005/0015), not a version branch.
- **Rename-vs-edit, rename-vs-rename, and cross-directory move
  conflicts** are real, separate gaps in `MergeTreesRecursive`'s own
  detection logic (it compares purely by entry NAME today, ADR 0011's
  own already-documented scope) - this ADR defines how ANY conflict,
  once detected, gets PERSISTED; it does not itself teach the merge
  algorithm to detect these specific new kinds. Real, separate,
  well-scoped follow-up work (the roadmap's own v1.8.5 slice).

## Format version

**Bump required.** `OBJ_CONFLICT` is a genuinely new object type (tag
5) and `Meta.HC` gains two new record tags - both additive, both
following this project's own established bounds-check/unknown-tag-
tolerant compatibility approach (an old reader encountering a
`META_TAG_CONFLICT` record it doesn't recognize simply doesn't have
code that looks for that tag, the same way `MetaFind`'s own tag-scoped
scan already ignores every record that doesn't match what it's
looking for) - but per this project's own standing discipline ("any
persisted format change must bump the repository format version and
update FORMAT.md"), bumped anyway for documentation honesty, not
because a version branch is technically required to read old repos
correctly.

## What would justify revisiting this

- Real usage showing take-ours/take-theirs resolution is insufficient
  often enough that arbitrary replacement content becomes a real,
  common need - the strongest trigger for the first "not done" item
  above.
- Real usage showing textual conflict markers are wanted after all
  (e.g. because more people expect Git's own familiar in-file marker
  workflow than expected) - the strongest trigger for the second.

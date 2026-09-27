# hgit status

Snapshot as of 2026-09-27. hgit is feature-frozen, with a scoped exception for
**1.9.0** covering storage and exchange only (ADR 0018) — see below. The
native port for Windows, macOS and Linux lives in
[hgit-native](https://github.com/VectorSophie/hgit-native); this repository
remains the reference implementation and owns the format contract (see below).

## What hgit is

A working, TempleOS-native version-control tool, written in HolyC and verified
on real TempleOS under QEMU: content-addressed objects, nested-tree
subdirectories, a rename-aware three-way merge with persistent, resolvable
conflicts, typed relations between commits, named paths with undo/redo,
DolDoc history and reconciliation views, `.hgitignore`, and
`.hgitattributes` file modes. Repository format version **4**
([`FORMAT.md`](../FORMAT.md)). Every command is covered by
[`tests/full-regression.hc`](../tests/README.md).

## Frozen, with a scoped exception for 1.9.0

No new repository semantics, object types, or record tags. Contract changes
still land here first: a format change or a correction to `FORMAT.md` or
`fixtures/` is made in this repository, tagged (`contract-<version>`), and
then picked up by hgit-native through its submodule pin.

[ADR 0018](adr/0018-storage-and-exchange-release-policy.md) lifts the freeze
for **1.9.0 only**, and only for **storage and exchange**: writers that store
each distinct object once instead of duplicating it on every `offer`/`merge`
([ADR 0019](adr/0019-objects-stored-once.md)), readers that tolerate an
interrupted (torn-tail) write instead of corrupting past it, an explicit
`compact` command, and a portable incremental exchange file, `.hgb`/`.hgh`
bundles ([ADR 0020](adr/0020-incremental-exchange-bundles.md), spec in
[`BUNDLE.md`](../BUNDLE.md)). `format_version` stays **4**: nothing a reader
must branch on changed, only what a writer produces and how tolerant a reader
is. After 1.9.0 the freeze resumes; later work needs its own ADR.

[`fixtures/`](../fixtures/README.md) holds the current (1.9) golden repos and
expected output, generated on real TempleOS by `tools/gen-fixtures.py`.
[`fixtures-1.8.9/`](../fixtures-1.8.9/README.md) preserves the pre-1.9 golden
set unchanged, so reading a legacy archive with duplicate records stays under
test. `hgit-native` keeps a legacy-append writer mode for the same reason.

## Installing

See [`INSTALL.md`](../INSTALL.md): the pre-built TempleOS+hgit bundle, or load
`HgitAll.HC` onto your own TempleOS install. `.deb`, Homebrew and Chocolatey
sources exist (`packaging/`); none is published to a community index.

## Known limits

- **Conflict resolution is narrow.** Conflicts persist and resolve by
  `take-ours` / `take-theirs` / deletion (ADR 0016); replacement content,
  conflict-marker text, and rename/rename resolution are not built (ADR 0017
  refuses the ambiguous rename case).
- **Cross-directory moves carry no identity evidence.** Rename detection is
  within one directory (ADR 0010), so a move plus an edit surfaces as an
  edit/delete conflict and a new file: safe, not smart.
- **Criss-cross merge bases.** `FindMergeBase` is a correct ancestor-set search
  but does not attempt Git's recursive virtual-base strategy for a genuinely
  ambiguous case.
- **`graph` does not draw merge commits as a DAG rejoin.** A merge shows as one
  line on its branch, not a connected join.
- **Fuzzy rename detection has a size ceiling.** `Status.HC` keeps a fixed
  512-byte-per-slot buffer, so a large file cannot be the source or target of a
  similarity-based rename; exact-content matching is unaffected.
- **The object index is a linear scan.** A hash-table version exists
  (`experiments/104-index-hash-table/`) but is unwired; repos are small.
- **Entity IDs and rename detection do not share information.**
- **No commit author/identity.** Single-user, single-machine by design so far.
- **No chunking or compression** in the object store.
- **Mode-only change on the side a file is deleted from** is not detected as a
  conflict.
- **Bundles authenticate content, not senders.** A `.hgb` bundle's hashes prove
  the bytes are unchanged and internally consistent; there is no signature or
  identity, so a recipient must get a bundle over a channel it trusts (see
  `BUNDLE.md`). Bundles are native-only in 1.9.0; TempleOS still exchanges
  whole repositories with `export`/`import`.
- **No partial or promissory replicas.** Every repository a command opens is
  complete; 1.9.0 only reduces what has to be *sent*, not what a single copy
  must *hold*.

## Where to read more

- [`docs/ARCHITECTURE.md`](ARCHITECTURE.md): the current-state module map.
- [`docs/adr/`](adr/): the decisions, one per file.
- [`docs/research/`](research/00-research-index.md): the dated, probe-by-probe
  record of how each piece was built and verified, and the research behind it.
- `experiments/`: numbered probes, each a question paired with captured
  evidence.

The v1.8.x planning brief that used to live in `docs/ROADMAP-v1.8.md` was
removed as a planning artifact; it stays in git history
(`git show 1808d87:docs/ROADMAP-v1.8.md`).

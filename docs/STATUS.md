# hgit status

Snapshot as of 2026-09-21. hgit **1.8.9** is complete and feature-frozen. The
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

## Frozen, with one exception

No new features. Contract fixes still land here first: a format change or a
correction to `FORMAT.md` or `fixtures/` is made in this repository, tagged
(`contract-<version>`), and then picked up by hgit-native through its
submodule pin.

The current contract tag is `contract-1.8.9`. [`fixtures/`](../fixtures/README.md)
holds repos and expected output generated on real TempleOS by
`tools/gen-fixtures.py`.

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

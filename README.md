# hgit

A lightweight, modular, self-contained version-control system, written in
HolyC, native to TempleOS — with persistent file/symbol identity,
executable DolDoc reconciliation, truthful non-destructive history, and a
consistent modern CLI.

**Status: M0 complete (7/7 acceptance items); M1 complete, including
command-surface polish.** See `docs/research/10-product-proposal.md`.
The full object storage layer — canonical encoding, BLAKE2b-512
(single-block and streaming), typed objects (blob/tree/commit), a
hash→offset index — is built and verified running natively on real
TempleOS under QEMU, not simulated. All five M1 commands
(`init`/`status`/`offer`/`history`/`see`) exist, are independently
verified, and are composed behind a real entry point: one dispatcher
function, `Hgit(cmdline)`, called exactly the way TempleOS's own native
commands are (`Hgit("init \"C:/Home/My Repo.hgs\"");` — quoted
arguments with spaces work) — there is no argv/shell syntax in TempleOS
to build a traditional CLI around, confirmed from primary source, so
this is the idiomatic shape, not a workaround. The whole toolchain
packages into one file, loadable with a single `#include`.

## What's here

- `docs/research/` — the research dossier, with an honest per-doc status
  in [`00-research-index.md`](docs/research/00-research-index.md). Most
  docs are partial or stubs; see that index before assuming coverage.
- `experiments/` — one directory per probe, each with its own `README.md`
  (what was tried, the exact result, what's not yet done) and, where
  relevant, the exact HolyC source that was pushed and verified.
  `experiments/00-qemu-boot/` proves TempleOS 5.03 boots to a live
  desktop under QEMU on a plain Linux host; `experiments/01-temple-repl/`
  is the reusable install + scripted source-injection channel every
  later probe runs through.
- `FORMAT.md` — the `.HGS` repository/archive format, documented
  byte-for-byte, matched to what's actually implemented.
- `docs/adr/` — 0001 (repository model) and 0002 (canonical encoding),
  each backed by working, tested `src/` code, updated as that code grew;
  0003 (the real 33-character path-length ceiling found in probe 36 —
  decided and now fully implemented: one combined per-repo metadata
  file instead of one sidecar file per concern. Every real command
  (`Paths.HC`, `OpLog.HC`) now genuinely runs on
  `src/hgit-core/Meta.HC` — a path name the old scheme would have
  rejected now succeeds). No ADR should be written before its own
  evidence exists — 0003 is backed by probes 36/37/40/41/42/43/44's
  real, binary-searched/QEMU-verified measurements.
- `src/hgit-core/` — the object storage layer: `Canon.HC` (canonical
  little-endian encoding), `Blake2b.HC` (BLAKE2b-512, single-block +
  streaming, matches RFC 7693), `Archive.HC`/`Hgs.HC` (the `.HGS` record
  format and file header), `Object.HC`/`Tree.HC`/`Commit.HC` (typed
  objects: blob/tree/commit content), `Index.HC` (hash→offset lookup),
  `Meta.HC` (ADR 0003's combined per-repo metadata file — HEAD, path
  list/current-path, and operation-log storage in one file, immune to
  the real 33-char path-length ceiling; `Paths.HC` now runs on it).
- `src/hgit-cli/` — the command surface: `Init.HC`, `WorkDir.HC`,
  `Head.HC` (now unused by real commands — retired in favor of
  `Meta.HC`, not yet deleted), `Paths.HC` (named paths, backed by
  `Meta.HC`), `Offer.HC`, `Status.HC`, `History.HC`, `See.HC`, `Hex.HC`
  (hex string ↔ hash bytes), `OpLog.HC` (operation log + undo/redo
  stack, wired into `Offer.HC`, now backed by `Meta.HC`), and
  `Hgit.HC` — the real entry point (`Hgit(cmdline)`) composing all of
  the above behind one dispatcher.
  Every file in both directories verified running on real TempleOS via
  `experiments/01-temple-repl/`'s injection channel — see each probe's
  README for exact evidence, and each source file's own comments for
  which probe verified it.
- `tools/build-package.sh` — concatenates every `src/hgit-core/` and
  `src/hgit-cli/` file, in dependency order, into `packaging/HgitAll.HC`
  — the actual distributable: verified loadable on real TempleOS with a
  single `#include "C:/Home/HgitAll.HC";`, followed by a working
  `Hgit(...)` call, in a session that never pushed any individual
  source file directly (`experiments/28-hgit-package/`).
- `tests/` — still scaffolded/empty.

**M2 in progress**: the operation log (`src/hgit-cli/OpLog.HC`) is
built, path-scoped, and wired into `hgit offer` itself; real
`hgit undo`/`hgit redo`/`hgit operation history` commands all exist (a
proper undo/redo stack, not just single-level) and are now genuinely
path-aware; named paths (`hgit path list/new/go/close`,
`src/hgit-cli/Paths.HC`) are wired into `offer`/`status`/`history`/
`undo`/`redo` — switching the current path changes what all of those
commands see — all verified end-to-end through the real `Hgit(cmdline)`
entry point on TempleOS (`experiments/30-oplog-undo/`,
`experiments/31-oplog-in-offer/`, `experiments/32-oplog-redo/`,
`experiments/33-operation-history/`, `experiments/34-hgit-paths/`,
`experiments/35-path-aware-offer/`, `experiments/36-path-scoped-oplog/`).

Along the way, a genuine, previously-undocumented TempleOS/RedSea
constraint was found: **a full path string longer than 33 characters
is silently rejected by `FileWrite`/`FileRead`** — a real risk for
every sidecar-file design this project uses. `hgit path new` now
proactively refuses a name that would cross this ceiling instead of
silently leaving behind an unreadable path (`experiments/37-path-length-guard/`),
though the underlying architectural constraint isn't resolved. See
`docs/research/01-templeos-holyc.md`.

`hgit operation restore <op>` (jump HEAD directly to any logged
operation by index) is also done, closing out the brief's full
operation-log vocabulary (`undo`/`redo`/`operation history`/
`operation restore <op>`). `.HGS` object-layer portability is confirmed
(a raw file copy, no sidecars, still resolves its full commit history
via a known hash) — whole-repo portability (bundling HEAD/oplog/paths
too) is still future work.

## Next steps

See `docs/research/10-product-proposal.md` for the live risk register
and milestone checklist. Remaining M2 work: a durable architectural
fix for the path-length ceiling itself, a real `hgit export`/`import`
for whole-repo portability, and a real DolDoc history view.

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
  each backed by working, tested `src/` code, updated as that code grew.
  No further ADR should be written before its own evidence exists.
- `src/hgit-core/` — the object storage layer: `Canon.HC` (canonical
  little-endian encoding), `Blake2b.HC` (BLAKE2b-512, single-block +
  streaming, matches RFC 7693), `Archive.HC`/`Hgs.HC` (the `.HGS` record
  format and file header), `Object.HC`/`Tree.HC`/`Commit.HC` (typed
  objects: blob/tree/commit content), `Index.HC` (hash→offset lookup).
- `src/hgit-cli/` — the command surface: `Init.HC`, `WorkDir.HC`,
  `Head.HC`, `Paths.HC` (named paths — bookkeeping only so far),
  `Offer.HC`, `Status.HC`, `History.HC`, `See.HC`, `Hex.HC`
  (hex string ↔ hash bytes), `OpLog.HC` (operation log + undo/redo
  stack, wired into `Offer.HC`), and `Hgit.HC` — the real entry point
  (`Hgit(cmdline)`) composing all of the above behind one dispatcher.
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
built, wired into `hgit offer` itself, and real `hgit undo`/`hgit redo`/
`hgit operation history` commands all exist (a proper undo/redo stack,
not just single-level); named paths (`hgit path list/new/go/close`,
`src/hgit-cli/Paths.HC`) exist and are now wired into `offer`/`status`/
`history` — switching the current path genuinely changes what those
commands see (`undo`/`redo` remain main-only for now, deliberately,
until the operation log itself becomes path-scoped) — all verified
end-to-end through the real `Hgit(cmdline)` entry point on TempleOS
(`experiments/30-oplog-undo/`, `experiments/31-oplog-in-offer/`,
`experiments/32-oplog-redo/`, `experiments/33-operation-history/`,
`experiments/34-hgit-paths/`, `experiments/35-path-aware-offer/`).

## Next steps

See `docs/research/10-product-proposal.md` for the live risk register
and milestone checklist. Remaining M2 work: making the operation log
path-scoped (so `undo`/`redo`/`hgit operation restore <op>` can safely
become path-aware too), portable `.HGS` archives, and a real DolDoc
history view.

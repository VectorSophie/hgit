# hgit

A lightweight, modular, self-contained version-control system, written in
HolyC, native to TempleOS — with persistent file/symbol identity,
executable DolDoc reconciliation, truthful non-destructive history, and a
consistent modern CLI.

**Status: M0 complete (7/7 acceptance items, real evidence); M1 started.**
See `docs/research/10-product-proposal.md`. The full object storage layer
— canonical encoding, BLAKE2b-512 (single-block and streaming), typed
objects (blob/tree/commit), a hash→offset index — is built and verified
running natively on real TempleOS under QEMU, not simulated. The first
real command, `hgit init`, now exists and works. Most of the M1 command
surface (`status`, `witness`, `offer`, `history`, `see`, `restore`,
`shrine check`) is still unbuilt.

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
  Every file verified running on real TempleOS via
  `experiments/01-temple-repl/`'s injection channel — see each probe's
  README for exact evidence, and each source file's own comments for
  which probe verified it.
- `src/hgit-cli/` — the command surface, just started: `Init.HC`
  (`hgit init`).
- `tests/`, `tools/`, `packaging/` — still scaffolded/empty.

## Next steps

See `docs/research/10-product-proposal.md` for the live risk register
and milestone checklist. With the object layer complete, the concrete
next work is the rest of M1's command surface (`status`, `witness`,
`offer`, `history`, `see`, `restore`, `shrine check`) — each buildable
directly on `src/hgit-core/` — followed by an actual argv-driven entry
point once enough commands exist to make a dispatcher worth building.

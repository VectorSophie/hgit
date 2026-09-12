# hgit

A lightweight, modular, self-contained version-control system, written in
HolyC, native to TempleOS — with persistent file/symbol identity,
executable DolDoc reconciliation, truthful non-destructive history, and a
consistent modern CLI.

**Status: M0 complete (7/7 acceptance items, real evidence); all five
M1 command targets built and verified.** See
`docs/research/10-product-proposal.md`. The full object storage layer —
canonical encoding, BLAKE2b-512 (single-block and streaming), typed
objects (blob/tree/commit), a hash→offset index — is built and verified
running natively on real TempleOS under QEMU, not simulated.
`hgit init`, `hgit status` (new/modified/unchanged/deleted, against a
real HEAD tree), `hgit offer` (real files → blobs → tree → commit →
HEAD, with a verified parent chain), `hgit history` (walks the parent
chain), and `hgit see` (one commit's full detail) all exist and work —
each demonstrated against a real, persisted repository, including
across QEMU reboots between sessions. What's left for M1: composing
these behind one real argv-driven entry point (they're currently
independently-callable functions, not yet a program).

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
- `src/hgit-cli/` — the command surface: `Init.HC` (`hgit init`),
  `WorkDir.HC` (working-directory enumeration), `Head.HC` (the
  current-offering pointer), `Offer.HC` (`hgit offer`), `Status.HC`
  (`hgit status`), `History.HC` (`hgit history`), `See.HC` (`hgit see`).
  Every file in both directories verified running on real TempleOS via
  `experiments/01-temple-repl/`'s injection channel — see each probe's
  README for exact evidence, and each source file's own comments for
  which probe verified it.
- `tests/`, `tools/`, `packaging/` — still scaffolded/empty.

## Next steps

See `docs/research/10-product-proposal.md` for the live risk register
and milestone checklist. With all five M1 commands built, the concrete
next work is composing them behind one real argv-driven `hgit` entry
point (including the hex-string↔hash-bytes parsing none of them have
needed yet, since every function so far takes raw 64-byte hashes), then
moving into M2 territory (paths/branches, the operation log, portable
`.HGS` archives, a real DolDoc history view).

# hgit

A lightweight, modular, self-contained version-control system, written in
HolyC, native to TempleOS — with persistent file/symbol identity,
executable DolDoc reconciliation, truthful non-destructive history, and a
consistent modern CLI.

**Status: M0 (feasibility), 6 of 7 acceptance items done with real
evidence** — see `docs/research/10-product-proposal.md`. Real HolyC now
exists (`src/hgit-core/`: canonical encoding, BLAKE2b-512, a tiny
object archive), each verified running on real TempleOS under QEMU, not
simulated. Still pre-M1: no CLI, no repository commands yet.

## What's here

- `docs/research/` — the research dossier, with an honest per-doc status
  in [`00-research-index.md`](docs/research/00-research-index.md). Most
  docs are partial or stubs; see that index before assuming coverage.
- `experiments/` — isolated, runnable feasibility probes.
  `experiments/00-qemu-boot/` proves TempleOS 5.03 boots to a live desktop
  under QEMU on a plain Linux host — the single highest-risk question for
  the whole project, resolved with screenshots and exact commands.
- `docs/adr/` — 0001 (repository model) and 0002 (canonical encoding)
  written, backed by working, tested `src/hgit-core/` code and the M0
  probes. The rest wait for their own evidence — no architecture
  decision should be recorded before the evidence behind it exists.
- `src/hgit-core/` — real, tested HolyC: `Canon.HC` (canonical
  little-endian encoding), `Blake2b.HC` (BLAKE2b-512, matches RFC 7693),
  `Archive.HC` (append/read/verify object records). Each verified
  running on real TempleOS via `experiments/01-temple-repl/`'s injection
  channel — see their probe READMEs for exact evidence.
- `tests/`, `tools/`, `packaging/` — still scaffolded/empty.

## Next steps

See the risk register and draft M0 acceptance checklist in
[`docs/research/10-product-proposal.md`](docs/research/10-product-proposal.md).
Highest-priority open items: confirm a host-side HolyC toolchain
(`docs/research/07-portability-and-toolchains.md`), and reproduce serial
source-injection + pass/fail marker capture into a booted TempleOS guest
(`docs/research/08-qemu-testing.md`).

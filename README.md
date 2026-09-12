# hgit

A lightweight, modular, self-contained version-control system, written in
HolyC, native to TempleOS — with persistent file/symbol identity,
executable DolDoc reconciliation, truthful non-destructive history, and a
consistent modern CLI.

**Status: Phase 0 (research/feasibility). No hgit code has been written
yet.** This repository currently holds research notes and isolated
feasibility probes only, per the project's own engineering discipline:
architecture is not allowed to freeze ahead of evidence.

## What's here

- `docs/research/` — the research dossier, with an honest per-doc status
  in [`00-research-index.md`](docs/research/00-research-index.md). Most
  docs are partial or stubs; see that index before assuming coverage.
- `experiments/` — isolated, runnable feasibility probes.
  `experiments/00-qemu-boot/` proves TempleOS 5.03 boots to a live desktop
  under QEMU on a plain Linux host — the single highest-risk question for
  the whole project, resolved with screenshots and exact commands.
- `docs/adr/` — empty. No architecture decision should be recorded before
  the evidence behind it exists.
- `src/`, `tests/`, `tools/`, `packaging/` — scaffolded, empty. M0 hasn't
  started.

## Next steps

See the risk register and draft M0 acceptance checklist in
[`docs/research/10-product-proposal.md`](docs/research/10-product-proposal.md).
Highest-priority open items: confirm a host-side HolyC toolchain
(`docs/research/07-portability-and-toolchains.md`), and reproduce serial
source-injection + pass/fail marker capture into a booted TempleOS guest
(`docs/research/08-qemu-testing.md`).

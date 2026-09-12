# hgit Research Index

Status legend: ✅ seeded with real primary-source material · 🟡 stub only (source list, nothing fetched yet) · ⛔ not started

This is Phase 0. It is intentionally incomplete — every doc below distinguishes
verified documentation, facts confirmed in source, experimental evidence,
inference, and open risk, per the project brief. Nothing here should be read
as a frozen decision; see `docs/adr/` (not yet written — no ADR should be
authored before its supporting evidence exists).

| Doc | Status | Notes |
|---|---|---|
| [01-templeos-holyc.md](01-templeos-holyc.md) | ✅ | HolyC lang basics, cmd-line REPL model, reliability philosophy, source mirror structure |
| [02-doldoc-interface.md](02-doldoc-interface.md) | ✅ | DolDoc format basics + live confirmation from boot probe |
| [03-zealos-and-networking.md](03-zealos-and-networking.md) | ✅ | ZealOS lineage/license/activity; networking status still unresolved |
| [04-vcs-comparison.md](04-vcs-comparison.md) | 🟡 | Only Git covered so far (see 05); jj/Sapling/Pijul/Fossil/GitButler not yet fetched |
| [05-git-internals-and-product-practice.md](05-git-internals-and-product-practice.md) | 🟡 | Object model only; packfiles/refs/merge/gc not yet fetched |
| [06-storage-hashing-compression.md](06-storage-hashing-compression.md) | 🟡 | Canonical encoding **and full BLAKE2b-512** both passing in native HolyC on real TempleOS, matching RFC vectors and the host oracle exactly (`experiments/03-canonical-encoding/`, `experiments/04-blake2b-native/`, `src/hgit-core/`); compression/chunking not started |
| [07-portability-and-toolchains.md](07-portability-and-toolchains.md) | ✅ | `holyc-parser` (210-snippet VM-validated corpus, found via templeos-devkit) is now the strongest evidence; holyc-lang still only homepage-level |
| [08-qemu-testing.md](08-qemu-testing.md) | ✅ | Boot **and** scripted install+inject+capture both reproduced end to end, see `experiments/00-qemu-boot/` and `experiments/01-temple-repl/` |
| [09-packaging-and-releases.md](09-packaging-and-releases.md) | ⛔ | Not started |
| [10-product-proposal.md](10-product-proposal.md) | 🟡 | Preliminary risk register only — too early for a real proposal |
| [failed-approaches.md](failed-approaches.md) | ✅ | Living log |

## What actually happened in this first pass

Rather than shallowly touch all ~80 linked sources, this pass went deep on
the two highest-risk questions — does TempleOS run at all here, and can
it be driven/tested automatically — and got definitive, evidenced
**yes** on both. `experiments/00-qemu-boot/` proves the former;
`experiments/01-temple-repl/` proves the latter (scripted install,
scripted daemon bootstrap, real HolyC source injected over COM2,
JIT-executed, result read back through a host file). Along the way,
`experiments/templeos-devkit/` (a third-party devkit discovered and
cloned mid-session, not in the original brief's source list — see doc 08)
turned out to be a previously-debugged reference implementation of
almost exactly this harness, plus a VM-validated HolyC parser
(`holyc-parser`, see doc 07). That de-risks the whole program enough to
justify continuing. The remaining research map is large and will be worked
through incrementally in following sessions; this index is the tracker.

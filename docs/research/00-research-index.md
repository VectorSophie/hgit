# hgit Research Index

Status legend: ✅ seeded with real primary-source material · 🟡 stub only (source list, nothing fetched yet) · ⛔ not started

This is Phase 0. It is intentionally incomplete — every doc below distinguishes
verified documentation, facts confirmed in source, experimental evidence,
inference, and open risk, per the project brief. Nothing here should be read
as a frozen decision; see `docs/adr/` (0001 and 0002 now written, backed
by the M0 probes below — the rest still wait; no ADR should be
authored before its supporting evidence exists).

| Doc | Status | Notes |
|---|---|---|
| [01-templeos-holyc.md](01-templeos-holyc.md) | ✅ | HolyC lang basics, cmd-line REPL model, reliability philosophy, source mirror structure |
| [02-doldoc-interface.md](02-doldoc-interface.md) | ✅ | DolDoc format basics, live confirmation from boot probe, `$..$` literal-text and generated-file rendering both confirmed (probe 46); `$LK$` (probe 54), `$TR$` (probe 57), and `$LS$` (probe 63) widgets all resolved from real TempleOS demo source — every widget syntax question this doc tracked is now closed |
| [03-zealos-and-networking.md](03-zealos-and-networking.md) | ✅ | ZealOS lineage/license/activity; networking status still unresolved |
| [04-vcs-comparison.md](04-vcs-comparison.md) | 🟡 | jj's operation log and Fossil's delta format both read and compared; Sapling/Pijul/GitButler/Mercurial still unfetched |
| [05-git-internals-and-product-practice.md](05-git-internals-and-product-practice.md) | 🟡 | Object model only; packfiles/refs/merge/gc not yet fetched |
| [06-storage-hashing-compression.md](06-storage-hashing-compression.md) | 🟡 | Canonical encoding, full BLAKE2b-512, a tiny append/read/verify object archive, **and a versioned `.HGS` header format** (see `FORMAT.md`) all passing in native HolyC on real TempleOS; compression/chunking not started |
| [07-portability-and-toolchains.md](07-portability-and-toolchains.md) | ✅ | `holyc-parser` (210-snippet VM-validated corpus, found via templeos-devkit) is now the strongest evidence; holyc-lang still only homepage-level |
| [08-qemu-testing.md](08-qemu-testing.md) | ✅ | Boot **and** scripted install+inject+capture both reproduced end to end, see `experiments/00-qemu-boot/` and `experiments/01-temple-repl/` |
| [09-packaging-and-releases.md](09-packaging-and-releases.md) | ✅ | TempleOS has no package manager/installer — release artifact is `packaging/HgitAll.HC` itself (already built and verified, `experiments/28-hgit-package/`), attached to a tagged GitHub Release |
| [10-product-proposal.md](10-product-proposal.md) | ✅ | Started as a preliminary risk register; now the project's live, dated narrative log — M0 through M3's core deliverables (object storage, undo/redo, named paths, ADR 0003's metadata-file fix, stable entity identity, entity-scoped typed relations) are built, wired into real commands, and verified. Risk register table corrected to current status (was stale). |
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

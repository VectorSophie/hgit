# hgit Research Index

**For a current, top-level snapshot of where the whole project stands
(milestones, what's solid, what's genuinely still open), see
`docs/STATUS.md` instead of trying to reconstruct it from this index.**

Status legend: ✅ seeded with real primary-source material · 🟡 stub only (source list, nothing fetched yet) · ⛔ not started

This is Phase 0. It is intentionally incomplete — every doc below distinguishes
verified documentation, facts confirmed in source, experimental evidence,
inference, and open risk, per the project brief. Nothing here should be read
as a frozen decision; see `docs/adr/` (14 ADRs now written, each backed
by real probes before being authored — no ADR should be authored
before its supporting evidence exists, per this project's own standing
discipline).

| Doc | Status | Notes |
|---|---|---|
| [01-templeos-holyc.md](01-templeos-holyc.md) | ✅ | HolyC lang basics, cmd-line REPL model, reliability philosophy, source mirror structure |
| [02-doldoc-interface.md](02-doldoc-interface.md) | ✅ | DolDoc format basics, live confirmation from boot probe, `$..$` literal-text and generated-file rendering both confirmed (probe 46); `$LK$` (probe 54), `$TR$` (probe 57), and `$LS$` (probe 63) widgets all resolved from real TempleOS demo source — every widget syntax question this doc tracked is now closed |
| [03-zealos-and-networking.md](03-zealos-and-networking.md) | ✅ | ZealOS lineage/license/activity; networking status checked directly against the real, current source tree (no `Net`/networking directory or file exists anywhere in `Kernel`, confirmed live via the GitHub API) - still purely aspirational, and moot regardless since hgit's own real transport need (`export`/`import`) turned out to need no network at all |
| [04-vcs-comparison.md](04-vcs-comparison.md) | ✅ | jj's operation log, Fossil's delta format, Sapling's undo/absorb/stacks model, Mercurial's obsolescence markers, GitButler's virtual branches, Pijul's/Darcs' patch theory, and now Breezy's file-ids all read and compared - Pijul's own conflicts-as-state idea and Darcs' own documented exponential-time "conflict fight" pathology both directly inform ADR 0011's own "what would justify revisiting" list, Sapling's "stacks" flagged as a real, different-in-kind M5-or-later candidate; Breezy's file-ids surfaced a real, previously-undocumented gap between hgit's own entity ids (ADR 0004) and its independent rename detector (ADR 0009), logged on ADR 0004's own revisit list. All originally-scoped comparisons now done |
| [05-git-internals-and-product-practice.md](05-git-internals-and-product-practice.md) | ✅ | Object model, refs/reflog, fsck/recovery, rename inference, and a real `hgit merge` command (probes 97-100: multi-parent-commit prerequisite, `FindMergeBase`, a real three-way merge with conflict detection, recursed into nested trees) are all real, verified parts of hgit itself, not just research; any real conflict-resolution mechanism remains separate, deferred work (ADR 0011's own central open decision); packfiles/commit-graph/protocol v2 deliberately deprioritized, checked against real Git docs (thousands-of-commits/network-transfer scale hgit has no analogue of) rather than assumed |
| [06-storage-hashing-compression.md](06-storage-hashing-compression.md) | 🟡 | Canonical encoding, full BLAKE2b-512, a tiny append/read/verify object archive, **and a versioned `.HGS` header format** (see `FORMAT.md`) all passing in native HolyC on real TempleOS; Fossil delta format (ADR 0008) fully verified reliable, with a real diff algorithm and similarity measure, wired into `hgit offer`/`status`/`diff`/`statustree` for fuzzy rename detection (ADR 0009); merge commits (ADR 0011) and recursive trees (ADR 0010) - both once flagged here as "format supports it, untested" - are now real, resolved, verified features; a real hash table for the index is now built and verified standalone (probe 104), deliberately not yet wired into any call site (no evidence of need at current scale); object-store compression itself remains a separate, deliberately-undecided question (no evidence of need); content-defined chunking still not started |
| [07-portability-and-toolchains.md](07-portability-and-toolchains.md) | ✅ | `holyc-parser` (210-snippet VM-validated corpus) verified against hgit's own real source (zero real errors) and **actually adopted** as `tools/lint-package.sh` — a real, working host-side lint step before QEMU; `holyc-lang` now actually read (its real repo, not just the homepage) - BSD-2-Clause, produces real runnable native binaries via AOT/JIT, but a real, unverified compatibility question remains since it's an extended superset of real TempleOS HolyC, not a bug-compatible reimplementation |
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

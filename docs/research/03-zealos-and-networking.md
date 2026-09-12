# ZealOS

## Verified documentation / facts confirmed in source

Source: `github.com/Zeal-Operating-System/ZealOS` (README, repo metadata).
Lineage: TempleOS → VoidNV's ZenithOS (2019 fork) → ZealOS (forked from
ZenithOS, July 2021). License: Unlicense (public domain). Actively
maintained: 1,224 commits on `master`, automated ISO-build CI present.
Stated goal mirrors TempleOS's own philosophy: "one person should be able
to comprehend the entire system in at least a semi-detailed way within a
few days of study." In-progress work includes AHCI, a network stack and
drivers, and UEFI boot via Limine. Language fork is called **ZealC**
(renamed from HolyC) — README notes reformatting, added comments, and
system-wide renaming alongside the language rename, but the *exact*
syntactic/semantic delta between HolyC and ZealC has not been read yet
(need actual compiler source diff, not just the README claim).

## Unresolved risk

- "Networking capabilities... under way" is vague — doesn't establish
  whether ZealOS networking is usable enough today to be a viable
  `hgit-transport` target, or purely aspirational. Needs the actual
  network driver/stack source and a running test, not the README.
- ZealC vs HolyC compatibility is the load-bearing question for the
  "shared core without conditional chaos" goal in the brief. Unverified.
- Whether `templeos-devkit` (see doc 08) builds ZealOS in a way that would
  let hgit's QEMU CI target both OSes from one harness, or needs two
  divergent pipelines — partially answered (see doc 08), not fully.

## Architectural implications so far

- Treat ZealOS as the "lower-risk to extend" platform (active CI, modern
  bootloader, public-domain) and TempleOS as the "lowest common
  denominator" per the brief — consistent with the product thesis as
  written. Nothing found yet contradicts that framing.
- Do not assume ZealC networking is usable for `hgit-transport` until an
  actual probe (send one packet from ZealOS under QEMU) succeeds — currently
  just a README claim, not evidence.

## Not yet done

VCS-comparison-weight networking source reading, ZealOS `Kernel`/driver
directory inspection, and a ZealOS boot probe analogous to
`experiments/00-qemu-boot/` (same method, different ISO — the
`templeos-devkit` `make setup` path fetches a ~44MB ZealOS BIOS ISO
automatically, per doc 08).

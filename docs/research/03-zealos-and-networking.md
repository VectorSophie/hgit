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

- ~~"Networking capabilities... under way" is vague — doesn't establish
  whether ZealOS networking is usable enough today to be a viable
  `hgit-transport` target, or purely aspirational.~~ **Checked directly
  against real, current primary source (2026-09-14)**: the real
  `Zeal-Operating-System/ZealOS` repo's own `src/Kernel` directory
  (fetched live via the GitHub API, not a cached description) contains
  `BlkDev`, `Memory`, and `SerialDev` subdirectories, `PCI.ZC`/
  `PCIBIOS.ZC` (bus enumeration only), and no `Net`/networking
  directory or file of any kind. The project's own current features
  page (`zeal-operating-system.github.io/Doc/Features.DD.html`) doesn't
  mention networking at all, and the README still lists "network card
  drivers and a networking stack" under "features in development" —
  same real status as when this doc was first written, not stale, just
  now independently confirmed against the actual source tree rather
  than only the README's own summary claim. Real conclusion: ZealOS
  networking is still purely aspirational, zero real source exists yet
  — not a viable `hgit-transport` target today, and this question is
  moot regardless per doc 10's own resolution (`hgit export`/`import`,
  plain local file copies, needed no network transport at all - see
  the main risk register).
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

~~ZealOS `Kernel`/driver directory inspection~~ **Done** (2026-09-14,
see "Unresolved risk" above) - no networking source exists, real
question answered without needing a running probe. A ZealOS boot
probe analogous to `experiments/00-qemu-boot/` (same method, different
ISO — the `templeos-devkit` `make setup` path fetches a ~44MB ZealOS
BIOS ISO automatically, per doc 08) remains genuinely not done - real,
separate work if this project ever needs to target ZealOS specifically
rather than TempleOS, no evidence of that need yet (hgit's own real
target has stayed TempleOS throughout). ZealC-vs-HolyC compatibility
also remains unread.

# Product proposal (preliminary — not the real M0 acceptance doc yet)

This is **not** the final version the brief asks for. That version needs
docs 04/06/09 filled in first, plus the remaining QEMU probes in doc 08.
Writing a firm proposal ahead of that evidence would violate the brief's
own engineering-discipline rule against freezing decisions without
evidence. What follows is a risk register and M0 acceptance draft, useful
for planning the next sessions of work.

## Risk register (highest risk first)

| Risk | Status | Evidence |
|---|---|---|
| TempleOS doesn't run in any available environment | **Resolved — low risk** | `experiments/00-qemu-boot/`: boots clean under plain QEMU/TCG, no KVM, no patches |
| Automated pass/fail signal out of a booted TempleOS guest | **Resolved — low risk** | `experiments/01-temple-repl/`: scripted install + COM2 injection + real `D_OK`/`PASS .../D_DONE` round trip through a host file, zero human interaction |
| No usable host-side HolyC toolchain, forcing every test through QEMU | **Open — downgraded to medium**: a lint/validate-only option (`holyc-parser`) is now evidenced; a full execute-on-host option (`holyc-lang`) is still unverified | doc 07 |
| Canonical encoding / BLAKE2b feasibility natively in HolyC | **Open — unknown risk, but now has a proven execution path to test it on** | Not probed; blocked on doc 06, but doc 08's proven injection loop removes the "how would we even run this" uncertainty |
| RedSea contiguous-file storage constraints on an append/rebuild archive format | **Downgraded — small files empirically fine, growth pattern still unverified** | `FileWrite`/`FileRead` round-tripped small (154/170-byte) `.HGS` archives correctly across three separate probes and multiple reboots; RedSea source itself still not read, and repeated in-place *growth* of one archive (vs. write-once) is untested |
| ZealOS networking maturity as a transport target | **Open — low priority for M0/M1** | README claims are unverified; not on the critical path yet |
| QEMU test-harness input timing is not naively reliable | **New risk, resolved as a design constraint** | probe 01's boot-phase-quirk false start: fixed-delay scripted input is unsafe; a real idle/ready check is required (now documented, not yet implemented as reusable tooling) |

## M0 acceptance criteria (draft, per the brief's own list)

- [x] Native TempleOS execution reachable in this environment (boot proven)
- [x] Automated QEMU control with observable, host-parseable test results
      (proven end to end: scripted install, scripted daemon bootstrap,
      COM2 source injection, `PASS`-marker round trip via host file —
      `experiments/01-temple-repl/`)
- [x] Canonical binary encoding round-trip, in HolyC
      (`src/hgit-core/Canon.HC`, `experiments/03-canonical-encoding/` —
      found and fixed two real HolyC quirks in the process)
- [x] Official BLAKE2b vectors passing in native HolyC
      (`src/hgit-core/Blake2b.HC`, `experiments/04-blake2b-native/` —
      RFC 7693 vector matched exactly, first try)
- [x] Same fixture hashes identically in TempleOS and a host build
      (probe 04's TempleOS digest == probe 02's host oracle digest for
      the same "abc" input)
- [x] Append/read/rebuild of a tiny object archive
      (`src/hgit-core/Archive.HC`, `experiments/05-tiny-archive/` —
      found and fixed a genuine new HolyC quirk: bare top-level loops
      with local declarations can silently misbehave)
- [x] Source injection into, and `.HGS` extraction from, a disposable guest
      (`FORMAT.md`, `src/hgit-core/Hgs.HC`, `experiments/06-hgs-format/`
      — a real, versioned, byte-documented `.HGS` header now exists,
      written and read back through the proven injection channel)

**All seven M0 acceptance boxes now checked with real evidence.** M0 is
functionally done: TempleOS boots and can be driven/tested
automatically, canonical encoding, BLAKE2b, a tiny object archive, and a
versioned `.HGS` header all work in native HolyC on real TempleOS.

Moving into M1-adjacent design: **object typing is now also implemented
and verified** (`src/hgit-core/Object.HC`, FORMAT.md) — a type tag
participates in the content hash, confirmed to prevent same-bytes-
different-type collisions. **BLAKE2b is no longer capped at 128 bytes**
either (`experiments/08-blake2b-streaming/`), **and that streaming hash
is now wired into the actual archive API** (`experiments/09-wire-streaming-hash/`)
— `ArchivePut`/`ArchiveVerify`/`HgsPut` all use it, verified with a real
200-byte object stored, persisted, and re-verified. **Tree object content is now designed and verified too**
(`src/hgit-core/Tree.HC`, `experiments/10-tree-object/`) — a flat entry
list, name → child type + hash, tested with a real two-blob tree stored,
persisted, reloaded, and both entries correctly resolved by name. **Commit object content is now designed and verified too**
(`src/hgit-core/Commit.HC`, `experiments/11-commit-object/`) — tree hash
+ parent hash(es) + timestamp + message, tested with a real
root-commit/child-commit chain where the parent field correctly names
an ancestor by its own computed hash. **The full blob→tree→commit
object graph now exists and works end to end on real TempleOS** —
persisted, reloaded, and re-verified from an actual file. **The
hash→offset index is also built and verified**
(`src/hgit-core/Index.HC`, `experiments/12-index/`) — closing the last
storage-layer gap ADR 0001/FORMAT.md flagged, after a real crash (a
General Protection fault from hand-computed offsets, not the library
code) forced a redesign that eliminated manual offset-tracking entirely
rather than just patching the arithmetic. The entire object storage
layer — encoding, hashing, typed objects, trees, commits, and lookup —
is now built and verified on real TempleOS. **M1 has actually started**: `hgit init` is now real, working code
(`src/hgit-cli/Init.HC`, `experiments/13-hgit-init/`) — creates a valid
empty repository, refuses to overwrite an existing one, verified on real
TempleOS. First file in a new `hgit-cli` module, separate from
`hgit-core`'s repository-format mechanics per the brief's own module
boundary. Remaining M1 commands (`status`, `witness`, `offer`,
`history`, `see`, `restore`, `shrine check`) are the next concrete
targets, each buildable on the now-complete object/index layer.

## Estimated line counts (very rough, will move once real code exists)

Not estimated yet — premature before `hgit-core`'s object model is decided
(needs doc 04's jj/Fossil comparison first). Placeholder removed rather
than filled with a guess.

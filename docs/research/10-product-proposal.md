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
| RedSea contiguous-file storage constraints on an append/rebuild archive format | **Open — unknown risk, plausible mitigation exists** | Only the philosophy doc mentions this; real RedSea source not read |
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
- [ ] Append/read/rebuild of a tiny object archive
- [ ] Source injection into, and `.HGS` extraction from, a disposable guest
      (the injection mechanism itself is now proven; `.HGS`-specific
      extraction still untested since no `.HGS` format exists yet)

Five of seven M0 boxes checked with real evidence. What's left needs an
actual archive format decision (blob/tree/commit shape — still blocked
on doc 04's jj/Fossil comparison, not yet done) before "append/read/
rebuild a tiny object archive" can be attempted meaningfully — that's
the next real fork in the road, not another isolated probe.

## Estimated line counts (very rough, will move once real code exists)

Not estimated yet — premature before `hgit-core`'s object model is decided
(needs doc 04's jj/Fossil comparison first). Placeholder removed rather
than filled with a guess.

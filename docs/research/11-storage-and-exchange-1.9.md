# 11 — 1.9.0: storage, exchange, and integrity observability

Final report for the storage/exchange campaign scoped by
[ADR 0018](../adr/0018-storage-and-exchange-release-policy.md). Covers both
this repository and [hgit-native](https://github.com/VectorSophie/hgit-native)
(branch `storage-1.9` in both, nothing pushed as of this writing). Read
alongside ADR 0019 (objects stored once, tolerant readers), ADR 0020
(bundles) and [`BUNDLE.md`](../../BUNDLE.md).

## What actually shipped

| Area | hgit (TempleOS/HolyC) | hgit-native (Go) |
|---|---|---|
| Store each object once (ADR 0019 §1) | `ObjectPutOnce`, all 15 `ObjectPut` sites in `Offer.HC`/`Merge.HC` | `Repo.Store`/`Dedup` (default on); `Append` kept for 1.8.9 parity |
| Header count as upper bound, never under-declared (§2) | `HgsCountRecords` before every `.hgs` write | header count synced from record count in `Save` |
| Torn tail tolerated, not corrupted past (§3) | `RecordEnd`/`ArchiveVerifyEx`/`IndexBuildEx`; `CHECK_WARN torn_tail` | `archive.ParseTolerant`; `Repo.Open` succeeds on a torn file; `Save` refuses (`ErrTorn`) until repaired |
| Writer never appends after a torn tail | `HgsConsumedLen`; fixed in `offer`/`offertree`/both `merge` write sites (a real bug found and fixed during review, not anticipated in the original ADR) | N/A — `Save`'s atomic replace means native itself can't produce a torn file; only a foreign/received one needs tolerance |
| Explicit `compact`, never a GC (§5) | not yet built (no HolyC dispatch precedent; native-first) | `Repo.Compact()` + `hgit compact`: dedups, verifies the rewrite from disk before replacing the original, keeps every dangling object |
| `check` distinguishes torn / corrupt / dangling | `CHECK_WARN torn_tail offset=N bytes=N`, `CHECK_FAIL ... corrupt=N`, `CHECK_DANGLING` (pre-existing) | same three, plus `TornOffset`/`TornBytes` on `check.Report`; wording matched to HolyC's byte-for-byte |
| Portable incremental exchange (ADR 0020) | not implemented (native-only in 1.9.0, by design) | `pkg/hgit/bundle`: `.hgb`/`.hgh`, `Build`/`BuildHave`/`Verify`/`Apply`, `hgit bundle create/inspect/apply`, `hgit have` |

`format_version` stays **4** everywhere. Nothing here changes what an
existing byte means; see `FORMAT.md`'s "1.9 clarifications" section for the
exact writer/reader behavior statements this rests on.

## Format/contract decisions

- **ADR 0018**: the feature freeze is lifted for 1.9.0 only, storage and
  exchange only. No new object types, no new `.hgs.m` record tags, no commit
  identity, no network transport, no automatic GC. Freeze resumes after.
- **ADR 0019**: a writer skips an object it has already stored (this
  command's own writes included); the header count is a write-time upper
  bound, not something a reader trusts; a *torn* record (structurally doesn't
  fit) stops a reader's walk, a *corrupt* record (fits, wrong hash) does not
  — these are different failures and conflating them (as an earlier draft of
  this ADR's own prose did) would let a single bit-flip anywhere in a file
  hide everything after it. `compact` is the only way to remove existing
  duplicates, and it is explicitly not a garbage collector.
- **ADR 0020** / `BUNDLE.md`: a bundle carries objects and *proposed* heads,
  never `.hgs.m`. Fast-forward only when structurally proven; divergent,
  closed-locally, or merge-in-progress paths are kept apart under
  `<path>@<label>` (never overwritten, never silently dropped). A bundle's
  hash proves integrity, not who sent it — stated explicitly, not implied.
  Verification is two phases: nothing on disk changes until every record,
  every prerequisite, and every reference has been checked.

## What was found and fixed along the way (not anticipated in the original brief)

Independent review during this campaign — not the implementing changes
themselves — found two real defects, both fixed and verified on real
TempleOS/in Go before being accepted:

1. **Writers appending after a torn tail.** `offer`/`offertree`/`merge`
   copied a previous archive's raw file size forward, including any torn
   tail, and appended the new commit right after it — a bound-checked reader
   would never scan far enough to reach it. Silently unreachable history.
   Fixed (`HgsConsumedLen`), with a regression segment
   (`TFULL_TORN_OFFER_*`) that proves the new commit is actually reachable
   afterward (history/check/a fresh index lookup), not just that a warning
   prints.
2. **ADR 0019 §3's own prose** originally defined a "complete" record as
   fitting *and* hash-matching — which didn't match what the code actually
   does (and shouldn't: stopping on every hash mismatch would let one
   bit-flip hide the rest of the file). The prose was corrected to define
   "torn" and "corrupt" as the separate failures they are.

Both were caught by treating an implementing agent's own flagged concerns as
real findings requiring code inspection, not by taking a "DONE" status at
face value — the same discipline applied to every phase below.

## Measured, before/after (hgit-native, `tools/bench`)

Same machine (Intel i5-1035G7, 4c/8t, 7.4 GiB RAM, Linux 6.17, go1.22.2),
deterministic harness (seeded content, frozen clock, counter entity ids), 3
runs per timing except `offer ms` (one sample: the commit itself).

| scenario | `.hgs` bytes | open ms | offer ms | save ms | check ms |
|---|---|---|---|---|---|
| s1 (5 files, 1000 commits) | 12.1 MB → 3.0 MB (4.0x) | 9.0 → 2.4 | 33.6 → 9.1 | 26.0 → 8.6 | 20.3 → 9.9 |
| s2 (2,000 files, 30 commits) | 101.9 MB → 3.9 MB (26x) | 63.7 → 1.5 | 406.9 → 37.6 | 180.4 → 7.3 | 156.5 → 7.4 |
| s2 (10,000 files, 5 commits) | 84.8 MB → 17.1 MB (5.0x) | 47.3 → 6.0 | 416.0 → 167.0 | 301.6 → 36.3 | 145.2 → 31.8 |
| s3 (500 files, 8 distinct contents, 20 commits) | 22.0 MB → 0.89 MB (24.6x) | 11.8 → 0.4 | 53.0 → 10.6 | 50.0 → 2.2 | 31.0 → 3.4 |
| s4 (named paths + merges, 110 commits) | 2.0 MB → 0.32 MB (6.2x) | 1.4 → 0.1 | 4.6 → 0.9 | 4.0 → 0.7 | 3.9 → 0.8 |
| s5 (5 × 2 MiB binaries, 10 commits) | 104.9 MB → 29.4 MB (3.6x) | 49.8 → 7.5 | 247.2 → 55.7 | 204.3 → 44.8 | 136.5 → 33.4 |

Full methodology, the complete generated table, and what did *not* improve
(status is flat — it hashes the working tree, untouched by this work; a
10,000-file offer still costs ~170 ms because every offer still reads and
hashes every working file) are in `hgit-native/docs/benchmarks/README.md`.
Results are checked in as `.jsonl` (`baseline-9602db2`, `dedup`,
`dedup-zerocopy`).

**s6 (whole-repository export/import vs. what a replica actually lacks):**
a replica one commit behind sends 3.15 MB (was 12.3 MB pre-dedup) to receive
2,396 bytes of genuinely new records — 1,315x more than necessary via
`export`/`import` alone. This is exactly the gap ADR 0020 bundles close (see
below); deduplication reduces the whole-repo baseline but does not by itself
fix whole-repo transfer.

**Bundle byte savings** (`pkg/hgit/bundle` test, 21-commit history, one
commit ahead of a replica that supplies a have-file): baseline bundle 14,679
bytes; incremental bundle carrying just the 21st commit's new objects, 2,084
bytes (~86% smaller than baseline for that same repository, and orders of
magnitude smaller than the whole-repo `export` for a repository of this
size — see s6 above for the export/import comparison at similar scale).

## TempleOS on-platform measurement (real QEMU, not native's numbers)

Guest jiffies (not calibrated to wall-clock seconds in this run — the
driver's own jiffies-per-second calibration crashed on a partial-line parse
bug, fixed afterward; the raw values are internally comparable to each other
run-to-run on the same guest):

| commits | archive bytes (pre-dedup / post-dedup) | offer (pre/post) | check (pre/post) | history (pre/post) |
|---|---|---|---|---|
| 1 | 21,497 / — | 343 / — | 1,070 / — | 701 / — |
| 10 | — | 388 / — | 1,168 / — | 4,108 / — |
| 25 | — | 422 / — | 1,345 / — | 9,604 / — |
| 50 | — | 510 / — | 1,712 / — | 19,202 / — |
| 100 | 2,154,544 / 68,836 (31x) | 718 / 390 | 2,395 / 1,112 | 38,403 / 39,279 (flat) |

`history` did not improve: profiling in-guest showed COM1 serial output costs
~12.5 ms/byte, dominating at ~384 jiffies per commit printed — the lookup
itself (an `IndexLookup` call) costs 0.66 ms (0.09 ms with the early-exit
hash compare already in this campaign). An earlier assumption that
`history`'s linear index scan was the bottleneck was wrong and was corrected
before any HolyC change was made on that basis — the measurement, not the
premise, decided it.

## Test and interop evidence

- **hgit (TempleOS)**: `tests/full-regression.hc` extended with `TFULL_DEDUP`,
  `TFULL_TORN`, and `TFULL_TORN_OFFER_*` segments; regenerated on real QEMU
  (`tools/gen-fixtures.py --hgitall`) against a candidate `HgitAll.HC`. Diff
  against the prior fixture set, timestamps and hashes masked: the only
  differences are nine `CHECK_OK objects=N` counts (each equal to the
  distinct-hash count of the corresponding 1.8.9 prefix) and the new
  segments' own lines — nothing else moved. `fixtures-1.8.9/` is preserved
  unchanged so reading a legacy duplicate-laden archive stays under test.
- **hgit-native**: 310 tests passing (`go test ./...`), `go vet` and `gofmt`
  clean at every commit. Bumping the `contract/` submodule pin to this
  fixture set broke 6 test files that force legacy (duplicate-appending)
  mode to reproduce 1.8.9 byte-for-byte — they were comparing legacy output
  against the new (deduped) golden counts. Fixed by giving `internal/testfix`
  a `Legacy*` accessor pointing at the preserved `fixtures-1.8.9/`, not by
  loosening any assertion.
- **Pillar C (TempleOS reads a native-written repository)**: proven pre-1.9
  (commit 9602db2) and unaffected by this campaign's format decisions
  (`format_version` unchanged); not re-run against a bundle-applied or
  deduped native repository under real QEMU as part of this campaign — see
  limitations below.
- **Bundle test matrix** (`pkg/hgit/bundle`, 14 tests): both-direction round
  trips, byte savings (above), idempotent re-apply, corruption refused in
  Phase 1 with nothing written (flipped hash, oversized length, truncated
  footer, missing prerequisite), a legacy non-dedup archive builds/applies
  correctly, divergent heads kept under `<path>@<label>` and reconciled via
  `merge`, a real merge-in-progress path left unmoved, a closed path not
  reopened, `--paths` limiting exchange, and a simulated crash between the
  archive and meta writes leaving only harmless dangling objects that a
  re-run completes.
- **Torn-tail / compact test matrix**: a synthetic torn archive opens
  successfully with everything before the tear usable; `Save` refuses and
  touches nothing; `check` reports torn and corrupt as separate, independent
  findings in the same file; `compact` dedups, keeps dangling objects
  (including one only an undone commit reaches), verifies its rewrite from
  disk before replacing the original, and clears torn state.
- **Manual end-to-end smoke tests** (this session, not part of the automated
  suite): `bundle create`/`inspect`/`apply` between two fresh repositories;
  and a real truncated file (`init`, two offers, truncate the last 40 bytes)
  through `check` → refused `offer` → `compact` → working `offer` again →
  `hgit undo` cleanly recovering a head that the truncation happened to
  sever, using metadata (`.hgs.m`) untouched by the tear.

## Exact commands (bundle exchange, hgit-native)

```
$ hgit init a.hgs
$ hgit offer a.hgs "f.txt" "first"
$ hgit bundle create a.hgs out.hgb
Wrote baseline bundle out.hgb (728 bytes, id cc3ee75cd9e183a6).
$ hgit bundle inspect out.hgb
kind: baseline
label: ""
bundle id: cc3ee75cd9e183a6
prerequisites: 0
heads: 1
  main -> f26693a9b102752c
objects: 3 (392 bytes)
$ hgit init b.hgs
$ hgit bundle apply b.hgs out.hgb --label a
Applied bundle out.hgb: 3 new object(s).
  main: declared at f26693a9b102752c.
$ hgit history b.hgs
f26693a9b102  2026-09-27T06:49:12.710Z  first
```

For an incremental exchange, the recipient first runs `hgit have b.hgs
have.hgh` and sends `have.hgh` back; the sender runs `hgit bundle create
a.hgs out.hgb --have have.hgh` to get only what `b.hgs` lacks.

## Commits

hgit (`storage-1.9`, 10 commits since `main`): `f476328`, `27752ba`,
`1edb2ac`, `cd4668a`, `a744095`, `f53b874`, `406377c`, `bf0d8e8`, `caa9404`,
`677bf84`.

hgit-native (`storage-1.9`, 12 commits since `main`): `50ddb06`, `4711b1d`,
`cb57e8e`, `96b048e`, `b9a070f`, `d779747`, `a484f77`, `4599111`, `d0bf0ee`,
`872528a`, `007f9d4`, `624c523`.

Nothing has been pushed, tagged, or released.

## Limitations, honestly

- **No re-run of the QEMU pillar-C interop gate against 1.9-produced
  artifacts specifically** (a deduped native repository, or one a bundle was
  applied to). The format itself didn't change, and every new native object
  record is byte-identical in shape to a pre-1.9 one, so there's good reason
  to expect this holds — but "good reason to expect" is not the same claim
  as "measured," and this campaign did not run that specific gate.
- **No CI matrix run** (Windows/macOS native builds) for this branch; only
  local Linux `go test ./...`.
- **`compact` has no TempleOS implementation.** Removing duplicates from an
  existing TempleOS-written archive is native-only in 1.9.0.
- **Bundles are native-only.** TempleOS still exchanges whole repositories
  via `export`/`import`.
- **A content hash is not authentication.** Nothing in `BUNDLE.md` claims a
  bundle's origin is verified — only that its bytes are self-consistent.
- **No partial/promissory replicas, no daemon, no multi-writer op-DAG.**
  Explicitly design-only for this release (ADR 0018's item D); see the
  follow-up roadmap below.
- **`hgit undo` as torn-tail recovery is observed, not engineered.** It
  works because operation-log metadata lives in `.hgs.m`, independent of the
  archive tear — a useful property, confirmed by manual test, but not a
  documented guarantee of this campaign's ADRs.

## Follow-up roadmap (not started)

1. Run the QEMU pillar-C interop gate specifically against a deduped
   native-written repository and a bundle-applied one.
2. A native CI matrix (Windows/macOS/Linux) for `storage-1.9` before any
   tag.
3. Partial/promissory replicas: a design note only, gated on real evidence
   that a full local copy is the actual bottleneck for some workload (ADR
   0018 explicitly did not find this yet).
4. A daemon or watch-mode for automatic bundle exchange over a mounted
   volume — currently a manual `bundle create`/`apply` round trip.
5. Multi-writer operation-log reconciliation beyond the current
   `<path>@<label>` keep-both-and-let-the-user-merge policy.
6. A TempleOS `compact` and, if evidence justifies it, TempleOS-side bundle
   support.

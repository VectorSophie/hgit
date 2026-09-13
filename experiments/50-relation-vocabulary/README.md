# Probe 50 — ADR 0005's typed relation vocabulary, PASS

Status: **PASS**, real, on real TempleOS under QEMU
(`serial-log-passing-run.txt`). Second half of M3's core primitives
(entity IDs in probe 49, relations here) — the storage layer only;
no CLI command produces a relation yet, per ADR 0005's own stated
scope.

## What changed

`src/hgit-core/Commit.HC`: `CommitEncode` gains two trailing
parameters, `relation_tag` (`REL_NONE`/`REL_CONTINUES`/`REL_CORRECTS`/
`REL_REVERTS`/`REL_RECONCILES`) and `relation_target` (a 64-byte prior
commit hash, only read when `relation_tag != REL_NONE`). New accessors
`CommitRelationTag`/`CommitRelationTarget`, both computed from
`CommitMessageLen` (via a new shared `CommitRelationOffset` helper)
rather than a fixed byte offset, since the relation fields sit after
the variable-length message. `Offer.HC`'s own call site updated to
pass `REL_NONE, NULL` — every ordinary offer is unaffected, costing
exactly one extra byte per commit.

## What was verified

`test_driver.hc`, two parts:

**Regression** — a real `hgit offer` through the dispatcher, decoded
back:
```
DISPATCH_OK offer
mlen1=14 msg1=ordinary offer
rel_tag1=0 (expect 0, REL_NONE)
```
Message and length still decode correctly; the new relation tag
correctly reads back as `REL_NONE` for an ordinary commit — confirms
the trailing field addition didn't disturb the existing accessors.

**New relation storage** — direct `CommitEncode`/accessor round-trip
with a real `REL_CORRECTS` relation (not yet reachable through any
real command, per ADR 0005's scope: storage layer first):
```
mlen2=43 msg2_matches=1
rel_tag2=2 (expect 2, REL_CORRECTS) target_matches=1
ts2=999888 (expect 999888) pcount2=1 (expect 1)
```
Message, relation tag, target hash (all 64 bytes, byte-compared),
timestamp, and parent count all decode correctly **together** — the
relation fields sitting after a real (non-empty) message didn't
corrupt anything, and nothing about them corrupted the earlier fields
either.

## Not yet done (per ADR 0005's own scope)

- No CLI command produces a relation yet — `Offer.HC` always passes
  `REL_NONE`. A real `hgit correct`/`hgit revert`/`hgit reconcile`
  command (or a shared flag on `hgit offer`) is the next concrete step.
- No entity-scoping — a relation names a whole commit, not a specific
  tracked file/entity within it (ADR 0004's entity IDs and ADR 0005's
  relations don't reference each other yet).
- No semantic validation (a `REL_CORRECTS` target isn't checked to
  actually exist in the repo, etc.) — pure storage, no policy.

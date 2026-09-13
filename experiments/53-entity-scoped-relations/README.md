# Probe 53 — ADR 0006: entity-scoped relations, PASS

Status: **PASS**, real, on real TempleOS under QEMU
(`serial-log-passing-run.txt`). Closes M3's last flagged gap: a
relation can now name a specific tracked entity within a commit, not
just the commit as a whole.

## Design

`Commit.HC`: when `relation_tag != REL_NONE`, an additional 8-byte
`relation_entity_id` (U64) follows the target hash. `0` means "not
entity-scoped" (ADR 0005's original whole-commit behavior) — a safe
sentinel since `GenerateEntityId()` (two `RandU32` reads) landing on
exactly `0` is vanishingly unlikely, same honest caveat as `OpLog.HC`'s
own all-zero `prev_head` sentinel.

Also fixed a real, hit-in-practice usability issue while wiring this
up: entity IDs are `U64`, and `hgit see`'s tree listing printed them
with plain `%d` — a value with the high bit set prints as a *negative*
number (seen directly in probe 49's own README:
`idB=-3748984827403573720`). A user copying that negative decimal into
a `correct`/`revert`/`reconcile` command would have no clean way to
type it back in. Fixed by adding `Hex.HC`'s `U64ToHex`/`HexToU64`
(same convention as the existing 64-byte hash hex helpers) and
switching `See.HC`'s entity ID display, and the relation commands'
entity argument, to hex throughout.

`Hgit.HC`'s relation commands now parse
`<repo> <target_hex> <entity_hex> <find_mask> <message...>` —
`entity_hex` is 16 hex chars; pass `0000000000000000` for "not
entity-scoped." A real, deliberate breaking change to these three
commands' argument shape (probes 51/52 used the pre-ADR-0006 shape).

## What was verified

`test_driver.hc`, through the real `Hgit(cmdline)` dispatcher, using an
entity ID read from the **actual tree** (not invented):

```
DISPATCH_OK offer
found1=1
real_entity_hex=e8e05d0b92720eae
DISPATCH_OK correct
rel_tag2=2 (expect 2) entity_matches=1
DISPATCH_OK correct
rel_tag3=2 (expect 2) rel_entity3=0 (expect 0, unscoped)
PASS entity_scoped_relations
```

- A real `hgit correct` naming `P53FileA.txt`'s genuine entity ID
  (`e8e05d0b92720eae`, read from the tree via `TreeFindEntry`, the same
  way `hgit see` would show it) produces a commit whose
  `relation_entity_id` matches that exact value.
- A second real `hgit correct`, passed the all-zero sentinel, produces
  a commit with `relation_entity_id == 0` — the unscoped, whole-commit
  case from ADR 0005 still works unchanged.

## Not yet done

- No validation that a supplied entity ID actually exists in either
  commit's tree — pure storage, no policy, matching every prior
  object-format ADR's first slice.
- `revert`/`reconcile` weren't independently re-verified with
  entity-scoping specifically (only `correct` was, in this probe) —
  they share the identical `HgitOfferRelatedCmd` code path already
  independently verified for the tag-only case in probe 52, but per
  this project's own standing rule that's a real, honestly-flagged gap,
  not assumed equivalent.

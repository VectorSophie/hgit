# Probe 49 — ADR 0004's stable entity ID, PASS

Status: **PASS**, real, on real TempleOS under QEMU
(`serial-log-passing-run.txt`). First implementation of M3's stable
entity identity concept, per `docs/adr/0004-stable-entity-identity.md`.

## What changed

`src/hgit-core/Tree.HC`: every tree entry gained an 8-byte `entity_id`
field (`[name_len][name][child_type][64-byte hash][8-byte entity_id]`).
`GenerateEntityId()` combines two `RandU32` reads into a random `U64`
(confirmed real in probe 48). `TreeEncodeEntry`/`TreeFindEntry` both
take/return it now.

`src/hgit-cli/Offer.HC`: before building the new tree, looks up the
**parent commit's own tree** (via `Index.HC`, same pattern
`History.HC`/`See.HC`/`Status.HC` already use) so each currently-offered
file's entity ID can be copied forward from the old entry of the same
name (`TreeFindEntry`) — a fresh ID (`GenerateEntityId()`) is only
generated for a name that wasn't in the parent's tree (a genuinely new
file, or a root offering with no parent at all).

`src/hgit-cli/See.HC`/`Status.HC`: both manually walk tree entries
(not via `TreeFindEntry`) and needed their own offset fix for the new
8-byte field — a real, easy-to-miss consequence of a format change
that isn't behind a single shared function, caught by checking every
caller (`grep`) before considering this probe's implementation
complete, not just the one obvious call site.

## What was verified

`test_driver.hc`, through the real `Hgit(cmdline)` dispatcher for every
`offer`, with direct `TreeFindEntry` reads (not internal state) for
verification:

```
DISPATCH_OK offer
found1=1 id1=6918486067039080059
DISPATCH_OK offer
found2=1 id2=6918486067039080059
id_same_across_offers=1 blob_hash_differs=1
DISPATCH_OK offer
foundB=1 idB=-3748984827403573720
foundA3=1 fileA_id_still_same=1
idB_is_different=1
PASS entity_id
```

- `P49FileA.txt` offered twice, with **different content** both times
  (confirmed: `blob_hash_differs=1`, a real byte comparison of the two
  blob hashes) — its entity ID is **identical** across both offers
  (`id_same_across_offers=1`). This is the actual point: identity
  survives content changes, unlike the hash.
- A third offer introduces `P49FileB.txt` (a genuinely new name) in the
  same pass that re-offers `P49FileA.txt` again — `FileB` gets a
  **different** ID from `FileA`'s (`idB_is_different=1`), and `FileA`'s
  own ID is **still** the same value it had from the very first offer,
  two generations earlier (`fileA_id_still_same=1`) — proving the
  carry-forward logic reaches back through the parent chain correctly,
  not just "the immediately previous offer."

(`idB` prints as a negative number — an artifact of `CommPrint`'s
`%d` format on a `U64` value with its high bit set, not a bug; the
actual `idB_is_different`/`fileA_id_still_same` checks compare raw
`U64` bit patterns directly, unaffected by how the value happens to
print.)

## Not yet done (per ADR 0004's own scope)

- No rename detection - a file renamed between offers gets a fresh ID,
  indistinguishable from delete+create. Not attempted here.
- No relation vocabulary (CONTINUES/CORRECTS/REVERTS/RECONCILES) yet -
  this probe only makes IDs exist and persist; nothing refers to them
  yet.
- `FORMAT.md` not yet updated to document the new tree-entry shape -
  real follow-up documentation work, not done in this probe.
- Every OLDER probe (10, 18-22, 30-47) that built or read a tree object
  used the previous 65-byte-per-entry shape; none were re-verified
  against the new 73-byte shape - only probe 49's own fresh repo was
  tested. A repo created under the old format cannot be read correctly
  by this new code (no migration exists or is planned - ADR 0004 states
  this as an explicit non-goal, matching this project's "no released
  users yet" stance).

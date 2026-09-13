# Probe 51 — `hgit correct`/`revert`/`reconcile`: real relation commands, PASS

Status: **PASS**, real, on real TempleOS under QEMU
(`serial-log-passing-run.txt`). Wires ADR 0005's relation vocabulary
(built and verified standalone in probe 50) into a real command
surface — the last piece ADR 0005 flagged as "not yet done."

## Design

`Offer.HC`: `HgitOffer` is now a thin wrapper over a new
`HgitOfferWithRelation(repo_path, find_mask, message, message_len,
timestamp, relation_tag, relation_target)`, which does everything the
original `HgitOffer` did plus passes the relation through to
`CommitEncode`. (`HgitOfferWithRelation` is defined *before*
`HgitOffer` in the file — HolyC has no forward declarations, so the
function being called needed to come first.)

`Hgit.HC`: a shared `HgitOfferRelatedCmd(rest, relation_tag, cmd_name)`
parses `<repo> <target_hex> <find_mask> <message...>`, decodes the hex
target via `Hex.HC`'s `HexToHash`, and calls `HgitOfferWithRelation`.
Three thin dispatch branches (`correct`/`revert`/`reconcile`) each call
it with the matching `REL_*` tag — no tripled logic.

`See.HC`: `hgit see` now prints `SEE_RELATION tag=... target=...` (hex)
when a commit carries one, alongside its existing commit/tree output —
the natural place a user would check what a commit's relation is.

## What was verified

`test_driver.hc`, entirely through the real `Hgit(cmdline)` dispatcher:

```
DISPATCH_OK offer
head1_hex=34ab512f0b71f57f...bd14bca
DISPATCH_OK correct
rel_tag=2 (expect 2, REL_CORRECTS) target_matches_head1=1
msg=fixes the bug from the previous commit
SEE_COMMIT ts=1782790 parents=1 msg=fixes the bug from the previous commit
SEE_RELATION tag=2 target=34ab512f0b71f57f...bd14bca
SEE_TREE entries=1
  entry id=2483912366885522070 name=P51FileA.txt
SEE_END
PASS relation_commands
```

- A real `hgit correct <repo> <target_hex> <find_mask> <message>`
  produced a commit whose `relation_tag` is genuinely `REL_CORRECTS`
  and whose target hash **exactly matches**, byte for byte, the prior
  commit's real hash noted before the command ran (`target_matches_head1=1`)
  — not just plausible-looking output.
- `hgit see` on the resulting commit independently shows the same
  relation (`SEE_RELATION tag=2 target=34ab512f0b71f57f...`) — visibly
  the identical hex string as `head1_hex` printed earlier — confirming
  the relation survives a full round-trip through the object store and
  back out through a completely different code path (`See.HC`, not the
  test's own direct accessor calls).
- The tree entry's entity ID (ADR 0004) still shows correctly in the
  same output — confirms the two M3 features (stable identity,
  relations) coexist correctly in one real commit, not just in
  isolation from each other.

## Not yet done

- No entity-scoping — `correct`/`revert`/`reconcile` name a whole
  target commit, not a specific tracked file/entity within it (still
  ADR 0005's own stated scope, unchanged).
- `revert`/`reconcile` share the exact same command shape as `correct`
  (only the tag differs) and weren't independently exercised in this
  probe beyond `correct` — the shared `HgitOfferRelatedCmd` helper
  makes this low-risk, but it's still an honest gap: only `correct`
  was pushed through the real dispatcher and verified.

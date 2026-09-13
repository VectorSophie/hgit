# Probe 52 — `hgit revert`/`hgit reconcile`, independently verified, PASS

Status: **PASS**, real, on real TempleOS under QEMU
(`serial-log-passing-run.txt`). Closes an honestly-flagged gap from
probe 51: `revert`/`reconcile` share `correct`'s exact code path
(`HgitOfferRelatedCmd`, only the `REL_*` tag differs), but per this
project's own standing rule — never claim a test passed without
actually running it — that similarity was documented as *not* a
substitute for pushing them through the real dispatcher independently.
This probe does that.

## What was verified

`test_driver.hc`, through the real `Hgit(cmdline)` dispatcher:

```
DISPATCH_OK offer
DISPATCH_OK revert
revert_tag=3 (expect 3, REL_REVERTS) revert_target_ok=1
DISPATCH_OK reconcile
reconcile_tag=4 (expect 4, REL_RECONCILES) reconcile_target_ok=1
PASS revert_reconcile
```

- A real `hgit revert <repo> <target_hex> <find_mask> <message>`
  produced a commit with `relation_tag == REL_REVERTS` (3) and a
  target hash matching the named prior commit exactly (byte
  comparison).
- A real `hgit reconcile` (naming the revert commit as its own target)
  produced a commit with `relation_tag == REL_RECONCILES` (4) and its
  own target hash matching correctly too.
- Both checked by reading the resulting commit object directly (via
  `Index.HC`/`Commit.HC`'s accessors), not by trusting the dispatcher's
  own `DISPATCH_OK` line.

With this, all three relation commands (`correct` — probe 51,
`revert`/`reconcile` — this probe) have each been independently pushed
through the real dispatcher and verified, not just inferred from shared
code.

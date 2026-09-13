# Probe 59 — `hgit reconcileoverview`: a real multi-commit reconciliation view

Status: **PASS** — the concrete follow-up probe 58 flagged ("Multiple
relations in one document (e.g. a real multi-commit reconciliation
overview...) isn't built").

## What this does

`src/hgit-cli/ReconcileDoc.HC` is refactored: the per-commit rendering
logic (short hash/message, then a real `$TR$`/`$ID$` tree node for its
relation if it has one - probes 57/58) is factored out into
`ReconcileEmitCommit`, a shared helper returning whether the commit had
a relation at all. `HgitReconcileDoc` (single commit, unchanged
behavior) is now a thin wrapper over it. A new command,
`hgit reconcileoverview <repo> <dest.DD>`, walks the **entire** real
parent chain from HEAD (the same walk `HistoryDoc.HC` already does)
and calls the shared helper for every commit, keeping only the ones
that actually carry a relation - an ordinary offer contributes nothing
to this view (`hgit historydoc` already covers plain history; cluttering
this one with every commit would defeat its purpose).

`HgitReconcileOverview` marks a `dlen` position before calling the
shared helper and rolls back to it if the commit turns out to have no
relation, rather than teaching the helper to peek ahead before writing
anything - the helper unconditionally writes the commit's own
hash/message header first, so a no-relation commit's header needs
undoing after the fact.

## Real bug hit and fixed while writing this: `pi` again

The parent-hash copy loop in `HgitReconcileOverview` first used `I64
pi; for (pi=0; pi<64; pi++) ...` - the exact same reserved-identifier
collision documented in probe 41
(`docs/research/01-templeos-holyc.md`), producing the same
`ERROR: Expecting '*' at "INT:400921FB54442D18"` (π's own IEEE754 bit
pattern). Renamed to `pj`. Notable because this project has documented
this exact quirk since probe 41 and it was still hit again here,
directly - a reminder that documenting a mistake doesn't reliably
prevent repeating it (the same thing happened with probe 12's
index-offset mistake, per `History.HC`'s own comments), so the fix
belongs in the file's own comment too (now added), not just the
research doc.

## Verified

Built a real repo with four commits: two ordinary offers, one
`correct` (a real relation), then one more ordinary offer on top.
`serial-log-passing-run.txt` shows two full independent runs (one
against the two touched files pushed standalone, one against a
freshly-rebuilt `packaging/HgitAll.HC` pushed whole from scratch),
each `init`→`offer`→`offer`→`correct`→`offer`→`reconcileoverview`, all
`DISPATCH_OK`, `PASS p59_reconcile_overview`.

`raw-doc-content.txt` — the real `.DD` bytes read back: exactly one
`$TR$` node (for the `correct` commit), correctly showing its own
short hash, its own message (`correcting_offer_two`), the relation type
(`CORRECTS`), a real `$LK$` link to its target, and the target's own
message (`plain_offer_two`) - the three *ordinary* offers are correctly
absent from the document entirely, not just hidden by rendering.

`evidence/rendered-overview.png` — the same document open in `Ed()`:
title, the one relevant commit, and its `[+] relation: CORRECTS` node,
collapsed by default (probe 57's own finding).

Also re-verified `hgit reconciledoc` (single-commit) still works
unchanged after the refactor - same `init`→`offer`→`correct`→
`reconciledoc` scenario from probe 58, still `PASS`.

## Guard added: same class of buffer risk probe 56 found in `Offer.HC`

`doc[8192]` is otherwise unbounded against a repo's real
relation-carrying-commit count and message sizes - the exact same class
of bug probe 56 root-caused and fixed. Added a heuristic stop (loop
breaks with a `truncated` flag once `dlen` is within 1024 bytes of the
buffer's end, printing a clear "truncated" notice) rather than leaving
the same landmine for a future probe to rediscover. Re-verified
end-to-end after adding it (same passing scenario, well under the
threshold so behavior is unchanged) - a repo with enough
relation-carrying history to actually trigger truncation wasn't
constructed in this probe, so the guard's own trigger path is
implemented and reasoned through but not itself exercised.

## Not yet done

- The truncation guard's own trigger path (a repo with enough history
  to actually hit it) isn't exercised by a real test in this probe -
  see above.
- Still doesn't implement following a link or expanding a node
  interactively (`Ed()` blocks the daemon - probe 54's own scoping,
  unchanged).

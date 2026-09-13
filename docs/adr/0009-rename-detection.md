# ADR 0009 — Exact-content rename detection

## Status

**Decided and implemented**, including its own follow-up UI work.
Closes the gap ADR 0004 explicitly deferred: "an actual rename is NOT
detected here... a renamed file gets a new ID, indistinguishable from
delete+create" - its own "what this slice does not do" section.

**Addendum (probe 71, `experiments/71-status-rename-surfacing/`)**:
the last item this ADR's own "what this slice does not do" section
flagged - "does not surface the rename to the user in any command's
own output yet" - is now also done. `hgit status` applies the same
exact-content matching (working-directory files vs. HEAD's tree,
rather than old-tree vs. new-tree at offer time) and reports
`STATUS_RENAMED <old> -> <new>` instead of separate `STATUS_NEW`/
`STATUS_DELETED` lines when a NEW-on-disk file's content hash matches
a DELETED tree entry's hash. Verified with a real repo carrying an
unrelated genuinely-new file and an unrelated genuinely-deleted file
alongside the real rename, confirming no false-positive pairing.

## Context

ADR 0004 gave every tree entry a stable entity ID, carried forward
across offers **by name**: if a file's name matches an entry in the
parent commit's own tree, its ID is copied forward; otherwise a fresh
ID is generated. A real rename (same content, different name) was
explicitly out of scope for that first slice - the new name gets a
fresh ID, and the old name's entry simply disappears from the new
tree, indistinguishable from "this file was deleted and an unrelated
new file was created."

This matters because entity IDs are the whole point of ADR 0004 -
they're what lets `hgit correct`/`revert`/`reconcile` (ADR 0005/0006)
name "this specific tracked thing" independent of its current content
or name. A rename that silently breaks identity defeats that purpose
for the renamed file.

## Decision

When a currently-offered file's name does **not** match any entry in
the parent commit's own tree (i.e., `TreeFindEntry` by name fails),
before generating a fresh entity ID, also check whether its **content
hash** matches an entry in that same old tree (`TreeFindEntryByHash`,
new in `Tree.HC`). If it does, treat this as a rename: carry that old
entry's entity ID forward, instead of generating a fresh one. If
neither the name nor the content hash matches anything old, it's
genuinely new - generate a fresh ID, unchanged from ADR 0004.

This is **exact-content rename detection only** - the same simplicity
level as Git's own 100%-similarity rename detection, not a fuzzy/
partial-similarity heuristic (Git's own "detect renames with M%
similarity" needs a real diff algorithm this project doesn't have -
`docs/adr/0008-fossil-delta-format-prototype.md`'s own prototype isn't
even reliable enough to adopt yet). A file that's renamed **and**
edited in the same offer is not detected as a rename here - it looks
like a genuinely new file (this ADR's own "what this slice does not
do").

## Alternatives considered

- **Fuzzy/similarity-based rename detection** (matching Git's own
  default `-M50%` behavior): rejected for this slice - needs a real
  diff/similarity algorithm, which this project doesn't have reliably
  (ADR 0008's own Fossil prototype has an unresolved reliability gap).
  Exact-content matching needs no diffing at all - just a hash
  comparison, already-available machinery.
- **Tracking renames via a separate, explicit `hgit rename` command**
  (the user declares the rename, rather than it being inferred):
  rejected as a much bigger UX/workflow question, and inference (when
  it's unambiguous, as exact-content matching is) is strictly more
  convenient - an explicit command can always be added later without
  conflicting with this.
- **Matching multiple candidate old entries and picking the "best"
  one** (e.g. by name similarity, if several old entries share the
  same content hash): rejected for this slice - take the first match
  found by the same linear scan `TreeFindEntry` already uses,
  documented as a known simplification (same honest-limitation
  pattern every prior ADR in this project uses), not a hidden bug.

## What this slice does not do

- Does not detect a rename where the content also changed in the same
  offer (looks like a new file - the name doesn't match, and now
  neither does the content hash).
- Does not disambiguate multiple old entries sharing the same content
  hash - takes the first one `TreeFindEntryByHash`'s own linear scan
  finds, which could occasionally pick the "wrong" one if a repo
  legitimately had duplicate-content files under different names
  before one of them was renamed.
- ~~Does not surface the rename to the user in any command's own
  output~~ **Now done for `status`** (probe 71): `hgit status` reports
  `STATUS_RENAMED <old> -> <new>`. `hgit history`/`hgit reconciledoc`
  still don't surface a rename the same way - extending the idea to a
  commit-vs-commit history view remains separate, real follow-up work.

## Costs

- One more linear scan per not-found-by-name file (`TreeFindEntryByHash`,
  same cost profile as the existing `TreeFindEntry` by-name scan) -
  acceptable at this project's own established "no premature
  optimization" stance (`Index.HC`'s own precedent).

## What would justify revisiting this

- If real usage shows the "first match wins" ambiguity (multiple old
  entries sharing a content hash) causes a real, observed identity
  mix-up - would need a tie-breaking heuristic (e.g. prefer a name
  similarity match) not designed here.
- If a renamed-and-edited-in-the-same-offer case turns out to be common
  enough to matter - would need real content-similarity detection,
  which needs ADR 0008's own Fossil prototype (or an alternative) to
  actually be reliable first.

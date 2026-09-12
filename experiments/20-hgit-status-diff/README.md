# Probe 20 — `hgit status`'s real comparison logic, real TempleOS

Status: **PASS after fixing one missing dependency in the test itself.**
Closes `Status.HC`'s `STATUS_UNIMPLEMENTED` branch (probes 16/18) —
`status` can now actually compare the working directory against HEAD's
tree, not just handle the trivial empty-repo case.

## What it does

Walks HEAD → its commit (`Commit.HC`) → its tree (`Tree.HC`) via
`Index.HC`, then for each file matching `find_mask`: hashes its current
content the same way `Offer.HC` would (tag + content, `B2Hash512Any`),
looks up the same filename in the tree's entry list
(`TreeFindEntry`), and classifies it:

- not found in the tree → `STATUS_NEW`
- found, hash matches → `STATUS_UNCHANGED`
- found, hash differs → `STATUS_MODIFIED`

## A missing-dependency mistake, caught immediately

First push produced no status output at all — just `D_OK`/`D_DONE`,
no error visible until a screendump showed a real compile error:
`Undefined identifier` on a call to `WorkDirList()`. Cause: the test's
source concatenation forgot to include `WorkDir.HC` — needed for
`Status`'s zero-offering branch, which this test's repo (`rcount=8`)
never actually takes at runtime, but HolyC still resolves every
referenced symbol at compile time regardless of which branch executes.
Fixed by adding the missing file to the concatenation; the daemon
survived the failed push (same "prints to screen, doesn't crash the
loop" pattern seen before) and accepted the corrected push immediately
after with no reboot needed.

## What was tested, after the fix

Against the real, already-persisted two-offering repository from probes
18/19 (`OfferTestRepo.hgs`, files `OfferFileA.txt="hello"`,
`OfferFileB.txt="world!!"` as of the last offer):

1. **No changes since the last offer** → both files correctly report
   `STATUS_UNCHANGED`.
2. **Modified `OfferFileA.txt`, added a brand-new `OfferFileC.txt`**,
   re-ran status → `STATUS_MODIFIED OfferFileA.txt`,
   `STATUS_UNCHANGED OfferFileB.txt` (untouched, correctly still
   unchanged), `STATUS_NEW OfferFileC.txt` (not in any tree yet).

All three classifications correct, verified against real content-hash
comparisons, not just presence checks.

## Landed as real hgit-cli source

`src/hgit-cli/Status.HC` — replaces the earlier stub
(`STATUS_UNIMPLEMENTED`) with the real comparison logic, merged with the
already-verified zero-offering case from probe 16. Logic identical to
the tested version (confirmed via diff — only a function rename,
`HgitStatus2`→`HgitStatus`, and added comments).

## Not yet done

- **No deleted-file detection** — a file present in the tree but
  missing from the working directory isn't reported at all. Real gap,
  not yet built.
- Still requires an explicit `find_mask`, same as `Offer.HC` — no
  automatic repo-self-exclusion.
- Only a single-level (flat) tree is walked — matches what `Tree.HC`
  itself has tested so far (no nested/recursive trees exercised yet).

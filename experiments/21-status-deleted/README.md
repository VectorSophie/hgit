# Probe 21 — `hgit status` deleted-file detection, real TempleOS

Status: **PASS, first try.** Closes the last real gap probe 20 flagged:
a file present in HEAD's tree but missing from the working directory is
now reported.

## Grounding the deletion call in primary source first

Needed to actually delete a file for this test and hadn't used file
deletion before. Rather than guess a name, searched the real
`cia-foundation/TempleOS` clone: no plain `FileDel` exists. The real API
(`Kernel/BlkDev/DskCopy.HC`) is `Del(files_find_mask, make_mask=FALSE,
del_dir=FALSE, print_msg=TRUE)` — a mask-based delete (a literal
filename works as a trivial one-file mask), with a `print_msg` flag that
was worth noticing and suppressing (`FALSE`) to keep test output clean.

## What was tested

Against the real, already-persisted repository from probes 18–20
(`OfferFileA.txt` already `MODIFIED`, `OfferFileC.txt` already `NEW` per
probe 20's last run): deleted `OfferFileB.txt` (previously
`UNCHANGED`), then ran the extended status check. Result:

```
STATUS_MODIFIED OfferFileA.txt
STATUS_NEW OfferFileC.txt
STATUS_DELETED OfferFileB.txt
STATUS_END
```

All three: A and C correctly unaffected by B's deletion (still their
prior classifications), and B correctly newly reported `DELETED` — a
tree entry with no corresponding file on disk.

## How it works

A second pass over HEAD's tree (separate from the first pass, which is
driven by what's on disk) — walks every entry in the tree's own list
and checks `FileRead` for existence at the reconstructed path. This is
the first place in `hgit-core` that needed "everything the tree says
should exist," rather than a single name lookup — handled inline in
`Status.HC` rather than adding a new generic iteration API to `Tree.HC`
for one caller.

## Landed as real hgit-cli source

`src/hgit-cli/Status.HC` — merges this pass into the existing new/
modified/unchanged logic (probe 20) and the zero-offering case
(probe 16). Logic identical to the tested version (confirmed via diff —
only a function rename and added comments).

## Not yet done

- `dir_prefix` must be passed in manually and must literally match
  `find_mask`'s directory portion — no automatic derivation.
- Still no recursive/nested-tree support (matches `Tree.HC`'s own
  current scope).
- `hgit status` is now feature-complete for a flat, single-tree
  repository at M1 scope. Real next targets: `hgit see <offering>`,
  and eventually wiring all of `init`/`status`/`offer`/`history` behind
  an actual argv-driven `hgit` entry point.

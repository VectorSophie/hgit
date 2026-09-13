# Probe 67 — two more real buffer bugs found by auditing, not guessing

Status: **PASS** — a proactive audit of every remaining fixed-size
buffer in the codebase (after probes 60-62/66 closed out `Offer.HC`/
`Index.HC`-call-site/`Meta.HC`'s own instances) found two more real,
previously-unguarded risks, both reproduced and fixed.

## `HistoryDoc.HC`'s `doc[8192]`: a real crash, reproduced against a real repo

`hgit historydoc` builds its whole output into a fixed `U8 doc[8192]`
with **no bound** against the repo's real commit count - unlike its
sibling `HgitReconcileOverview` (probe 59), which already had a
truncation guard. Tested directly against the real ~300-commit
`P66Repo.hgs` left over from probe 66's own stress test (no synthetic
setup needed - the repo already existed) and got a genuine kernel GPF:
`RIP:0000DB2A:&StrNew+0x0021` (`evidence/gpf-crash-before-fix.png`) -
the crash surfacing inside an unrelated kernel string-allocation
function is the same signature as probe 60's own `CommitEncode` crash:
stack corruption from the buffer's own overflow, manifesting wherever
the corrupted stack next gets used, not necessarily at the write site
itself.

**Fix**: added the same truncation guard `HgitReconcileOverview`
already uses - before appending each commit's entry, check
`dlen + mlen > 8192 - 256` (256 bytes of margin for the fixed-size
parts of one entry: hash prefix, timestamp, `$..$` commands) and stop
cleanly with a `(truncated - too much history for one document)`
notice instead of overflowing.

## `Status.HC`'s `tagged[512]`: the same per-file-size bug probe 56 fixed in `Offer.HC`, unfixed here

`hgit status`'s per-file loop hashes each matched file's content into
a fixed `U8 tagged[512]` with no size check - any matched file over
511 bytes overflows it, identical to the bug probe 56 found and fixed
in `Offer.HC`'s `blob_tagged[512]`, just never applied here. Fixed the
same way: a file that doesn't fit reports `STATUS_TOO_LARGE_TO_CHECK
<name>` and is skipped, instead of corrupting memory.

## Verified

- Rebooted the VM fresh, pushed the rebuilt package as the first
  source compiled that session - clean compile.
- Re-ran `hgit historydoc` against the real ~300-commit repo that
  previously crashed: completes cleanly now, `DISPATCH_OK historydoc`,
  `PASS`. Read the generated document's raw bytes back directly
  (not just trusted the dispatch code) and confirmed it ends with the
  real truncation notice, not corrupted/truncated mid-entry -
  `DOC_SIZE=7978`, safely under the 8192 cap.
- Ran `hgit status` against a real, deliberately oversized (600-byte)
  file matched by `find_mask`: `STATUS_TOO_LARGE_TO_CHECK
  P67CBig.txt`, no crash.
- Ran a normal small-repo regression (`init`/`offer`/`status`/
  `historydoc`) afterward - unaffected, same output as before either
  fix.

## Not yet done

- `Object.HC`'s own `tagged[4096]` (in `ObjectPut`) is currently safe
  only because every caller already bounds its own content (probe 56's
  guards cap blob/tree/commit content well under 4096) - not
  independently guarded at the `ObjectPut` level itself. Flagged as a
  real, lower-priority risk: if a future caller ever passes unbounded
  content directly to `ObjectPut`, this buffer has no defense of its
  own.
- `Archive.HC`'s `hgit_archive[1024]` (the original M0
  global-buffer-based `ArchivePut`) was not touched - confirmed it has
  no real callers in any current command (superseded by `Hgs.HC`'s
  parameterized `HgsPut`), so it's dead code risk, not a live one - a
  separate cleanup candidate, not fixed here.

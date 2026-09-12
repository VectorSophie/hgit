# Probe 36 — path-scoped operation log, PASS (after finding a real filesystem limit)

Status: **PASS**, real, on real TempleOS under QEMU
(`serial-log-passing-run.txt`, `evidence-pass.png`). Also discovered a
genuine, previously-undocumented TempleOS/RedSea path-length limit —
see below; this is the main technical finding of this probe, not a
footnote.

## What changed

`src/hgit-cli/OpLog.HC`: both `.oplog` and `.redolog` become path-
scoped, same "main" convention as `Paths.HC`'s `PathHeadFilePath` —
main's logs stay at the original bare `<repo_path>.oplog`/`.redolog`
(byte-identical to probes 30-35, so nothing that never touches paths
changes); any other path gets its own log file. `OpLogUndo`/
`OpLogRedo` switch from plain `HeadWrite` to `CurrentHeadWrite` — this
was deliberately *not* done in probe 35, specifically because a single
shared-across-paths log made path-aware undo/redo unsafe (an undo on
path B could revert a HEAD hash belonging to path A's history). Now
that each path's log is its own file, that's fixed.

## A real bug found, chased down properly, and root-caused

First attempt at this probe's test genuinely **FAILED** (reported
honestly, not hidden): `feature_head_restored_by_own_redo=0` and
`feature_untouched_by_main_undo=0`. Investigated with five successive
diagnostic pushes rather than guessing:

1. Confirmed `feature`'s undo *did* correctly revert its own HEAD and
   leave `main` untouched (so `CurrentHeadWrite`/`CurrentPathGet`
   themselves were fine) - but its `.redolog` file was found not to
   exist at all afterward.
2. Isolated further: even calling `OpLogAppend` **directly** (bypassing
   `Offer.HC`/`Hgit()` entirely) on a hand-built 64-byte hash pair
   failed to create the file.
3. Isolated further still: a **plain literal `FileWrite`** call to the
   exact hardcoded path string, no helper functions involved at all,
   also silently failed to create the file - ruling out every layer of
   this project's own code as the cause.
4. Cross-checked a sibling, previously-*working* shape
   (`<repo>.head.feature`, verified in probes 34/35) against the same
   repo name and found it **also** failed for a longer suffix
   (`.head.feature2`) - the common factor wasn't "oplog" as a word, it
   was total string length.
5. A dedicated binary-search probe (`diag6b.hc`, correctly wrapped in a
   real function per this project's own established quirk about bare
   top-level loops - `diag6.hc`, its unwrapped first attempt, produced
   nonsense `len=0` output for exactly that documented reason and was
   discarded) pinned the exact boundary: **a full path string of 33
   characters round-trips through `FileWrite`/`FileRead` correctly; 34
   characters silently fails** - the call neither errors nor throws,
   the file simply isn't created/found afterward.

This is a real, previously-undocumented TempleOS/RedSea constraint,
now recorded in `docs/research/01-templeos-holyc.md`. It directly
explained the failure: `C:/Home/P36Repo.hgs.oplog.feature` was 34
characters wide - one over the limit - while `C:/Home/P34Repo.hgs.head.feature`
(32 characters, prior probes' path shape) fit comfortably.

**Fix:** shortened the non-main suffix from `.oplog.<name>`/
`.redolog.<name>` to `.ol.<name>`/`.rl.<name>` (still `.oplog`/
`.redolog` unchanged for "main" - only the per-path case, which is new
in this probe, needed shortening). Re-running the *same* test after
this fix produced a clean, real `PASS`:

```
DISPATCH_OK offer
DISPATCH_OK undo
feature_head_reverted_by_own_undo=1
main_untouched_by_feature_undo=1
DISPATCH_OK redo
feature_head_restored_by_own_redo=1
DISPATCH_OK path_go main
DISPATCH_OK undo
feature_untouched_by_main_undo=1
PASS path_scoped_oplog
```

(The `DISPATCH_ERR path_new_failed feature` line earlier in the same
log is expected, harmless residue of re-running the identical test
against the same already-initialized repo from the first, failed
attempt - `feature` already existed in the path list from that run,
so `path new` correctly refused to recreate it. Not a bug.)

## Architectural implication - not fully resolved here

This 33-character full-path ceiling is a real, load-bearing constraint
on **every** sidecar-file-per-concern design this project has used so
far (`.head`, `.oplog`, `.redolog`, `.paths`, `.currentpath`, and now
their per-path variants) - any sufficiently long repository path
combined with a reasonably long path name will eventually exceed it,
regardless of how short an individual suffix is made. Shortening
`oplog`/`redolog` to `ol`/`rl` buys headroom but doesn't remove the
ceiling. A durable fix (e.g., a single combined per-repo metadata file
instead of N growing sidecar files, or short hash-derived suffixes
instead of literal path names) is real future design work, flagged
here as a known risk for a future ADR - not decided or built in this
probe.

## Not yet done

- `hgit operation restore <op>` still not built.
- The general path-length-ceiling risk above is documented, not fixed
  at the architecture level.

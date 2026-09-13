# Probe 65 — deleting `Head.HC`, a real decision made and verified

Status: **PASS** — makes the deletion decision every prior commit
touching `Head.HC` deferred as "a separate decision, not made here"
(`experiments/43-paths-on-meta/`, `experiments/44-oplog-on-meta/`, ADR
0003), now that there's no remaining reason not to.

## Why now

`Head.HC` (`HeadPath`/`HeadRead`/`HeadWrite`, a single-pointer-per-repo
sidecar file, `<repo_path>.head`) was M1's original HEAD mechanism,
fully superseded by `Meta.HC`'s combined metadata file once ADR 0003
was implemented (`experiments/43-paths-on-meta/`,
`experiments/44-oplog-on-meta/`) - every real command has run on
`Paths.HC`'s `CurrentHeadRead`/`CurrentHeadWrite` (backed by
`Meta.HC`) instead, since then. Confirmed by grep before touching
anything: zero real call sites anywhere in `src/` reference
`HeadRead`/`HeadWrite`/`HeadPath` outside `Head.HC`'s own definitions -
not "probably unused," actually zero.

## What was done

- Deleted `src/hgit-cli/Head.HC`.
- Removed its line from `tools/build-package.sh`'s build order.
- Cleaned up four stale "Depends on ... `Head.HC`" comments that no
  longer reflected reality (`History.HC`, `Hgit.HC`, `Offer.HC`,
  `Status.HC`) - these were dependency-comment drift, not functional
  code, but worth fixing since a stale dependency comment is
  misleading documentation.
- `docs/adr/0003-path-length-ceiling.md`'s own historical narrative
  (describing what `Head.HC` *was*, at the time ADR 0003 was
  implemented) is left unchanged - it's an accurate record of that
  point in the project's history, not a stale claim about the current
  codebase.

## Verified on a truly fresh boot (not an already-warm session)

Rebooted the QEMU VM from scratch, redid the full stage-1→stage-2
daemon bootstrap, then pushed the rebuilt `packaging/HgitAll.HC` (with
`Head.HC` fully absent) as the **first and only** source this session
ever compiled - proving nothing else in the package secretly still
needed `Head.HC`'s functions, not just asserting it. Compiled clean.

Then ran a real end-to-end regression covering every command family
that plausibly could have depended on the old HEAD mechanism:
`init`, `offer` (x2), `undo`, `redo`, `path new`/`path go`, `history`,
`status`, `check`, `historydoc`, and `see` - all in one real session,
against one real repo. `serial-log-passing-run.txt` shows every
command's correct output (`DISPATCH_OK` throughout, `HISTORY_END
shown=2`, `STATUS_UNCHANGED`, `CHECK_OK objects=6`, a correct
`SEE_COMMIT`/`SEE_TREE`), ending in `PASS
p65_head_deletion_regression`. Confirmed the daemon still fully
responsive afterward.

## Not yet done

Nothing - this closes out the deletion question cleanly. The only
remaining trace of `Head.HC` is its own historical mention in prior
probes'/ADR's README files, which is correct: they describe what was
true when they were written, not what's true now.

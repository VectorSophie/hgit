# Probe 43 — Paths.HC cut over to Meta.HC, PASS: ADR 0003's first real payoff

Status: **PASS**, real, on real TempleOS under QEMU
(`serial-log-passing-run.txt`, `evidence-pass.png`). This is the first
real command wiring for ADR 0003 — not just another storage primitive,
but a working command (`hgit path new`/`go`, `offer`, `status`,
`history`) actually backed by the combined metadata file, with the
real path-length ceiling problem it was designed to fix demonstrably
gone for path names.

## What changed

`src/hgit-cli/Paths.HC` rewritten: every public function
(`CurrentPathGet`/`PathExists`/`PathListPrint`/`PathNew`/`PathGo`/
`CurrentHeadRead`/`CurrentHeadWrite`/`PathClose`) keeps its exact name
and signature, but is now a thin wrapper over `Meta.HC`'s
`MetaCurrentGet`/`MetaPathExists`/`MetaPathList`/`MetaPathDeclare`/
`MetaPathUndeclare`(new)/`MetaCurrentSet`/`MetaReadHead`/
`MetaWriteHead`. Because the public API didn't change, `Hgit.HC`,
`Offer.HC`, `History.HC`, and `Status.HC` needed **zero** changes —
they already called these same function names.

`MetaPathUndeclare` (new, in `Meta.HC`): removes a path's
`META_TAG_PATH_DECLARED` record via the existing `MetaSpliceOut`
primitive — needed so `PathClose` could keep its real "path no longer
exists afterward" contract.

`PathNameFits`'s *meaning* changed, not just its implementation: under
the old per-path-sidecar scheme it had to budget
`repo_path + ".head." + name <= 33`; under `Meta.HC` only
`repo_path + ".m" <= 33` matters — `name` no longer affects any
filename at all, so it's dropped from the actual check (kept as an
unused parameter only so `PathNew`'s call site didn't need to change).

`tools/build-package.sh`: added `Meta.HC` to the `hgit-core` section
(after `Index.HC`, needs `Canon.HC`'s `PutU64LE`/`GetU64LE` for its
operation-log slice). Rebuilt `packaging/HgitAll.HC` (90413 bytes).

`Head.HC`'s own `<repo_path>.head` sidecar file is now **effectively
retired for real commands** — nothing in `Offer.HC`/`History.HC`/
`Status.HC`/`OpLog.HC` calls `HeadRead`/`HeadWrite` directly anymore
(confirmed: `grep` finds zero real call sites, only comments and old
probes' own historical test code). `Head.HC` is left in the build for
now — not deleted — since removing it is a separate, deliberate
decision not made in this probe.

## What was verified

`test_driver.hc` reuses probe 35's exact scenario (one commit on
`main`, branch to `feature`, one more commit on `feature`) through the
real `Hgit(cmdline)` dispatcher, checking results via `MetaReadHead`
directly (not `Head.HC`'s now-obsolete `HeadRead`):

```
DISPATCH_OK offer
main_head1_meta_ok=1
DISPATCH_OK path_new feature
DISPATCH_OK path_go feature
DISPATCH_OK offer
main_unchanged_after_feature_offer=1
feature_head_ok=1 feature_differs=1
commit ts=1983675 msg=feature commit 1
commit ts=1982282 msg=main commit 1
HISTORY_END shown=2
commit ts=1982282 msg=main commit 1
HISTORY_END shown=1
STATUS_MODIFIED P43FileA.txt
STATUS_END
STATUS_UNCHANGED P43FileA.txt
STATUS_END
long_name_now_ok=1 (was rejected under the old scheme)
PASS paths_on_meta
```

- Every check from probe 35 (main/feature HEAD isolation, `history`
  entry counts differing by current path, `status` `MODIFIED`/
  `UNCHANGED` split) reproduces identically under the new backing
  store — real evidence this was a genuine drop-in cutover, not a
  behavior change.
- **The actual payoff**: `PathNew("C:/Home/P43Repo.hgs", "areallylongbranchname11")`
  (a 20-character repo path + a 20-character name — `repo + ".head." +
  name` would have been 46 characters under the old scheme, refused by
  probe 37's `PathNameFits` guard) now **succeeds**
  (`long_name_now_ok=1`). This is the concrete, demonstrated fix ADR
  0003 set out to deliver.

## Not yet done

- `OpLog.HC` (`undo`/`redo`/`operation history`/`operation restore`)
  still uses its own separate `.oplog.<name>`/`.redolog.<name>` sidecar
  files, not `Meta.HC`'s operation-log slice (built and verified
  standalone in probe 42, not wired in yet). That's the remaining
  piece of ADR 0003's real-command cutover.
- `Head.HC` itself is not deleted, just unused by real commands now -
  a deliberate decision on whether to remove it entirely is left open.

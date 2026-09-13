# Probe 101 — a real "delete a directory from disk" primitive found and verified

Status: **PASS.** Closes a real, repeatedly-flagged open question:
this project has stated since the DirTreeDel incident
(`docs/research/failed-approaches.md`'s 2026-09-14 entry) and ADR
0010/probe 94's own "Not yet done" lists that hgit has "no proven
primitive for deleting a real directory entry from disk." It does now
- found via real primary source, then confirmed with a real QEMU test,
not assumed from the source reading alone.

## What was found

Reading TempleOS's own real kernel source directly (this project's own
established capability since probe 76), `Kernel/BlkDev/DskCopy.HC`'s
own real `Del` signature:

```c
I64 Del(U8 *files_find_mask, Bool make_mask=FALSE,
        Bool del_dir=FALSE, Bool print_msg=TRUE)
```

This project has called `Del(path, FALSE, FALSE, FALSE)` throughout
its entire history - always with `del_dir=FALSE`. `del_dir` was never
previously investigated. Tracing into `Kernel/BlkDev/FileSysRedSea.HC`'s
own `RedSeaFilesDel` (RedSea being this project's own real target
filesystem, per doc 01) shows exactly what it controls - a matched
directory entry is only actually marked deleted if:

```c
(del_dir || !(ptr->attr & RS_ATTR_DIR))
```

With `del_dir=FALSE` (this project's own convention so far), a
directory entry never matches this condition and is never deleted -
exactly matching every prior real observation. With `del_dir=TRUE`, a
matched directory entry's own record IS marked deleted too.

## Verified (real QEMU run, not fabricated)

A real, minimal, isolated test (no hgit code involved, matching the
same caution the earlier DirTreeDel incident's own recovery used):
create a real directory with one file inside, delete the file
individually (the already-established safe practice), then call
`Del("C:/Home/P101Dir", FALSE, TRUE, FALSE)` - real, actual result:

```
P101_FOUND_BEFORE=1
P101_DIR_DEL_RESULT=0
P101_FOUND_AFTER=0
```

The directory entry existed before (`FilesFind` found it), `Del`
returned `0` (correct per `RedSeaFilesDel`'s own real return-count
logic - only non-directory deletions are counted, `if
(!(ptr->attr & RS_ATTR_DIR)) res++;`), and the directory entry is
genuinely GONE from disk afterward (`FilesFind` no longer finds it) -
not just emptied, the real directory entry itself.

**Regression**: `experiments/65-head-deletion/test_driver.hc` re-run
clean immediately after.

## Real, honest scope note

This test only exercises a directory that's already empty of its own
real files (deleted individually first). Whether `del_dir=TRUE` alone
(without emptying files first) also recursively frees a directory's
own contained files is a related, real, separate question this probe
doesn't answer - `RedSeaFilesDel`'s own code frees the directory
entry's allocated cluster space directly, which would orphan any real
files still inside rather than delete each one's own entry
individually. The established safe practice (delete every real file
individually first, then the now-empty directory) remains the correct
approach - this probe confirms the SECOND half of that sequence now
has a real, verified primitive, not that skipping the first half is
safe.

## Real, practical use

This closes the gap flagged in `experiments/94-diff-nested-trees/`'s
own README and ADR 0010's "not yet done" list. Any future probe that
needs to test "a whole subdirectory vanished from disk" (the
not-found-by-name DELETED-recursion branches in `Diff.HC`/`Status.HC`,
still only indirectly exercised via emptied-but-present directories -
see probe 94's own "Not yet done" note) can now use
`Del(dir_path, FALSE, TRUE, FALSE)` for real, after deleting the
directory's own files individually - a real, separate follow-up test,
not attempted in this probe.

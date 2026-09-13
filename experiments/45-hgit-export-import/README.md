# Probe 45 — `hgit export`/`import`: real whole-repo portability, PASS

Status: **PASS**, real, on real TempleOS under QEMU
(`serial-log-passing-run.txt`, `evidence-pass.png`). This is a direct,
concrete payoff of ADR 0003's full completion (probe 44) — a genuine
working-repo copy, not just the object-layer portability probe 39
proved.

## Design

`src/hgit-cli/Portable.HC`: `HgitCopyRepo(src_repo_path, dest_repo_path)`
copies the object file (`FileRead`/`FileWrite`, same pattern probe 39
already used) **and** `Meta.HC`'s combined metadata file
(`MetaPath(src)` → `MetaPath(dest)`). Since every tool-state concern
(HEAD for every path, path list, current-path, operation log, redo
log) now lives in that one `.m` file (ADR 0003, complete as of probe
44), copying exactly two files copies a repo's **entire** working
state — no need to discover or enumerate an unknown number of
per-path sidecar files, which is exactly the problem the old scheme
would have made this feature painful to build correctly. `hgit export
<repo> <dest>` and `hgit import <src> <dest>` both call the same
underlying copy, named for the two directions of use.

## What was verified

`test_driver.hc`: a repo with two paths (`main`, `feature`) and real,
independent history on each, exported to a brand-new path, then
checked entirely through the **copy** — not the original:

```
DISPATCH_OK export
dst_main_ok=1 main_matches=1 dst_feature_ok=1 feature_matches=1
PATH main
PATH feature
DISPATCH_OK path_list
commit ts=3680806 msg=feature commit 1
commit ts=3679494 msg=main commit 1
HISTORY_END shown=2
commit ts=3679494 msg=main commit 1
HISTORY_END shown=1
DISPATCH_OK undo
undo_changed_dst=1
src_untouched=1
PASS hgit_export_import
```

- Both paths' HEAD hashes on the copy match the originals exactly
  (byte comparison), with no other setup ever run against the new
  path — proof the `.m` file transferred correctly, not just the
  object bytes.
- `hgit path list`/`history` on the **copy**, through the real
  dispatcher, show the correct path names and per-path entry counts
  (2 on `feature`, 1 on `main`) — the copy's own tool state genuinely
  works, not just its object layer.
- `hgit undo` on the copy **actually changes its HEAD** — a real,
  mutable, independently-usable repository, going meaningfully further
  than probe 39's read-only object-access proof.
- The **original** repo is confirmed completely unaffected by
  anything done to the copy afterward — two real, independent repos,
  not an alias of the same underlying files.

## Not yet done

- No conflict handling if `dest` already exists (silently overwrites,
  same as every other `FileWrite` in this project — consistent, not a
  new gap).
- Doesn't validate that `src` is actually a valid `.HGS` repo before
  copying (would just copy garbage if given a bogus path) — no worse
  than any other command's error handling so far, not specifically
  hardened here.

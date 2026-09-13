# Probe 40 — Meta.HC combined metadata file (ADR 0003's first slice), PASS

Status: **PASS**, real, on real TempleOS under QEMU
(`serial-log-passing-run.txt`, `evidence-pass.png`). First concrete
implementation slice of `docs/adr/0003-path-length-ceiling.md`'s
decision — a single combined per-repo metadata file, standalone and
**not yet wired into** `Head.HC`/`Paths.HC`/`OpLog.HC` or any real hgit
command (same incremental pattern as `OpLog.HC`: built standalone in
probe 30, wired in later).

## Design

`src/hgit-core/Meta.HC`: `<repo_path>.m` — one short, fixed suffix that
never grows regardless of how many paths exist or how long their names
are, because path names live inside the file's own record structure as
data, not in filenames as identity. Record format: `[U8 name_len][name]
[U8 tag][U8 payload_len][payload]`, flat and read-until-EOF (same style
as `Paths.HC`'s `.paths` file). This slice implements only the HEAD
concern (`META_TAG_HEAD`): `MetaWriteHead` splices out any existing
HEAD record for a name before appending the new one (same
splice-and-rewrite pattern as `Paths.HC`'s `PathClose`), so there's at
most one HEAD record per path name at any time; `MetaReadHead` scans
for it.

A real compile error was caught immediately by probe 31's stage-2
daemon on the first push: `ERROR: Duplicate member` — the same
sibling-branch-same-variable-name HolyC quirk documented since early in
this project (two different `if` blocks inside one `while` loop each
declaring their own `I64 i;`). Fixed by renaming to distinct `ci`/`ei`/
`ai` per block — a two-minute fix thanks to stage-2 actually reporting
the error, in sharp contrast to what a stage-1-only session would have
done here (silently hung, per probe 31's own finding).

## A second real bug found: an over-length path can genuinely HANG, not just no-op

The first test attempt deliberately used an oversized repo path
(`C:/Home/AVeryLongRepositoryName.hgs`, 35 characters — already over
probe 36's 33-character ceiling **on its own**, before any suffix) to
demonstrate contrast with the old per-path-sidecar scheme. This was a
real test-design mistake, and it produced a real, reproducible
**hang** — confirmed on two separate fresh boots (ruling out session
degradation), not a compile error, not a silent no-op: execution froze
partway through the very first `MetaWriteHead` call and never
returned, with `Fs->catch_except` never firing (stage-2's own
`COMPILE_OK`/`COMPILE_FAIL` report only appears once `_DRun` returns -
it never did).

This is meaningfully different from probe 36's original finding (an
over-length `FileWrite`/`FileRead` silently does nothing and returns
cleanly). The working theory, not independently isolated further here:
`FileRead` on a path that's invalid (over the length ceiling), as
opposed to a path that's merely valid-but-nonexistent, may not reliably
zero its output `size` parameter, so code that guards purely on
`buf == NULL` (already correct practice, and what `Meta.HC` does) could
still be exposed if some other code path trusted `size` without that
guard. Re-running the identical test with a realistic, valid-length
repo path (`C:/Home/FeatureRepo.hgs`, 23 characters) on a fresh boot
completed cleanly and produced the `PASS` below — strong evidence the
oversized path was the actual trigger, though the precise kernel-level
mechanism wasn't isolated further (flagged as a known, not fully
chased down, risk — see `docs/research/failed-approaches.md`).

**Practical rule going forward, beyond `PathNameFits`'s guard on new
path names (probe 37):** never construct or pass a path string that
might exceed 33 characters into `FileRead`/`FileWrite` anywhere in this
project, including in test/diagnostic code, not just real repo paths -
probe 37's guard only covers `PathNew`'s specific call site.

## What was verified (after the fix)

`test_driver.hc`, with a valid 23-character repo path:

```
repo_len=23
name_len=33
old_style_path_len=62 (would exceed the 33-char ceiling)
meta_path=C:/Home/FeatureRepo.hgs.m len=25
found_a=1 a_matches=1 found_b=1 b_matches=1
found_a2=1 a2_matches=1
found_b2=1 b2_still_matches=1
found_missing=0 (expect 0)
PASS combined_meta_file
```

- The combined file's own path is confirmed short (25 chars) and
  constant, regardless of `long_path_name`'s own 33-character length -
  the exact property ADR 0003 wants: the same path name that would
  have made the OLD scheme's `.head.<name>` file 62 characters (over
  the ceiling) fits with room to spare here.
- Two different path names' HEADs (`"main"` and a 33-character branch
  name) round-trip correctly through the **same** file.
- Updating `"main"`'s HEAD again (`MetaWriteHead` called a second time)
  correctly replaces its record - confirmed by reading back the new
  value, not the old one - proving the splice logic keeps exactly one
  HEAD record per name, not an unbounded history.
- The OTHER path's HEAD (`long_path_name`) is confirmed **completely
  unaffected** by `"main"`'s update, despite sharing one file -
  real evidence the splice-and-rewrite only ever touches the matching
  record.
- A path name never written correctly reports "not found."

## Not yet done

- Only the HEAD concern is implemented in the combined file. Path list,
  current-path pointer, and operation-log/redo-log entries all still
  live in their own separate sidecar files (`Paths.HC`, `OpLog.HC`) -
  migrating those into `Meta.HC` too is the rest of ADR 0003's decision,
  not done here.
- `Head.HC`/`Paths.HC`/`OpLog.HC`/`Offer.HC` and every dependent probe
  (30 through 39) still use today's separate-sidecar-file layout - none
  of them have been switched over to `Meta.HC` yet.

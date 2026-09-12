# Probe 15 — directory enumeration (`FilesFind`/`CDirEntry`), real TempleOS

Status: **PASS, both variants verified.** First use of TempleOS's real
filesystem enumeration API — needed for `hgit status`/`hgit witness` to
ever see what files exist to track.

## Grounding in primary source first

Before writing anything, found and read the real definitions rather than
guessing: `FilesFind(mask, flags)` (`Kernel/BlkDev/DskFind.HC` in a fresh
clone of `cia-foundation/TempleOS`) returns a `CDirEntry*` tree/list;
real call sites (`Adam/Opt/Utils/DocUtils.HC`) traverse it as
`while (tmpde) { ...tmpde->full_name...tmpde->datetime...
tmpde=tmpde->next; }` and free it with `DirTreeDel()`. This is also
where the RedSea "files cannot grow" finding (see the prior commit) came
from — same source-reading pass.

## What was tested

`FilesFind("*", 0)` over `C:/Home`, printing `full_name`+`size` for each
entry, freeing with `DirTreeDel`. Result — all 14 real files on the
disk, correctly named and sized, including the special `.`/`..` entries:

```
entry: name=C:/Home/. size=0
entry: name=C:/Home/.. size=0
entry: name=C:/Home/DoDistro.HC.Z size=1046
...
entry: name=C:/Home/test7.hgs size=391
count=14
PASS dir_enumeration
```

As a bonus, this incidentally confirmed every `.hgs` file created by
probes 01–14 survived correctly, at the right size, across roughly a
dozen separate QEMU reboots of the same persistent disk.

**Second pass**: the first version ran the loop as a bare top-level
statement (working, per the log above) — inconsistent with the
project's own standing rule about top-level loops with locals (doc 01).
Rewrote it as a real function (`WorkDirList`, now `src/hgit-cli/WorkDir.HC`)
and **re-ran it independently** rather than assuming the rewrite was
equivalent — identical result, confirmed.

## A real process mistake this session, worth recording

Immediately before the working run, two consecutive bootstrap attempts
failed with cascading `Undefined identifier`/compile errors, sourced
from `::/Doc/Comm.HC.Z` itself. Root cause, found by screendumping
instead of guessing: the screen was still sitting at TempleOS's own
`Take Tour (y or n)?` prompt both times — misread as an idle command
line — so the bootstrap keystrokes were typed into the wrong input
context and got garbled. A full VM reboot plus actually confirming the
`C:/Home>` prompt (not just "the screen looks idle") before typing
anything fixed it immediately. See `failed-approaches.md`.

## Landed as real hgit-cli source

`src/hgit-cli/WorkDir.HC` (`WorkDirList`) — the function-wrapped,
independently-verified version.

## Not yet done

- No filtering of `.`/`..` or hidden/system files — a real `status`
  needs to skip those and probably the repository's own `.hgs` file.
- No comparison against any recorded tree — this only lists "what's in
  the directory right now," not "what changed." That comparison is
  `hgit status`'s actual job, not yet built.
- `CDirEntry`'s other fields (`attr`, `datetime`) untested — only
  `full_name`/`size`/`next` have been exercised.

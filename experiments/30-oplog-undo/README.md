# Probe 30 — operation log + undo, real TempleOS

Status: **PASS after one fix (a real, pre-documented HolyC limitation).**
First M2 milestone: hgit's own tool-operation history, separate from
project history (commits), per the product thesis's explicit design.

## Preliminary question answered first

Before designing the log's append behavior, checked whether `FileWrite`
can *shrink* an existing file (needed for `undo` to truncate the log) —
only growth had been verified before (probe 14). Tested directly:
write 64 bytes, then write 8 bytes to the same path →
`size=8 first=100` — correctly shrunk, no leftover trailing bytes from
the larger write. `PASS filewrite_shrinks`.

## Design

Sidecar file per repo (`<repo_path>.oplog`), append-only list of
136-byte entries: `[U64 timestamp][64-byte prev_head][64-byte
new_head]`. `OpLogAppend` grows it (per the confirmed-safe `FileWrite`
growth pattern); `OpLogUndo` reads the *last* entry, restores HEAD to
its `prev_head`, and shrinks the file to drop that entry — using the
shrink behavior just confirmed above.

## A real HolyC gap, already documented elsewhere

First push failed: `ERROR: Missing '(' at ','` on
`I64 total_old = (old_buf==NULL) ? 0 : old_size;` — HolyC's `?:`
ternary operator doesn't work as in C. This wasn't a new discovery:
`holyc-parser`'s own bug-compatibility corpus (found earlier this
project, `experiments/templeos-devkit/holyc-parser/tests/corpus/failing/`)
already has an entry named exactly
`009-bug-compat-bug-ternary-not-supported.hc` —
`I64 bt_x=1; I64 bt_y = bt_x ? 1 : 2;` — confirming this is a known,
real limitation, not a mistake in this session's test. Fixed with a
plain `if`/`else` instead.

## What was tested, after the fix

Two offerings against a real repo, each logged, then two undos and a
third no-op check:

```
heads_differ_after_two_offers=1
undo_ok=1 found_after_undo=1 matches_head1=1
undo_ok2=1 matches_zero=1
undo_ok3=0 (expect 0)
PASS oplog_undo
```

- The two offerings produced genuinely different HEAD hashes (confirmed
  by byte comparison, not assumed).
- First `OpLogUndo` correctly restored HEAD to the *first* commit's
  actual hash.
- Second `OpLogUndo` correctly restored HEAD to the all-zero
  "no commit yet" sentinel.
- Third `OpLogUndo` correctly reported `FALSE` — nothing left to undo —
  rather than corrupting state or crashing.

## Landed as real hgit-cli source

`src/hgit-cli/OpLog.HC` (`OpLogPath`/`OpLogAppend`/`OpLogUndo`) — logic
byte-for-byte identical to the tested version (a comment addition
only).

## Not yet done

- **Not wired into `Offer.HC`** — `HgitOffer` doesn't call
  `OpLogAppend` itself yet; this probe called it manually alongside
  `HgitOffer`. Wiring it in is the natural next step, not done here.
- **No `redo`** — this is a single-level undo (pop and revert), not a
  full undo/redo stack with a movable cursor. The brief's
  `hgit operation history`/`hgit operation restore <op>` commands
  aren't built either.
- The all-zero `prev_head` sentinel for "no commit yet" is a practical
  choice, not formally proven collision-free against a real hash.
- Fixed `new_buf[16384]` cap (~120 entries) — not yet made dynamic.

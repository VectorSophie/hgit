# Probe 19 — `hgit history`, real TempleOS (repeated the probe-12 offset bug, caught it, fixed it)

Status: **PASS after one fix.** Walks the parent chain from HEAD,
printing each commit's timestamp and message. Tested against the actual
persisted repository `hgit offer` built in the previous session
(probe 18) — not a fresh fixture, a real repo read back correctly
across a QEMU reboot boundary.

## First attempt — repeated a known mistake

`HgitHistory`'s first version took `IndexLookup`'s returned offset and
indexed directly into the full file buffer (`rbuf[off+8]`). Result:
`HISTORY_ERR not_a_commit`. A diagnostic dump showed garbage (`type=19`,
an astronomically large "length") at the looked-up position.

**This is the exact same mistake probe 12 already found and
documented**: `IndexBuild`'s offsets are relative to the *object
section* it was given (`rbuf+16`), not the whole file — the 16-byte
`.HGS` header has to be added back before indexing into `rbuf` directly.
Caught immediately by re-reading `failed-approaches.md`'s own probe-12
entry while debugging, rather than re-deriving the fix from scratch.
Worth recording plainly: **having documented a mistake once didn't
prevent making it again** — the fix this time is the same one-line
addition (`I64 off = 16 + off_rel;`), now written directly into
`History.HC`'s own comments at the exact point it matters, not just in
a separate research doc, so the next reader hits the comment before
hitting the bug.

(A throwaway ad-hoc debug loop written while diagnosing this also hit
the *other* standing quirk — a bare top-level loop with local
declarations, from probe 05/12 — producing separately-garbled output.
Not fixed or kept, since it was scaffolding for this fix, not a
deliverable; noted here only so the two garbled symptoms in the
transcript aren't mistaken for two different bugs.)

## What was tested, after the fix

```
commit ts=2000 msg=second
commit ts=1000 msg=first
HISTORY_END shown=2
```

— walked from HEAD (the "second" commit) back through its parent to
the "first"/root commit, in the correct reverse-chronological order,
with the correct messages and timestamps, matching exactly what probe
18 created. Plus the empty-repo case: `HISTORY_EMPTY` for a repo with
no offerings yet.

## Landed as real hgit-cli source

`src/hgit-cli/History.HC` (`HgitHistory`) — logic byte-for-byte
identical to the tested/fixed version (comment wording only differs).

## Not yet done

- Only single-parent chains are walked (`CommitParentHash(content, 0)`)
  — merge commits (`parent_count` > 1) aren't specially handled, since
  none exist yet to test against.
- No commit hash itself is printed (only timestamp + message) — useful
  for `hgit see <offering>` to add once that command exists.
- No limit/pagination for a long history — fine at the current 2-commit
  scale, untested beyond it.

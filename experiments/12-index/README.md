# Probe 12 — hash → offset index, real TempleOS (one real crash, then PASS)

Status: **PASS on the second attempt.** Closes the last piece ADR
0001/FORMAT.md flagged as missing from the storage layer. Also produced
a genuine crash on the first attempt, root-caused and fixed rather than
routed around — worth reporting in full since it's a real, instructive
failure, not a clean success story.

## Design

`IndexBuild` scans an archive's object section once, recording each
record's *stored* hash (not recomputed — that's `ArchiveVerify`'s job)
and its start offset. `IndexLookup` linear-searches that result for a
target hash. Not a hash table yet (see "Not yet done") — but a real
capability that didn't exist before: until this probe, nothing could
answer "where is the object with this hash" at all; every prior probe
that needed an object's location tracked the offset by hand at the call
site that created it (e.g. `tree_off = alen` right after `ObjectPut`).

## Attempt 1 — crashed

The first test built the same small object graph as probes 10/11 (2
blobs + 1 tree), then tried to locate the tree object **by hand-computed
byte offset** (`16 [header] + 5+8+64 [blob1] + 5+8+64 [blob2]`) to set up
a comparison against the index. Pushed, and the guest hit a real fault:

```
Fault 0x0E General Protection
RIP:...:&TreeFindEntry+0x315F
```

**Root cause**: the hand-computed offset forgot that `ObjectPut`
prepends a 1-byte type tag before storing — so each blob record is
actually 78 bytes (8 length + 6 tagged-data + 64 hash), not the 77 the
manual arithmetic assumed. The resulting pointer into `TreeFindEntry`
was 2 bytes off, so it read a garbage `name_len` and walked far outside
the buffer. Confirmed as the actual cause: the *index's own* reported
offset for the second blob (`off2=78`) initially looked "off by one"
against my own mental math, until re-deriving it by hand showed 78 was
correct and my expectation (77) was the error — the same forgotten
type-tag byte, twice.

The daemon didn't recover after the fault (confirmed by pinging it —
no response); a full VM reboot + re-bootstrap was needed. Logged in
`docs/research/failed-approaches.md`.

## Attempt 2 — redesigned to use the index for everything, passed

Rather than fix the arithmetic and keep hand-computed offsets around,
the test was rewritten to **never compute a byte offset by hand** —
every object's location comes from `IndexLookup`, and every object's
length comes from its own stored length field (`GetU64LE` at that
offset), not a remembered variable. This is the actual point being
proven, not a workaround: an index exists specifically so callers don't
have to get this arithmetic right themselves.

Result:
```
D_OK
idx_count=3
found1=1 found2=1 found_tree=1
found_bogus=0
reloaded_tree_type=2 entry_found=1 content_matches=1
PASS index_lookup_and_dereference
D_DONE
```

Every check passed: all three real objects found by hash; a
deliberately-wrong hash correctly reported not-found; the tree object
located purely via the index, its type and content read out using its
own stored length; a tree entry resolved through `TreeFindEntry`; and
the resolved child hash looked up *again* through the index to fetch
the actual blob bytes, which matched `"hello"` exactly.

## Landed as real hgit-core source

`src/hgit-core/Index.HC` — byte-for-byte identical to the passing
attempt's `IndexBuild`/`IndexLookup` (confirmed via diff, zero
differences at all, not even whitespace).

## Not yet done

- **Still linear search**, not a real hash table — fine at hgit's
  current tiny scale, a real bottleneck once a corpus grows. The
  brief's own benchmarking plan (doc 06) should decide when this
  actually matters, rather than optimizing ahead of evidence.
- **Not persisted** — the index is rebuilt from scratch every time via
  `IndexBuild`'s full scan; no on-disk index format yet.
- Fixed-size output arrays (`idx_hashes[N*64]`, `idx_offsets[N]`) sized
  by the caller ahead of time — no dynamic growth.

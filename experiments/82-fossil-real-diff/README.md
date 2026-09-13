# Probe 82 — a real diff algorithm for Fossil.HC (single longest match)

Status: **PASS** — the first real diff algorithm for ADR 0008's Fossil
delta prototype, unblocked by probe 80's root-cause fix (before that,
building on top of an unreliable checksum would have been pointless).

## What was built

`FossilDeltaMakeReal` (`src/hgit-core/Fossil.HC`): finds the single
longest matching substring between `source` and `target` (a plain
O(source_len × target_len) double scan - this project's own
established "no premature optimization" stance, same as every linear
scan in `Index.HC`), and if it's at least `FOSSIL_MIN_COPY_LEN` (4)
bytes, encodes the delta as `[literal prefix][copy segment][literal
suffix]` instead of `FossilDeltaMakeTrivial`'s always-one-big-literal
shape. Falls back to the same all-literal encoding if no match meets
the threshold.

This is **genuinely a first real diff**, not the format's final one:
it finds exactly one copy segment (the single longest match), not a
real multi-hunk diff - a target edited in two separate, non-adjacent
places still only gets one copy segment, with the other unchanged
region staying literal. Real, useful compression for the common
single-edit-region case; honestly scoped as a real limitation for
anything more complex, not oversold.

`FossilDeltaApply`'s own copy-segment parsing (`op == '@'`) was
already written and ready during probe 68's original prototyping,
before any encoder produced real copy segments - it needed zero
changes now that one actually does.

## Verified

`test_driver.hc` (`P81RealDiffTest`):

**Positive (real compression + correctness)**: `source`/`target` are
two 105-character sentences sharing a long common region with one
small word changed in the middle ("jumps" → "LEAPS"). The resulting
delta is **41 bytes** - a real ~61% reduction versus the 105-byte
target it encodes, proving an actual copy segment got used, not just
one big literal. Applying the delta reconstructs the target exactly:
`P81_APPLY_OK=1`, and a direct byte-for-byte comparison against the
real `target` string (`P81_BYTE_MATCH=1`) - not just trusting the
checksum alone.

**Negative (no shared content)**: `source`/`target` share nothing
(all `'a'`s vs. all `'Z'`s/`'!'`s). The encoder correctly falls back
to the all-literal shape and still round-trips exactly
(`P81_NEG_APPLY_OK=1`, `P81_NEG_BYTE_MATCH=1`).

**Regression**: re-ran `experiments/65-head-deletion/test_driver.hc`
(the project's standing full command-surface regression) - unaffected
(`Fossil.HC` still isn't wired into any real command's own build).

`Fossil.HC` pushed and compiled standalone against the live daemon,
same as every prior Fossil.HC probe (it isn't in
`tools/build-package.sh`'s own concatenation).

## What this means for ADR 0008

The format now has real byte-level mechanics (probe 68), a reliable
checksum (probe 80), and a real, if minimal, diff algorithm (this
probe) - the pieces doc 04 originally asked to be prototyped are all
real and verified. `Fossil.HC` is still not wired into
`tools/build-package.sh` or any real hgit command: no real hgit command
currently stores or needs delta-compressed objects (the object store
is append-only, whole-content blobs), so wiring this in now would add
real weight for no user-visible benefit yet - a real product decision
(when/whether hgit's storage layer adopts delta compression at all),
not a reliability gap anymore.

## Not yet done

- Multi-hunk diffing (more than one copy segment) - a real, separate
  algorithm (e.g. a rolling-hash block matcher, closer to what
  Fossil's own real implementation and `rsync` use) would be needed
  for a target edited in multiple non-adjacent places to compress
  well; not attempted here.
- No real hgit command uses this yet - a genuine "should hgit's object
  store use delta compression at all, and where" product decision,
  separate from this probe's own scope.

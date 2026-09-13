# Probe 83 — `FossilSimilarityPercent`: a real similarity measure, reusing the diff engine

Status: **PASS** — a real, git-`-M`-style similarity percentage,
built directly on `FossilDeltaMakeReal`'s own longest-match scan
(probe 82) rather than a separate reimplementation, closing the gap
towards fuzzy/partial-similarity rename detection that ADR 0009
explicitly deferred ("needs a real diff/similarity algorithm this
project doesn't have").

## What was built

`FossilFindLongestMatch` (`src/hgit-core/Fossil.HC`): the same
O(source_len × target_len) longest-common-substring scan
`FossilDeltaMakeReal` already did, extracted into its own function so
both the encoder and the new similarity measure share exactly one
implementation - two independent copies of this scan would be a real
risk of the similarity score silently drifting from what the actual
encoder would produce.

`FossilSimilarityPercent(source, source_len, target, target_len)`:
returns the percentage (0-100) of `target` covered by that single
longest match. Matches git's own real "similarity index" concept (the
number a caller thresholds against, e.g. git's own default `-M50%`),
inheriting the same honest limitation `FossilDeltaMakeReal` already
has: only one contiguous match is measured, not true multi-hunk
similarity - a file edited in several separate places will score lower
here than a real multi-hunk diff tool would report.

## Verified

`test_driver.hc` (`P83SimilarityTest`), four real cases in one run:

- **Near-identical** (two 105-107-char sentences, one word changed):
  `76%` - a real, sensible high score.
- **Totally unrelated** (`"aaa..."` vs `"ZZZ...!!"`, no shared
  content): `0%` - correctly floors at zero, no false match.
- **Identical strings**: `100%` - the trivial, necessary sanity check.
- **A short file with one line appended** (`"line one\nline two\n"` →
  `"line one\nline two\nline three\n"`, 18 of 29 bytes shared):
  `62%` - matches the expected `18/29 ≈ 62%` by hand.

**Regression**: re-ran `experiments/65-head-deletion/test_driver.hc`
(the project's standing full command-surface regression) immediately
after - all still correct.

`Fossil.HC` pushed and compiled standalone against the live daemon,
same as every prior Fossil.HC probe (not in `tools/build-package.sh`).

## Not yet done

- Not wired into `Offer.HC`'s (or `Status.HC`'s) rename-detection
  fallback yet - the real next step towards ADR 0009's own deferred
  fuzzy-rename item, but a separate, real design question (what
  threshold to use, whether/how to disambiguate multiple candidates
  above threshold, and the real performance cost of scanning every
  unmatched old entry against every unmatched new file) - not decided
  or attempted in this probe.
- Multi-hunk similarity (matching real `git diff --stat`-style
  percentages more closely) needs a real multi-hunk diff algorithm,
  same as `FossilDeltaMakeReal`'s own "Not yet done" - inherited here,
  not solved.

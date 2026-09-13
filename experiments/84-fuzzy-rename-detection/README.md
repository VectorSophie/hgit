# Probe 84 — fuzzy rename detection: `Fossil.HC` wired into a real command at last

Status: **PASS** — closes ADR 0009's own explicitly-deferred item
("fuzzy/similarity-based rename detection... rejected for this slice
- needs a real diff/similarity algorithm this project doesn't have
reliably"), now that ADR 0008's reliability gap (probe 80) and
similarity measure (probe 83) both exist. This is also the **first
time `Fossil.HC` is wired into a real hgit command** - closing ADR
0008's own long-standing "not adopted" status for a real, concrete
reason.

## What was built

`Offer.HC` gains a third fallback in its per-file entity-ID chain
(name match, then exact-content-hash match, now this): when neither
exact check finds the file's identity in the parent tree,
`OfferFindFuzzyRename` scans every `OBJ_BLOB` entry in that same
parent tree, resolves each candidate's actual content (via the
`old_idx_hashes`/`old_idx_offsets` index already built for the exact-
hash path - now kept alive through the whole per-file loop instead of
freed early, since this fallback needs it too), and scores it against
the currently-offered file's content with `FossilSimilarityPercent`
(ADR 0008, probe 83). The single best-scoring candidate's entity ID is
adopted if it meets `FOSSIL_RENAME_SIMILARITY_THRESHOLD` (50, matching
git's own real default `-M50%` rather than inventing a different
number).

`tools/build-package.sh` now includes `src/hgit-core/Fossil.HC` -
the first real command dependency on it, closing ADR 0008's
"not adopted into any real command" status for the reason ADR 0008
itself named as the thing that would justify it: a real caller that
actually needs it.

Same "first/best match wins, no cross-file disambiguation"
simplification ADR 0009 already documents for its own exact-content
matching: this doesn't check whether some *other* file in the same
offering already exactly matched this same old entry - a real,
accepted limitation, not a hidden bug.

## Verified

`test_driver.hc` (`P84FuzzyRenameTest`): offers a 106-byte file of real
prose (`P84Orig.txt`), reads back its entity ID via `hgit see`
(`6c3a916dbd13cb00`). Then, in one offer: deletes `P84Orig.txt`,
writes a **new name with one word changed** (`P84Renamed.txt`, "jumps"
→ "LEAPS" in one place - NOT byte-identical, so exact-hash matching
alone would miss it), and *also* writes a genuinely unrelated new file
(`P84GenuinelyNew.txt`) in the same batch - a real opportunity for a
false-positive fuzzy match. `hgit see` on the resulting commit shows:

```
entry type=1 id=ca60efd0021f6002 name=P84GenuinelyNew.txt
entry type=1 id=6c3a916dbd13cb00 name=P84Renamed.txt
```

`P84Renamed.txt` carries the **exact same entity ID**,
`6c3a916dbd13cb00`, as the original file - fuzzy rename detection
worked, confirmed by direct string comparison of the two `SEE_TREE`
outputs, not eyeballing similar hex. `P84GenuinelyNew.txt` correctly
gets its own **different** ID, `ca60efd0021f6002` - no false-positive
match against the renamed-and-edited file despite being offered in the
same batch.

**Regression**: re-ran `experiments/65-head-deletion/test_driver.hc`
(the project's full command-surface regression) and both of ADR 0009's
own original exact-content-rename tests
(`experiments/70-rename-detection/test_driver_rename_positive.hc`/
`test_driver_negative.hc`) - all still correct, confirming exact-match
still takes priority over fuzzy matching and neither interferes with
the other.

`tools/lint-package.sh` clean before pushing (only the 3 known
built-in-manifest gaps). Package rebuilt to 187,505 bytes (a real
jump - `Fossil.HC`'s own `FossilFindLongestMatch`/`FossilChecksum`/
`FossilPutInt`/`FossilGetInt` machinery is now part of the shipped
build for the first time).

## Not yet done

- `hgit status`'s own rename surfacing (ADR 0009 addendum, probe 71)
  still only detects exact-content renames, not fuzzy ones - extending
  it the same way is a separate, real follow-up (a different code path,
  working-directory-vs-HEAD-tree rather than old-tree-vs-new-tree).
- No cross-file disambiguation within one offer (see "What was built"
  above) - if two old entries are both similar enough to one new file,
  whichever the scan reaches first wins, not necessarily the "right"
  one semantically.
- The 50% threshold is git's own real convention, not independently
  tuned against real hgit usage data - a reasonable, defensible
  starting point, not a scientifically optimized one.
- Real performance cost: this fallback does an
  O(unmatched_new_files × old_tree_entries × content_size²) scan in
  the worst case (each `FossilSimilarityPercent` call is itself
  O(source_len × target_len)) - fine at this project's own established
  "no premature optimization" scale, a real cost that would matter at
  large-repo scale, not addressed here.

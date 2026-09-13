# Probe 85 — `hgit status` surfaces fuzzy (edited) renames too

Status: **PASS** — extends probe 71's exact-content rename surfacing
in `hgit status` with a second pass reusing `Fossil.HC`'s similarity
measure, the same way `Offer.HC`'s own fuzzy rename detection does
(probe 84), closing the "real follow-up" that probe 84's own README
explicitly named.

## What was built

`Status.HC`'s NEW-on-disk candidates now buffer their real content
(`new_contents`, one 512-byte slot each - the same per-file size cap
the loop already enforces) alongside their name and hash, not just the
hash - a fuzzy check needs actual bytes to compare, not just a hash
equality test.

After the existing exact-hash rename pass, a second pass runs: for
each still-unmatched DELETED tree entry, its real content is resolved
via the index Status.HC already builds (`idx_hashes`/`idx_offsets` +
`rbuf`) - the same technique `Offer.HC`'s own `OfferFindFuzzyRename`
uses - then scored against every still-unmatched NEW-on-disk candidate
with `FossilSimilarityPercent`. The best-scoring pair at or above
`FOSSIL_RENAME_SIMILARITY_THRESHOLD` (git's own real `-M50%`, now
defined once in `Fossil.HC` itself rather than duplicated - `Offer.HC`
was updated to reference the same shared constant instead of its own
copy) gets reported as `STATUS_RENAMED <old> -> <new>`, same as the
exact-content case.

## Verified

`test_driver.hc` (`P85StatusFuzzyTest`): offers three files, then out-
of-band: renames one **with an edit** (one word changed - not byte-
identical, so only the new fuzzy pass can catch it), genuinely deletes
a second, and creates a genuinely new third - all in the *same*
`hgit status` check, so a false positive against the unrelated NEW/
DELETED files would be a real, meaningful failure:

```
STATUS_UNCHANGED P85Stays.txt
STATUS_RENAMED P85Orig.txt -> P85Renamed.txt
STATUS_NEW P85GenuinelyNew.txt
STATUS_DELETED P85WillDelete.txt
```

All four classifications correct in one run.

**Regression**: `experiments/65-head-deletion/test_driver.hc` (the
project's full command-surface test) re-run clean. Also re-verified
probe 71's own *exact*-content scenario still works after adding the
fuzzy pass, using a fresh repo (`test_driver_exact_regression.hc`,
`P85bExactRegressionTest`) rather than probe 71's own original test
driver - re-running that original driver against the same persistent
session repo it always used gave a *different-looking* but still
internally-correct result, because that repo already carries committed
state from every earlier run of it this session (no `Del()` cleanup in
that older driver) - a real state-pollution artifact of reusing one
long-lived QEMU disk across dozens of probes, not a regression. The
fresh-repo re-test confirms exact-content matching still works
identically: `STATUS_RENAMED P85BOrig.txt -> P85BRenamed.txt`, correct
`STATUS_NEW`/`STATUS_DELETED` for the unrelated files.

`tools/lint-package.sh` clean before pushing. Package rebuilt to
190,803 bytes.

## Not yet done

- Same limitations `Offer.HC`'s own fuzzy detection already documents:
  no cross-candidate disambiguation beyond "first/best match wins,"
  and a real O(unmatched-new × unmatched-deleted × content-size²) scan
  cost, fine at this project's own established scale.
- `hgit history`/`hgit reconciledoc` still don't surface any rename
  (exact or fuzzy) - unchanged from probe 71's own "Not yet done."

# Probe 70 — exact-content rename detection (ADR 0009)

Status: **PASS** — closes the gap ADR 0004 explicitly deferred: "an
actual rename is NOT detected here... a renamed file gets a new ID,
indistinguishable from delete+create."

## What was built

`Tree.HC` gains `TreeFindEntryByHash` (finds the first tree entry whose
own child hash matches a target hash, returning its entity ID - the
content-addressed counterpart to the existing by-name
`TreeFindEntry`). `Offer.HC`'s per-file loop now tries this **after**
the existing by-name lookup fails: if a currently-offered file's name
isn't in the parent tree, but its content hash *is* (under some other
name), its old entity ID is carried forward instead of generating a
fresh one - exact-content rename detection, per ADR 0009.

## Verified

**Positive case** (`test_driver_rename_positive.hc`): offered
`P70Original.txt` ("same content here"), confirmed its entity ID via
`hgit see` (`bed2cffaf4e6391c`). Then "renamed" it - wrote the
identical content to `P70Renamed.txt` and offered that instead (the
old name never reappears). `hgit see` on the new commit shows
`P70Renamed.txt` with the **exact same entity ID**,
`bed2cffaf4e6391c` - confirmed by direct string comparison of the two
`SEE_TREE` lines, not just eyeballing similar-looking hex.

**Negative case** (`test_driver_negative.hc`): offered
`P70BFileA.txt` ("content A"), then a **genuinely new** file,
`P70BFileB.txt`, with different content ("totally different content").
Its parent tree does contain an old entry under a different name
(`P70BFileA.txt`) - a real opportunity for a false-positive rename
match if the content-hash check were buggy - but since the content
genuinely differs, no hash match is found, and the new file correctly
gets a fresh entity ID (`661281709c60602e`, confirmed different from
any prior ID). This is the actually-informative negative test: it
exercises the exact code path (an old tree entry exists, by-name
lookup fails, hash lookup is attempted) without tripping a false
positive.

**Regression**: re-ran probe 65's own full command-surface regression
(`init`/`offer`/`undo`/`redo`/`path new`/`path go`/`history`/`status`/
`check`/`historydoc`/`see`) afterward - all still correct, unaffected.

`tools/lint-package.sh` was run before every push in this probe -
clean (only the three known built-in-manifest gaps).

## Not yet done

Per ADR 0009's own scope: a rename-and-edit in the same offer isn't
detected (content hash no longer matches either); multiple old entries
sharing the same content hash aren't disambiguated (first match wins);
no command's own output surfaces "this was a detected rename" to a
user yet (e.g. `hgit status` doesn't print `RENAMED old -> new`) - the
entity-ID continuity is fixed, a real UI improvement to *show* it is
separate follow-up work.

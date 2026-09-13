# Probe 92 — the adversarial `Check.HC`-vs-nested-trees test (ADR 0010's own remaining follow-up)

Status: **PASS.** Closes the one real, honestly-flagged follow-up left
after probe 91's own doc-accuracy correction: probe 91 showed the
*positive* case (a real nested tree, nothing wrong, `CHECK_OK`/
`CHECK_REFS_OK`/`CHECK_DANGLING_NONE`); this probe deliberately breaks
something *inside* a nested tree and confirms `hgit check` actually
detects it there, not just at the top level.

## What was built

`test_driver.hc` (`P92CheckNestedCorruptionTest`): builds the same
kind of real nested repo probe 91 did (`hgit offertree` over a
directory with a top-level file and a subdirectory `SubA` holding
`inner.txt`), confirms `hgit check` is clean beforehand, then
corrupts one byte of `SubA`'s own tree record - specifically, one byte
of the `child_hash` field of its `inner.txt` entry - directly in the
archive buffer, via a real linear scan (the same record-walking
convention `Check.HC`'s own referential-integrity pass uses to find
the target record in the first place).

**Deliberately not re-hashed.** `Index.HC`'s own header comment notes
`IndexBuild` keys off a record's *stored* hash, not a recomputed one -
so leaving `SubA`'s own stored hash untouched means every OTHER real
reference to `SubA` (the top-level tree's own entry) still resolves
exactly as before the corruption. This isolates exactly one real
failure (this one entry's own outgoing reference no longer resolves)
instead of cascading into an unrelated rewrite of the whole parent
chain up to the commit. The one honest, expected side effect: `SubA`'s
own record now hash-mismatches (`ArchiveVerify`'s separate hash-
integrity check) - not something this test tries to avoid or hide.

## Verified (real QEMU run, not fabricated)

Before corruption:
```
CHECK_OK objects=5
CHECK_REFS_OK
CHECK_DANGLING_NONE
```

After flipping one byte of `inner.txt`'s `child_hash` inside `SubA`'s
own tree record:
```
CHECK_FAIL objects=5 ok=4 corrupt=1
CHECK_BROKEN_REF tree_child_missing 812de1d8...61d81a9
CHECK_REFS_FAIL broken=1
CHECK_DANGLING blob 7e2de1d8...61d81a9
CHECK_DANGLING_COUNT 1
```

Three real, independent confirmations, all firing from a corruption
that exists only inside a nested tree's own content:

1. **`CHECK_FAIL objects=5 ok=4 corrupt=1`** - the expected,
   unavoidable side effect of not re-hashing `SubA`'s own record;
   `ArchiveVerify`'s hash-integrity pass (blind to structure, doesn't
   care about nesting) still correctly flags it.
2. **`CHECK_BROKEN_REF tree_child_missing 812de1d8...`** - the
   referential-integrity pass's flat scan over every archive record
   (not a walk that starts at a commit's tree and stops one level
   down) found and reported the broken reference *from inside* `SubA`'s
   own content, exactly where it was planted. Note the hash differs
   from the real `inner.txt` blob's own hash (`CHECK_DANGLING` below)
   only in its first byte (`81` vs `7e` - a byte-for-byte `XOR 0xFF`
   of the single flipped byte, confirming the corruption landed
   exactly where intended and nowhere else).
3. **`CHECK_DANGLING blob 7e2de1d8...` / `CHECK_DANGLING_COUNT 1`** -
   the recursive reachability walk (`CheckMarkReachable`) correctly
   determined `inner.txt`'s real blob is now unreachable, precisely
   because its only real reference (inside `SubA`'s own content) no
   longer resolves - proving the recursion actually depends on and
   inspects nested tree content to make this determination, not just a
   shallow top-level check.

This closes ADR 0010's last remaining open item about `Check.HC`
("the adversarial case ... hasn't been run yet") with a real,
verified, negative-case result to match probe 91's positive one.

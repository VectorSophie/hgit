# Probe 125 - hardening (v1.8.7)
Real QEMU: (1) merge state pointing at a nonexistent conflict object -> `check` prints
`CHECK_BROKEN_REF conflict_object_missing`, `CHECK_REFS_FAIL`; `merge abort` recovers, check clean.
(2) a malformed OBJ_CONFLICT (5 junk bytes) in the archive -> `check` reports
`conflict_object_malformed`/`conflict_malformed`; `conflicts`/`conflictdoc` do not crash,
`resolve` refuses with a clear error, `merge abort` recovers. (3) format_version 9 file ->
`check`/`status` print `unsupported_format_version=9`. (4) cross-directory move (A/f.txt ->
B/f.txt) vs edit -> a persisted, resolvable conflict at A/f.txt (nothing silently lost;
no move detection since offer's rename detection is per-directory).
Stable cases added to tests/full-regression.hc (conflict lifecycle with rename, abort +
conflictdoc, missing-dependency check, newer-format rejection); full suite ran to TFULL_END.

# Probe 124 - conflictdoc + MERGE_AUTO (v1.8.6)
Real QEMU: text conflict (t.txt), binary conflict (bin.dat), auto-merged file (ok.txt).
Merge printed `MERGE_AUTO took-theirs ok.txt` + two `MERGE_CONFLICT`s. `conflictdoc` wrote a
DolDoc with a `$TR$` node per conflict: text side lines, `(binary, 5 bytes)` sides, a
`resolved to: ours` marker, and the un-chosen suggestion `hgit resolve <repo> N take-ours | take-theirs`.
Found+fixed: `resolve` used to move the resolved record to the end (indices shifted);
Meta.HC now rewrites it in place - verified indices stay stable.
Not done: `$LK$` links to stored objects (objects are inside the archive, not files);
only a link to the repo file itself.

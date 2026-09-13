# Git internals (partial — object model, plus merge-base/three-way merge)

## Verified documentation

Source: `git-scm.com/book/en/v2/Git-Internals-Git-Objects`.

Git is content-addressed: every object is `SHA-1(header + content)` where
`header = "<type> <size>\0"`. Three object kinds:

- **blob** — raw file bytes, no name/mode attached.
- **tree** — entries of `<mode> <type> <sha1> <filename>`, one per child;
  a directory's identity is exactly the hash of its serialized entry list.
- **commit** — `tree <sha1>` + zero or more `parent <sha1>` lines +
  author/committer (name, email, timestamp, timezone) + blank line +
  message. Parents form the DAG.

Objects are zlib-compressed and stored at
`.git/objects/<first 2 hex chars>/<remaining 38 hex chars>`.

## Ideas worth borrowing (per the product thesis's own framing)

- Content addressing + strict separation of blob/tree/commit is exactly
  the "proven snapshot model" the thesis says to start from. Nothing in
  this pass contradicts adopting it as hgit's base layer, with the
  identity/fingerprint fields (`stable entity ID`, `structural
  fingerprint`) layered on top rather than replacing it.
- The 2-char/38-char directory sharding is a filesystem-scaling trick
  that's irrelevant at TempleOS's stated ~100MB-repo scale — worth noting
  as a Git complication that does **not** need to be ported (ties to the
  brief's instruction to identify Git's "accumulated compatibility debt"
  vs. genuinely essential mechanisms).

## Verified documentation — merge-base / three-way merge

Source: `git-scm.com/book/en/v2/Git-Tools-Advanced-Merging`. Git
tracks three versions of a file during a merge (accessible via the
index's own numbered stages): stage 1 is the merge base (common
ancestor), stage 2 is "ours" (current branch), stage 3 is "theirs"
(the branch being merged in). The three-way merge compares all three:
a line unchanged from the base on both sides is untouched; a line
changed on only one side is taken as-is; a line changed differently on
*both* sides is a real conflict - Git "does not try to be clever" about
resolving that case, it inserts literal `<<<<<<<`/`=======`/`>>>>>>>`
conflict markers (optionally including the base version too, via
`--conflict=diff3`) and leaves resolution to the user.

**Real prerequisite check, before designing an actual merge command**
(`experiments/97-multiparent-commits/`, PASS): does hgit's own object
model already support a real multi-parent (merge) commit, given no
real command has ever created one? Checked directly rather than
assumed - `Commit.HC`'s own `CommitEncode`/`CommitParentHash` were
never hardcoded to one parent (a generic `parent_count`/concatenated
`parent_hashes` array from the start), and `Check.HC`'s own
`CheckMarkReachable` and referential-integrity pass already loop over
every real parent, not just the first. A manually-constructed, real
2-parent commit (injected directly into a real archive, the same
technique probe 92 used) round-tripped correctly end to end:
`SEE_COMMIT ... parents=2`, `CHECK_REFS_OK`, `CHECK_DANGLING_NONE` (the
reachability walk followed BOTH parents, not just one) - all with
**zero code changes**. `History.HC`/`HistoryDoc.HC` are already
honestly documented as following only `CommitParentHash(content, 0)` -
a real, existing, known limitation for a linear-history view, not a
new finding.

**Real, separate work still needed, not attempted**: an actual merge
ALGORITHM - finding a real merge base (the lowest common ancestor in
the commit DAG, non-trivial once criss-cross histories exist) and a
real three-way tree-level merge (reusing `Diff.HC`'s own recursive
tree-walking pattern, extended to three trees with a real conflict
representation this project doesn't have yet). Both real, well-scoped,
substantial follow-up work for a future session - the prerequisite
question this pass answers is only "can the object model represent the
*result*," not "how is the result computed."

## Not yet done

Packfile format & delta-base selection, index format, commit-graph,
protocol v2/partial clone - lower priority, TempleOS's own stated scale
and single-machine-first design make these Git-scaling concerns less
urgent than they were at the top of this list. Several items originally
listed here are now real, resolved parts of hgit itself, not just
research: refs/reflog (`Paths.HC`'s named paths + `OpLog.HC`'s own
operation log), `git fsck`/recovery (`hgit check`'s referential-
integrity and dangling-object passes), rename inference (ADR 0009,
exact-hash and Fossil-based fuzzy matching). Merge-base/three-way merge
is now real, *ongoing* work (see above) rather than untouched. The
plumbing/porcelain split doesn't apply to hgit's own single-command
(`Hgit(cmdline)`) CLI shape - a real, deliberate architectural
difference from Git, not a gap.

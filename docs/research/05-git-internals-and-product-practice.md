# Git internals (partial — object model only)

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

## Not yet done

This is the smallest possible first slice. Still open, per the brief's own
list: packfile format & delta-base selection, index format, commit-graph,
refs/reflog, `git fsck`/recovery, merge-base/three-way merge, rename
inference, plumbing/porcelain split, protocol v2/partial clone. These are
needed before doc 04 (VCS comparison) or ADR 0001 (repository model) can
honestly claim evidence-based conclusions — right now the thesis's
Git-derived design (blob/tree/commit + typed relations) is *plausible*,
not yet *verified against Git's actual failure modes and workarounds*.

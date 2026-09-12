# Probe 16 — `hgit status` (zero-offering case), real TempleOS

Status: **PASS, both test cases, first try.**

## Scope, chosen deliberately

hgit has no ref/HEAD concept yet — no way to name "the current
offering" a repository is at. So "what changed since the last offering"
isn't a well-defined question in general yet; answering it would mean
inventing behavior rather than implementing something known-correct.
What *is* well-defined without that machinery: a repository with zero
objects has no prior offering to compare against, by definition, so
every file in the working directory is untracked. `HgitStatus`
implements exactly that case, and reports an honest
`STATUS_UNIMPLEMENTED` for the general case rather than guessing.

## What was tested

1. `HgitStatus` on a path with no file at all →
   `STATUS_ERR not_a_repository ...` (reuses `HgsReadHeader`'s own
   `FileRead`-returns-`NULL` handling, same pattern as `HgitInit`).
2. `HgitInit` a fresh repo, then `HgitStatus` on it → `STATUS_NO_OFFERINGS_YET`
   followed by the full working-directory listing (via `WorkDir.HC`'s
   `WorkDirList`, from probe 15) — every real file on the disk, correctly
   named and sized, shown as untracked.

Both passed, first push, no retries needed — this session's earlier
tour-prompt mistake (probe 15) was caught *before* typing this time by
actually reading the screendump's literal text (`Take Tour(y or n)? NO`)
rather than judging it "looks idle."

## Landed as real hgit-core... hgit-cli source

`src/hgit-cli/Status.HC` (`HgitStatus`) — byte-for-byte identical to the
tested version (confirmed via diff, zero differences).

## Not yet done

- **The actual point of `status`** — comparing against a prior
  offering — needs a ref/HEAD concept that doesn't exist yet. That's
  the next real design step, not a small addition: it's the first place
  hgit needs to track "current state" as something other than "whatever
  the working directory happens to contain."
- No filtering of hgit's own repo file from the untracked listing (a
  repo would currently report itself as untracked, which is wrong).
- No distinction yet between "new," "modified," and "deleted" — only
  "everything, because nothing is tracked" is implemented.

# Probe 111 — `hgit diff` against a real merge commit: verified sane, comment corrected

Status: **PASS**. Follows probe 110's own pattern (checking commands
that predate ADR 0011 against a real merge commit) - `Diff.HC`'s own
header comment never mentioned merge commits at all ("show what
changed in one commit relative to its own parent's tree", singular,
written before multi-parent commits existed).

## What was checked

Built a real small merge history (root commit, a `feature` path
forking and adding its own file, `main` independently adding a file,
then a real `hgit merge` producing a real 2-parent commit) and ran
`hgit diff` against the merge commit itself.

**Real, coherent result, not a crash or a wrong answer**:
`DIFF_NEW P111Feat.txt` - `Diff.HC` diffs against the FIRST parent
only (`ours` at merge time), the same pre-existing single-parent
behavior this file always had, unchanged and unmodified for merge
commits. Since `feature`'s own file only entered the tree via the
merge's SECOND parent, it correctly shows as new relative to the
first parent's own tree - not a special case added here, just
`Diff.HC`'s own existing logic applied to a commit type it happened
to have never been tested against before. Matches the same convention
`git show`/`git log -p` use by default for a merge commit (diff
against the first parent) - not a novel design choice.

## What was fixed

`Diff.HC`'s own header comment updated to state this plainly and cite
this probe's real verification, rather than leaving merge commits
unmentioned entirely (silence that could otherwise read as "never
checked" rather than "checked and it's fine"). Comment-only change,
rebuilt/linted/pushed to the live daemon (`COMPILE_OK`), regression
re-run clean.

## What this does not do

- Does not change `hgit diff`'s actual behavior for merge commits -
  diffing against the first parent only remains real, deliberate,
  unmodified behavior, matching common VCS convention, not something
  this probe argues should change.
- Does not add a "combined diff" (showing what BOTH parents
  contributed, `git diff --cc`'s own real feature) - a real, separate,
  bigger feature, not scoped here, no evidence of need.

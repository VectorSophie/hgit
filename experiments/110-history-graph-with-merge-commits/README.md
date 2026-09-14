# Probe 110 — `hgit history`/`hgit graph`: real verification against an actual merge commit

Status: **PASS**. Both `History.HC` and `Graph.HC` had header comments
predating real merge commits: `History.HC` said "merge commits...
aren't walked specially yet, since none have been created or tested";
`Graph.HC` said "no multi-parent commits exist yet". Both went stale
once ADR 0011 (probes 97-100) made merge commits real - never
corrected, and never actually re-verified against one, until now.

## What was checked

Built a real, small merge history (root commit, a `feature` path
forking and adding its own file, `main` independently adding a file,
then a real `hgit merge` producing a real 2-parent commit) and ran
both `hgit history` and `hgit graph` against it.

**Neither command crashes or corrupts anything.** Both already do the
same real, honest thing they did before merge commits existed: only
follow a commit's FIRST parent when walking backward.

- `hgit history` shows 3 commits (`root_commit`, `main_commit_2`,
  `merge feature`) - `feature`'s own unique commit (`feature_commit`,
  only reachable via the merge's SECOND parent) is honestly absent
  from this view. A real, deliberate simplification for a plain
  sequential log (the same thing `git log --first-parent` names), not
  a crash or a silently wrong answer.
- `hgit graph` correctly finds `feature`'s own fork point (walking
  backward from its HEAD until hitting `root_commit`, already in
  main's chain) and nests `feature_commit` under its own `[feature]`
  branch group - real output, byte-for-byte in
  `serial-log-evidence.txt`. The merge commit itself still renders as
  one plain line on main's own trunk, not as a visually connected DAG
  rejoin between the two branch groups - `Graph.HC`'s own header
  comment already documented this as a real, honest simplification,
  just with a stale reason ("no multi-parent commits exist yet")
  instead of the real one (first-parent-only walking, unchanged by
  merge commits existing).

## What was fixed

Both files' own header comments corrected to state plainly that
multi-parent commits are real (ADR 0011) and describe their own
actual, continuing first-parent-only behavior accurately, backed by
this probe's real verification - not assumed, not left stale.
Comment-only changes, still rebuilt/linted/pushed to the live daemon
(`COMPILE_OK`) and regression-tested per this project's own standing
discipline.

## What this does not do

- Does not change either command's actual behavior - first-parent-only
  walking remains a real, deliberate design choice for both, not
  something this probe argues should change without real evidence of
  need.
- Does not attempt a full DAG-aware rendering of merge commits in
  `hgit graph` (drawing a real rejoin between two branch groups) - a
  real, separate, substantially bigger feature, not scoped here.

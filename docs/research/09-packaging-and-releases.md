# Packaging and releases

## Verified documentation

TempleOS has no package manager, no dependency resolution, and no
argv-based executable convention (confirmed from primary source,
`Doc/CmdLineOverview.DD`, already established in doc 01) — a "program"
is run by `#include`-ing its source file at the live command line:
`#include "C:/Home/Whatever.HC";`. There is nothing to "install" in
the sense a Linux/Windows/macOS user would recognize: no binary
format, no linker step visible to the user, no registry. A release
artifact for a TempleOS program is, structurally, just a `.HC` (or
`.HC.Z`, compressed) source file a user copies onto their own disk and
`#include`s.

## What hgit already has, verified

- `tools/build-package.sh` concatenates every `src/hgit-core/` and
  `src/hgit-cli/` file, in dependency order, into one self-contained
  file, `packaging/HgitAll.HC`.
- This is not a proposal — it's already been verified loadable on real
  TempleOS with a single `#include`, followed by a working `Hgit(...)`
  call, in a session that never pushed any individual source file
  directly (`experiments/28-hgit-package/`).
- Every real command (`init`/`offer`/`status`/`history`/`see`/
  `undo`/`redo`/`path *`/`operation *`/`export`/`import`/`historydoc`/
  `correct`/`revert`/`reconcile`) is included in this one file and has
  been independently verified against real TempleOS at some point in
  this project's history (see each command's own `experiments/`
  probe).

So the actual packaging mechanism this doc was "not started" pending
is, in fact, done and has been for a long time (`experiments/28-hgit-package/`,
well before this doc was updated to say so) — this doc's own "not
started" status was stale, same class of drift the risk register in
doc 10 just had corrected.

## What a real release means here

Given TempleOS's own convention (copy a `.HC` file, `#include` it),
the release artifact is `packaging/HgitAll.HC` itself, versioned by a
git tag. A GitHub Release attaching that file, with release notes
describing what's verified and what isn't, is the natural "release" —
not a compiled binary, not an installer, because none of those concepts
apply here.

## Ideas worth borrowing / open questions

- Whether to ship the file compressed (`.HC.Z`, matching TempleOS's own
  on-disk convention for its stock `Doc/*.DD.Z` files) or plain text —
  not yet decided; plain text is simpler to inspect before running,
  compressed matches native convention more closely. Shipping plain
  text for now (simpler, and GitHub's own release UI doesn't need a
  TempleOS-native format to be useful).
- No version string is embedded in the packaged file itself yet — a
  real release should probably print its own version via a real
  command (e.g. `Hgit("version");`) so a user can confirm what they
  loaded. Not built yet — real follow-up work.
- No install script/instructions doc exists yet beyond this file and
  the top-level README's own description of `tools/build-package.sh`.

## Architectural implications so far

- No packaging redesign needed - the existing single-file concatenation
  approach already matches TempleOS's own `#include`-a-file convention
  natively; this was already the right design, just under-documented
  as "not started" here.

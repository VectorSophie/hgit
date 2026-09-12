# ADR 0003 — The 33-character path ceiling: a single combined metadata file, not one sidecar file per concern

## Status

Decided, **not yet implemented**. This ADR records the decision and its
reasoning; migrating `Head.HC`/`Paths.HC`/`OpLog.HC` off the current
one-sidecar-file-per-concern-per-path design is real future work, not
done in this ADR or the probes that motivated it.

## Context

Probe 36 (`experiments/36-path-scoped-oplog/`) found, while debugging a
genuine test failure, a real and previously-undocumented TempleOS/
RedSea constraint: **a full path string longer than 33 characters is
silently rejected by `FileWrite`/`FileRead`** — no exception, no error
code, the call simply does nothing, and a later read finds nothing.
Pinned exactly by binary search (32 works, 33 works, 34 fails,
reproduced consistently) — see `docs/research/01-templeos-holyc.md`'s
"Path length limit" section for the full evidence.

This directly threatens every sidecar-file-per-concern design hgit has
built so far:

- `Head.HC`: `<repo_path>.head` (main), `<repo_path>.head.<name>` (other
  paths)
- `Paths.HC`: `<repo_path>.paths`, `<repo_path>.currentpath`
- `OpLog.HC`: `<repo_path>.oplog`/`.ol.<name>`,
  `<repo_path>.redolog`/`.rl.<name>`

Every one of these is `<repo_path>` plus a fixed tag plus, for
per-path files, the path's own name. Probe 37 added a proactive guard
(`PathNameFits`) that refuses a `path new` call whose own sidecar would
cross the ceiling — a real, useful mitigation, but only a guard on the
symptom nearest the user. It does nothing for:

- A repo whose **own path** is already long enough that even `main`'s
  bare `<repo_path>.oplog` (no per-path suffix at all) is at risk.
- The ceiling getting *tighter* every time this project adds one more
  concern that needs its own per-path sidecar file (the more kinds of
  per-path state hgit tracks, the less name-length budget remains for
  the same 33-character total).

This is a real design constraint, not a one-off bug to patch around
file by file.

## Alternatives considered

- **Keep guarding each new sidecar type individually** (as probe 37
  did for `Paths.HC`): rejected as the long-term answer. It treats each
  symptom as it's found rather than removing the shared root cause, and
  the "safe name budget" shrinks every time a new per-path concern is
  added — a design that gets more fragile as hgit grows features, which
  is backwards.
- **Hash-derived short suffixes instead of literal path names** (e.g. an
  8-hex-char ID per path name, stored in a small lookup table): would
  work, and bounds suffix length regardless of how long a user's chosen
  path name is — but doesn't help `main`'s own already-long-`repo_path`
  case at all (the base filename length is the same problem either
  way), and adds a real layer of indirection (name → ID → file) for
  comparatively little gain over the option below.
- **Subdirectories** (shortening the *visible* path by nesting): not
  pursued — TempleOS/RedSea subdirectory support hasn't been verified
  from source for this project's purposes, and even if it worked, the
  33-character ceiling appears to apply to the **full path string**
  (confirmed: `C:/Home/` prefix included in every measurement), not just
  a filename component, so nesting doesn't obviously buy back budget
  without further, separate verification.

## Decision

Consolidate every per-repo *tool* metadata concern (HEAD for every
path, the operation log and redo log for every path, the path list,
the current-path pointer) into **one combined metadata file per
repository**, at a single short, fixed-length suffix off `repo_path`
(e.g. `<repo_path>.m`) — never growing with how many paths exist or how
long their names are, because path names live **inside** the file's
own binary structure (as data) rather than **in filenames** (as
identity). This is the same shape hgit already uses for the *object*
layer (`Archive.HC`/`Hgs.HC`: one file, many typed, addressed records)
— applying the same idea to tool-state metadata that this project
arrived at independently for objects, for the same underlying reason
(RedSea rewards "one file, many records" over "many small files").

This does **not** remove the ceiling itself (still a real TempleOS/
RedSea constraint on `repo_path` + `.m`, i.e. on the repo's own chosen
path length) — but it removes the part of the problem this project's
own design was making *worse*: the number of sidecar files, and their
growing per-path suffixes, no longer scale with feature count or path
names at all. A `repo_path` chosen short enough for `<repo_path>.m` to
fit comfortably is the only remaining constraint, not
`<repo_path>.oplog.somewhatlongbranchname`.

## Costs

- A real migration: `Head.HC`, `Paths.HC`, and `OpLog.HC`'s on-disk
  layout all change. Every already-verified probe (30 through 39) that
  hardcodes today's separate-sidecar-file paths would need to be
  re-verified against the new combined format, not assumed to still
  pass.
- The combined file's internal format needs its own design (a small
  record-per-concern-per-path shape, presumably similar to `OpLog.HC`'s
  existing fixed/variable-length entry patterns) — not designed in this
  ADR, real work for whichever probe implements this decision.
- Backward compatibility for repos already created under the current
  scheme is an open question, not decided here (this project has no
  released users yet, so a clean cutover is plausibly fine, but that's
  a judgment call for the implementing probe, not asserted here).

## What would justify revisiting this

- If TempleOS/RedSea's real subdirectory support is independently
  verified from primary source and confirmed to change what portion of
  a path counts against the 33-character ceiling, nesting might become
  a simpler answer than a combined-file migration.
- If the combined file's own internal format turns out to have scaling
  problems (e.g. many paths with long histories bloating one file badly
  enough to matter at hgit's target scale) — no evidence of this either
  way yet, per ADR 0001's same "no premature optimization" stance.

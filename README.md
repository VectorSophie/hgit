# hgit

A lightweight, modular, self-contained version-control system, written in
HolyC, native to TempleOS — with persistent file/symbol identity,
executable DolDoc reconciliation, truthful non-destructive history, and a
consistent modern CLI.

**Status: M0 complete (7/7 acceptance items); M1 complete, including
command-surface polish.** See `docs/research/10-product-proposal.md`.
The full object storage layer — canonical encoding, BLAKE2b-512
(single-block and streaming), typed objects (blob/tree/commit), a
hash→offset index — is built and verified running natively on real
TempleOS under QEMU, not simulated. All five M1 commands
(`init`/`status`/`offer`/`history`/`see`) exist, are independently
verified, and are composed behind a real entry point: one dispatcher
function, `Hgit(cmdline)`, called exactly the way TempleOS's own native
commands are (`Hgit("init \"C:/Home/My Repo.hgs\"");` — quoted
arguments with spaces work) — there is no argv/shell syntax in TempleOS
to build a traditional CLI around, confirmed from primary source, so
this is the idiomatic shape, not a workaround. The whole toolchain
packages into one file, loadable with a single `#include`.

## What's here

- `docs/research/` — the research dossier, with an honest per-doc status
  in [`00-research-index.md`](docs/research/00-research-index.md). Most
  docs are partial or stubs; see that index before assuming coverage.
- `experiments/` — one directory per probe, each with its own `README.md`
  (what was tried, the exact result, what's not yet done) and, where
  relevant, the exact HolyC source that was pushed and verified.
  `experiments/00-qemu-boot/` proves TempleOS 5.03 boots to a live
  desktop under QEMU on a plain Linux host; `experiments/01-temple-repl/`
  is the reusable install + scripted source-injection channel every
  later probe runs through.
- `FORMAT.md` — the `.HGS` repository/archive format, documented
  byte-for-byte, matched to what's actually implemented.
- `docs/adr/` — 0001 (repository model) and 0002 (canonical encoding),
  each backed by working, tested `src/` code, updated as that code grew;
  0003 (the real 33-character path-length ceiling found in probe 36 —
  decided and now fully implemented: one combined per-repo metadata
  file instead of one sidecar file per concern. Every real command
  (`Paths.HC`, `OpLog.HC`) now genuinely runs on
  `src/hgit-core/Meta.HC` — a path name the old scheme would have
  rejected now succeeds). No ADR should be written before its own
  evidence exists — 0003 is backed by probes 36/37/40/41/42/43/44's
  real, binary-searched/QEMU-verified measurements.
- `src/hgit-core/` — the object storage layer: `Canon.HC` (canonical
  little-endian encoding), `Blake2b.HC` (BLAKE2b-512, single-block +
  streaming, matches RFC 7693), `Archive.HC`/`Hgs.HC` (the `.HGS` record
  format and file header), `Object.HC`/`Tree.HC`/`Commit.HC` (typed
  objects: blob/tree/commit content), `Index.HC` (hash→offset lookup),
  `Meta.HC` (ADR 0003's combined per-repo metadata file — HEAD, path
  list/current-path, and operation-log storage in one file, immune to
  the real 33-char path-length ceiling; `Paths.HC` now runs on it).
- `src/hgit-cli/` — the command surface: `Init.HC`, `Check.HC`
  (`hgit check` — repo integrity verification, a thin wrapper over
  M0's own `Archive.HC` `ArchiveVerify`), `WorkDir.HC`,
  `Paths.HC` (named paths, backed by
  `Meta.HC`), `Offer.HC`, `Status.HC`, `History.HC`, `See.HC`, `Hex.HC`
  (hex string ↔ hash bytes), `HistoryDoc.HC` (`hgit historydoc` — a
  real, colored, rendered DolDoc history view), `ReconcileDoc.HC`
  (`hgit reconciledoc` — a real DolDoc reconciliation view with a live
  `$LK$` link to a commit's relation target), `OpLog.HC` (operation
  log + undo/redo stack, wired into `Offer.HC`, now backed by
  `Meta.HC`), `Portable.HC` (`hgit export`/`import` — whole-repo copy,
  both files), and `Hgit.HC` — the real entry point (`Hgit(cmdline)`)
  composing all of the above behind one dispatcher.
  Every file in both directories verified running on real TempleOS via
  `experiments/01-temple-repl/`'s injection channel — see each probe's
  README for exact evidence, and each source file's own comments for
  which probe verified it.
- `tools/build-package.sh` — concatenates every `src/hgit-core/` and
  `src/hgit-cli/` file, in dependency order, into `packaging/HgitAll.HC`
  — the actual distributable: verified loadable on real TempleOS with a
  single `#include "C:/Home/HgitAll.HC";`, followed by a working
  `Hgit(...)` call, in a session that never pushed any individual
  source file directly (`experiments/28-hgit-package/`).
- `tests/` — still scaffolded/empty.

**M2 in progress**: the operation log (`src/hgit-cli/OpLog.HC`) is
built, path-scoped, and wired into `hgit offer` itself; real
`hgit undo`/`hgit redo`/`hgit operation history` commands all exist (a
proper undo/redo stack, not just single-level) and are now genuinely
path-aware; named paths (`hgit path list/new/go/close`,
`src/hgit-cli/Paths.HC`) are wired into `offer`/`status`/`history`/
`undo`/`redo` — switching the current path changes what all of those
commands see — all verified end-to-end through the real `Hgit(cmdline)`
entry point on TempleOS (`experiments/30-oplog-undo/`,
`experiments/31-oplog-in-offer/`, `experiments/32-oplog-redo/`,
`experiments/33-operation-history/`, `experiments/34-hgit-paths/`,
`experiments/35-path-aware-offer/`, `experiments/36-path-scoped-oplog/`).

Along the way, a genuine, previously-undocumented TempleOS/RedSea
constraint was found: **a full path string longer than 33 characters
is silently rejected by `FileWrite`/`FileRead`** — a real risk for
every sidecar-file design this project uses. `hgit path new` now
proactively refuses a name that would cross this ceiling instead of
silently leaving behind an unreadable path (`experiments/37-path-length-guard/`),
though the underlying architectural constraint isn't resolved. See
`docs/research/01-templeos-holyc.md`.

`hgit operation restore <op>` (jump HEAD directly to any logged
operation by index) is also done, closing out the brief's full
operation-log vocabulary (`undo`/`redo`/`operation history`/
`operation restore <op>`). ADR 0003 (the real 33-char path-length
ceiling) is fully implemented — every real command now runs on
`src/hgit-core/Meta.HC`'s combined metadata file — and `hgit export`/
`import` give genuine whole-repo portability (own paths, own history,
own working `undo` on the copy), a direct payoff of that design.

**A real, rendered DolDoc history view now exists**: `hgit historydoc
<repo> <dest.DD>` (`src/hgit-cli/HistoryDoc.HC`) builds a colored
`$..$`-formatted document from real commit history and writes it with
a plain `FileWrite` — verified both by its raw file content and its
actual rendered appearance (screenshotted via TempleOS's own `Ed()`).
This closes out M2's tracked work list.

**M3 has started and its first slice is implemented**: every tree
entry now carries a stable 64-bit entity ID (`docs/adr/0004-stable-entity-identity.md`),
grounded in real evidence that TempleOS's `RandU32` is a genuine,
usable random source. `Offer.HC` carries a file's ID forward across
offers as long as its name persists; verified the same name keeps its
ID through content changes and across multiple generations, while a
new name gets a distinct one (`experiments/49-entity-id/`, PASS). This
is a real, breaking change to the tree object format — no rename
detection or relation vocabulary yet, both explicitly out of scope for
this first slice.

The typed relation vocabulary is fully wired in and independently
verified: real `hgit correct`/`hgit revert`/`hgit reconcile` commands
each produce commits carrying the right CONTINUES/CORRECTS/REVERTS/
RECONCILES tag and an exactly-matching target hash, each pushed
through the real dispatcher on its own — `hgit see` shows a commit's
relation too. Both M3 features (stable identity and relations)
confirmed working together in one real commit.

Relations can now also be scoped to a specific tracked entity, not just
a whole commit (`docs/adr/0006-entity-scoped-relations.md`), verified
with a real entity ID read from an actual tree. Entity IDs are now
shown/entered as hex, not decimal — a `U64` with its high bit set used
to print as a negative number, a real issue found and fixed. Both of
M3's headline features (stable identity, typed relations) are now
complete and verified on real TempleOS.

**M4 is underway**: `experiments/54-doldoc-widgets/` confirmed a real
`$LK$` link widget renders correctly (underlined, clickable) from
HolyC-generated `.DD` output. `hgit reconciledoc <repo> <commit_hex>
<dest.DD>` (`src/hgit-cli/ReconcileDoc.HC`, `experiments/55-reconciledoc/`)
now puts that to use for real: given a commit with an ADR 0005/0006
relation, it builds a document showing the commit, a real `$LK$` link
to its relation target (tagged with the target's full hash), the
target's own message, and any entity scope — verified through the real
dispatcher, by raw-byte content, and by rendered appearance in `Ed()`.
`$TR$` (tree widget) syntax is also resolved now
(`experiments/57-tree-widget/`), from real shipped TempleOS demo source
(`C:/Demo/DolDoc/TreeDemo.HC`): a single self-contained `$TR,"label"$`
command (no closing tag) plus `$ID,+2$`/`$ID,-2$` for nesting —
verified rendering a real `[+]` collapse marker. `ReconcileDoc.HC` now
uses this for real (`experiments/58-reconciledoc-tree/`): a commit's
relation renders as a real collapsible `[+] relation: <TYPE>` node with
the link/target-message/entity-scope nested inside. Found a real
gotcha while verifying it — redefining a function doesn't retroactively
fix up an already-compiled caller's call site in this long-running
daemon; the caller (here, `Hgit.HC`) must be re-pushed too, even with
no source changes, or the change silently doesn't take effect despite
a clean compile. **A real multi-commit view now exists too**:
`hgit reconcileoverview <repo> <dest.DD>`
(`experiments/59-reconcile-overview/`) walks a repo's whole history and
shows a real tree node for every commit that carries a relation,
skipping ordinary offers entirely — verified with a real four-commit
repo where exactly the one relevant commit appears in the output.
`$LS$` (the list widget) is also resolved now
(`experiments/63-list-widget/`), closing doc 02's last tracked DolDoc
widget question — a real form-input widget bound via `DocForm()`,
deliberately not adopted into any hgit command since every hgit view
is a generated, read-only document, not an interactive form.
`hgit check <repo>` also now exists — the original brief's "shrine
check" (repo integrity verification), a thin wrapper over M0's own
`ArchiveVerify` — verified against a real repo and against a
deliberately corrupted one (correctly reports `CHECK_FAIL`, not a
false pass). `Head.HC` (unused since ADR 0003, previously left
undeleted as "a separate decision") is now actually deleted — confirmed
zero real callers, then verified on a truly fresh QEMU boot with a
full command-surface regression, nothing broke
(`experiments/65-head-deletion/`). **A more severe bug class was then
found and fixed in `Meta.HC` itself** — the shared metadata layer
underneath every real command had the same fixed-buffer pattern in
nine of its own functions, but unlike every prior crash-based bug this
one produced **zero error signal**: a real 150-offer stress test
reported `DISPATCH_OK` for every single call while silently losing 35
of 150 real operation-log entries and leaving `HEAD` stuck 36 offers
behind the true latest commit. Fixed the same way (`MAlloc`'d from the
file's real size); verified with full data-integrity accounting after
the fix (`experiments/66-meta-dynamic-buffer/`). Getting here also surfaced a real crash — `hgit offer *` against a directory holding
dozens of pre-existing files caused a genuine kernel-level GPF (not a
graceful error) — since **root-caused and fixed**
(`experiments/56-offer-buffer-guard/`): two unbounded stack buffers in
`Offer.HC` now cleanly skip a file that doesn't fit (`OFFER_SKIP ...`)
instead of corrupting memory. A **second, different crash** was then
found and fixed the same way: a repo that simply accumulates ~13+
ordinary offers alone (no wildcards, no large files) eventually
overflows `Offer.HC`'s `archive[8192]` in-memory copy buffer — bisected
precisely (repo grows ~600 bytes/offer, crash confirmed at exactly the
point the repo alone exceeds 8192 bytes) and fixed with a clean
`OFFER_REFUSED` refusal instead of a crash
(`experiments/60-archive-buffer-guard/`). **That ceiling is now fully
lifted** (`docs/adr/0007-dynamic-archive-buffer.md`,
`experiments/61-dynamic-archive/`): `archive` is `MAlloc`'d from the
repo's real size instead of a fixed array. Fixing it surfaced a
*second*, different fixed-buffer bug at a larger scale
(`old_idx_hashes[64*64]`, a hardcoded 64-object-in-the-whole-repo cap)
— fixed the same way. Verified with 30 corrections growing a repo to
30,808 bytes, no crash. The same fixed-array pattern also existed in
five other read-only view commands (`see`/`history`/`status`/
`historydoc`/`reconcileoverview`) — **now fixed too**
(`experiments/62-index-buffer-sweep/`), verified against a real
26-offer/~78-object repo run through all five, no crash; see
`docs/research/failed-approaches.md`.

**Three real releases are cut**: [`v0.3.0`](https://github.com/VectorSophie/hgit/releases/tag/v0.3.0)
(M0–M3 complete), [`v0.4.0`](https://github.com/VectorSophie/hgit/releases/tag/v0.4.0)
(M4's reconciliation view underway), and
[`v0.5.0`](https://github.com/VectorSophie/hgit/releases/tag/v0.5.0)
(every known fixed-size-buffer overflow found and fixed). Each attaches
`packaging/HgitAll.HC` — verified downloaded and byte-identical to the
local build before being announced done. Matches TempleOS's own
convention (no installer/package manager; a program is `#include`d as
one source file) — see `docs/research/09-packaging-and-releases.md`.

## Next steps

See `docs/research/10-product-proposal.md` for the live risk register
and milestone checklist.

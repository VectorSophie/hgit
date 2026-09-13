# Product proposal (preliminary — not the real M0 acceptance doc yet)

This is **not** the final version the brief asks for. That version needs
docs 04/06/09 filled in first, plus the remaining QEMU probes in doc 08.
Writing a firm proposal ahead of that evidence would violate the brief's
own engineering-discipline rule against freezing decisions without
evidence. What follows is a risk register and M0 acceptance draft, useful
for planning the next sessions of work.

**Note on this doc's own age**: the risk register immediately below was
written during early M0 research and, until this note, had not been
updated to reflect how much of it the project has since resolved through
real, verified work (M0-M3 are now substantially complete — see the
narrative log further down this file for the actual, dated history).
Table entries below are now corrected to their real current status
rather than left stale; the prose sections after the M0 checklist remain
the authoritative, chronological record of what was actually done and
verified, probe by probe.

## Risk register (highest risk first)

| Risk | Status | Evidence |
|---|---|---|
| TempleOS doesn't run in any available environment | **Resolved — low risk** | `experiments/00-qemu-boot/`: boots clean under plain QEMU/TCG, no KVM, no patches |
| Automated pass/fail signal out of a booted TempleOS guest | **Resolved — low risk** | `experiments/01-temple-repl/`: scripted install + COM2 injection + real `D_OK`/`PASS .../D_DONE` round trip through a host file, zero human interaction |
| No usable host-side HolyC toolchain, forcing every test through QEMU | **Accepted, not a blocker** — every probe (00 through 53) has gone through the real QEMU injection loop; this was never worked around, just proven fast and reliable enough (paced_push.py, stage-2 error capture) to not need a host toolchain | `experiments/01-temple-repl/`, `docs/research/01-templeos-holyc.md` |
| Canonical encoding / BLAKE2b feasibility natively in HolyC | **Resolved** — both built, verified against RFC 7693 and official KAT vectors, running natively | `src/hgit-core/Canon.HC`, `Blake2b.HC`; `experiments/03-canonical-encoding/`, `experiments/04-blake2b-native/`, `experiments/08-blake2b-streaming/` |
| RedSea contiguous-file storage constraints on an append/rebuild archive format | **Resolved** — `FileWrite` transparently handles both growth and shrinkage of an existing file (confirmed directly, not just for small archives); the entire object store (`.hgs`) and `Meta.HC`'s combined metadata file both rely on this pattern across 53 probes with no failure traced to it | `experiments/14-file-growth/`, `experiments/30-oplog-undo/` (shrink), and every probe since |
| ZealOS networking maturity as a transport target | **Superseded** — hgit ended up needing no network transport of its own; `hgit export`/`import` (whole-repo portability) use plain local file copies instead | `experiments/45-hgit-export-import/` |
| QEMU test-harness input timing is not naively reliable | **Resolved as an established, repeatable workflow** — real idle/ready checks (reading literal screendump text before typing, never assuming timing) are now the standing practice for every probe, documented and followed consistently since probe 01 | `docs/research/01-templeos-holyc.md`, every probe's own README |
| Stage-1 daemon has no compile-error capture, silently hangs on a real syntax error | **Resolved** — found via deliberate reproduction, fixed by upgrading to the devkit's stage-2 daemon (`D2`/`_DRun`, `Fs->catch_except`-based `COMPILE_OK`/`COMPILE_FAIL` reporting) before pushing new/changed source; now standing practice | `experiments/31-oplog-in-offer/`, `docs/research/01-templeos-holyc.md` |
| A real, previously-undocumented 33-character path-length ceiling (`FileWrite`/`FileRead` silently no-op past it) | **Resolved architecturally** — `Meta.HC` consolidates every per-repo tool-state concern into one combined file, immune to the ceiling scaling with path names; every real command now runs on it | `docs/adr/0003-path-length-ceiling.md`, `experiments/36` through `44` |
| Large unpaced pushes over the injection channel can silently drop bytes under host memory pressure | **Resolved** — `experiments/01-temple-repl/paced_push.py` sends in small paced chunks; standard practice for any push over ~10KB | `experiments/34-hgit-paths/` |
| `hgit offer *` against a directory holding many dozens of pre-existing files causes a real kernel-level GPF, not a graceful error | **Resolved** — root-caused to two unbounded fixed-size stack buffers in `Offer.HC` (`tree_content[2048]`, `blob_tagged[512]`); a file that doesn't fit is now cleanly skipped (`OFFER_SKIP ...`) instead of corrupting memory. Confirmed by reproducing both of the bug's failure modes (a GPF and, separately, a silent infinite loop) before fixing, then re-verifying the fix against both plus a full regression of probe 55's own scenario | `experiments/56-offer-buffer-guard/`, `docs/research/failed-approaches.md`'s 2026-09-13 entries |

## M0 acceptance criteria (draft, per the brief's own list)

- [x] Native TempleOS execution reachable in this environment (boot proven)
- [x] Automated QEMU control with observable, host-parseable test results
      (proven end to end: scripted install, scripted daemon bootstrap,
      COM2 source injection, `PASS`-marker round trip via host file —
      `experiments/01-temple-repl/`)
- [x] Canonical binary encoding round-trip, in HolyC
      (`src/hgit-core/Canon.HC`, `experiments/03-canonical-encoding/` —
      found and fixed two real HolyC quirks in the process)
- [x] Official BLAKE2b vectors passing in native HolyC
      (`src/hgit-core/Blake2b.HC`, `experiments/04-blake2b-native/` —
      RFC 7693 vector matched exactly, first try)
- [x] Same fixture hashes identically in TempleOS and a host build
      (probe 04's TempleOS digest == probe 02's host oracle digest for
      the same "abc" input)
- [x] Append/read/rebuild of a tiny object archive
      (`src/hgit-core/Archive.HC`, `experiments/05-tiny-archive/` —
      found and fixed a genuine new HolyC quirk: bare top-level loops
      with local declarations can silently misbehave)
- [x] Source injection into, and `.HGS` extraction from, a disposable guest
      (`FORMAT.md`, `src/hgit-core/Hgs.HC`, `experiments/06-hgs-format/`
      — a real, versioned, byte-documented `.HGS` header now exists,
      written and read back through the proven injection channel)

**All seven M0 acceptance boxes now checked with real evidence.** M0 is
functionally done: TempleOS boots and can be driven/tested
automatically, canonical encoding, BLAKE2b, a tiny object archive, and a
versioned `.HGS` header all work in native HolyC on real TempleOS.

Moving into M1-adjacent design: **object typing is now also implemented
and verified** (`src/hgit-core/Object.HC`, FORMAT.md) — a type tag
participates in the content hash, confirmed to prevent same-bytes-
different-type collisions. **BLAKE2b is no longer capped at 128 bytes**
either (`experiments/08-blake2b-streaming/`), **and that streaming hash
is now wired into the actual archive API** (`experiments/09-wire-streaming-hash/`)
— `ArchivePut`/`ArchiveVerify`/`HgsPut` all use it, verified with a real
200-byte object stored, persisted, and re-verified. **Tree object content is now designed and verified too**
(`src/hgit-core/Tree.HC`, `experiments/10-tree-object/`) — a flat entry
list, name → child type + hash, tested with a real two-blob tree stored,
persisted, reloaded, and both entries correctly resolved by name. **Commit object content is now designed and verified too**
(`src/hgit-core/Commit.HC`, `experiments/11-commit-object/`) — tree hash
+ parent hash(es) + timestamp + message, tested with a real
root-commit/child-commit chain where the parent field correctly names
an ancestor by its own computed hash. **The full blob→tree→commit
object graph now exists and works end to end on real TempleOS** —
persisted, reloaded, and re-verified from an actual file. **The
hash→offset index is also built and verified**
(`src/hgit-core/Index.HC`, `experiments/12-index/`) — closing the last
storage-layer gap ADR 0001/FORMAT.md flagged, after a real crash (a
General Protection fault from hand-computed offsets, not the library
code) forced a redesign that eliminated manual offset-tracking entirely
rather than just patching the arithmetic. The entire object storage
layer — encoding, hashing, typed objects, trees, commits, and lookup —
is now built and verified on real TempleOS. **M1 has actually started**: `hgit init` is now real, working code
(`src/hgit-cli/Init.HC`, `experiments/13-hgit-init/`) — creates a valid
empty repository, refuses to overwrite an existing one, verified on real
TempleOS. First file in a new `hgit-cli` module, separate from
`hgit-core`'s repository-format mechanics per the brief's own module
boundary. Remaining M1 commands (`status`, `witness`, `offer`,
`history`, `see`, `restore`, `shrine check`) are the next concrete
targets, each buildable on the now-complete object/index layer.
**Directory enumeration is now also real** (`src/hgit-cli/WorkDir.HC`,
`experiments/15-dir-enumeration/`) — `FilesFind`/`CDirEntry`, confirmed
from primary source before use, lists real working-directory files with
correct names and sizes. **`hgit status` now exists too**
(`src/hgit-cli/Status.HC`, `experiments/16-hgit-status/`), scoped
honestly to what's well-defined without a ref/HEAD concept: a
zero-offering repository reports every working-directory file as
untracked (verified); anything else reports `STATUS_UNIMPLEMENTED`
rather than guessing. **That blocker is now closed**: `src/hgit-cli/Head.HC`
(`experiments/17-head-pointer/`) — a minimal one-pointer-per-repository
"current offering" reference (deliberately not the brief's full
multi-`path` system, which is explicitly M2 work), verified absent on a
fresh repo, settable, and independently re-settable to a second value.
**`hgit offer` now exists and works** (`src/hgit-cli/Offer.HC`,
`experiments/18-hgit-offer/`) — the integration milestone. Real files →
blobs → tree → commit → HEAD update, verified for both a root offering
and a second offering with a real parent chain (HEAD correctly moved
from the first commit's hash to the second's). Every previously-built
piece (probes 03–17) composed correctly on the first try. hgit can now
actually record something, not just read/scaffold.

**`hgit history` is also done** (`src/hgit-cli/History.HC`,
`experiments/19-hgit-history/`) — walks the real parent chain from
HEAD, verified against the actual two-commit repository probe 18 built
in the previous session (correct order, correct messages/timestamps,
read back across a QEMU reboot boundary). Repeated probe 12's
index-offset mistake while building it — documenting a mistake in a
research file didn't prevent repeating it in new code — fixed the same
way, this time with the warning written directly into `History.HC`'s
own source at the point of use.

**`hgit status` now has its real comparison logic too**
(`src/hgit-cli/Status.HC`, `experiments/20-hgit-status-diff/`) — walks
HEAD's tree and classifies each working-directory file as new,
modified, or unchanged via real content-hash comparison, verified
against the actual probe-18 repository (one unchanged file, one
modified, one brand-new — all three classified correctly). `hgit`'s
core M1 loop (`init`/`status`/`offer`/`history`) is now complete and
internally consistent.

**Deleted-file detection is also done** (`experiments/21-status-deleted/`)
— a second pass over HEAD's tree checking each entry still exists on
disk, verified against the real repo (deleted a previously-unchanged
file, correctly reported `STATUS_DELETED`, other files unaffected).
`hgit status` is now feature-complete for a flat, single-tree repo at
M1 scope.

**`hgit see <offering>` is also done** (`src/hgit-cli/See.HC`,
`experiments/22-hgit-see/`) — shows a commit's message/timestamp/parent
count and its tree's entries, verified against both real commits in
the probe-18 repository plus a clean not-found error for a bogus hash.

**All five of doc 10's M1 command targets now exist and are verified:
`init`, `status`, `offer`, `history`, `see`.**

**The real entry point also now exists** (`src/hgit-cli/Hgit.HC`,
`experiments/23-hgit-dispatch/`) — and resolved a question flagged since
doc 01's first draft in the process: TempleOS has no argv/shell syntax
at all (confirmed from primary source, `Doc/CmdLineOverview.DD` — every
native command is a literal function call, `Dir("*.DD.Z")`-style). So
hgit's entry point is a single dispatcher function, `Hgit(cmdline)`,
called exactly like any other TempleOS command
(`Hgit("init C:/Home/MyRepo.hgs");`), splitting the first word as a
command name.

**`status` and `history` are now wired too**
(`experiments/24-hgit-dispatch-more/`) — both verified through the
dispatcher against the real repository, matching direct-call results
exactly. Found a genuinely new HolyC quirk while wiring them: local
variables declared in sibling `else if` branches of one function don't
get separate block scope the way C's do — same-named locals in two
branches collided as `ERROR: Duplicate member` at compile time (a
safer failure mode than probe 05/12's silent-corruption quirks, but a
real difference from C-shaped assumptions). Fixed and documented
directly in `Hgit.HC`'s comments.

`see` is now also wired (`experiments/25-hex-hash/`,
`experiments/26-hgit-see-dispatch/`) — hex-string↔hash conversion
(`src/hgit-cli/Hex.HC`) verified via round-trip on a real hash plus
rejection of invalid hex, then composed into `Hgit()`'s `see` branch and
verified end-to-end against the real repository.

**`offer` is now wired too** (`experiments/27-hgit-offer-dispatch/`) —
**all five M1 commands (`init`/`status`/`history`/`see`/`offer`) now
dispatch through `Hgit(cmdline)`, verified against a real repository.**
`offer`'s free-text message (spaces preserved, not token-split) and
`cnts.jiffies`-based timestamp both round-tripped correctly through a
real commit and back out via `see`. Along the way, corrected a wrong
diagnosis from probe 26: a "silent no-output, not fully root-caused"
failure was actually the same missing-dependency mistake both times
(every branch of `Hgit()`'s single function body needs every other
branch's dependencies present to compile, not just the one under test)
— not session-state weirdness, as originally guessed. Corrected
honestly in `failed-approaches.md` rather than left standing.

**M1's command-surface milestone is functionally complete, and now
packaged** (`tools/build-package.sh`, `packaging/HgitAll.HC`,
`experiments/28-hgit-package/`): all 16 `src/hgit-core`/`src/hgit-cli`
files concatenated in dependency order into one file, verified loadable
on real TempleOS with a single `#include "C:/Home/HgitAll.HC";` followed
by a working `Hgit("status ...")` call — in a session that never
directly pushed any individual source file. Getting the file onto disk
surfaced two more real HolyC ordering lessons (a follow-up push
overwrites the daemon's own receive buffer before a same-buffer
`FileWrite` can run; a global referenced inside an earlier-defined
function must still be declared before that function textually) plus
one unexplained one (a compile error appeared inside long-stable
`Canon.HC` code after the fourth consecutive full-package redefinition
in one session — fixed by a clean reboot, cause not determined).

**Quoting is now also done** (`experiments/29-hgit-quoting/`) —
`ExtractToken` supports `"quoted tokens with spaces"`, verified against
a real RedSea file created at a space-containing path (confirmed from
primary source that RedSea allows spaces in filenames before testing
against one). Found and fixed a real bug along the way: `init`'s
dispatch branch never routed its argument through `ExtractToken` at all
(unlike every other command), so a quoted path silently became the
*wrong* filename (quote characters included literally) rather than an
error. Fixed and verified against the real, final `Hgit()`. Also hit one
genuinely unexplained daemon hang (distinct from every prior failure —
no output or error at all, not even a reply to a trivial ping; resolved
by a clean reboot, cause not determined) and one self-inflicted
string-escaping mistake in the test harness itself (not a HolyC issue).

**M1 is now complete, including its command-surface polish.**

**First M2 milestone done: the operation log + single-level undo**
(`src/hgit-cli/OpLog.HC`, `experiments/30-oplog-undo/`) — a sidecar
append-only log of HEAD before/after values, separate from project
history per the brief's own design; verified with two real offerings
logged and two successive undos correctly walking HEAD back through
both commits to a "no commit yet" sentinel, plus a third undo correctly
reporting nothing left to undo. Also confirmed `FileWrite` can shrink
an existing file (needed for undo's truncation), not just grow one.
Hit HolyC's lack of a `?:` ternary operator — already documented in
`holyc-parser`'s own bug-compat corpus, not a new discovery, but a real
gap this session hit independently.

**`OpLogAppend` wired into `Offer.HC` itself, and a real `undo` command
— done and verified** (`experiments/31-oplog-in-offer/`). `Offer.HC`
now logs its own HEAD before/after transition on every offer (building
an explicit all-zero sentinel for the no-parent case, since
`parent_hash` is uninitialized stack garbage there); `Hgit.HC` gained
an `undo` dispatch branch. Verified end-to-end through the real
`Hgit(cmdline)` entry point (init → offer → offer → undo → undo, PASS)
— not by calling hgit-core functions directly. Getting here took two
false starts logged honestly as "blocked" before being resolved in the
same session: stage-1's daemon has no compile-error capture, so a real
syntax error freezes TempleOS's own debugger headlessly with zero
host-visible signal — indistinguishable from a hang without a
screendump. Fixed by upgrading to the devkit's stage-2 daemon (compile
errors now reported as `COMPILE_OK`/`COMPILE_FAIL` instead of silently
hanging) — now standard practice for any push of new/changed source.
Full story: `docs/research/failed-approaches.md`'s 2026-09-13 entry.

**`redo` done and verified** (`experiments/32-oplog-redo/`, PASS) — a
second sidecar file (`.redolog`) holds entries popped by `undo` so they
can be replayed; `OpLogAppend` (any real operation) clears it, matching
standard undo/redo-stack semantics, confirmed explicitly (undo, then a
real new offer, then a redo correctly fails rather than resurrecting
stale state).

**`hgit operation history` done and verified** (`experiments/33-operation-history/`,
PASS) — walks the `.oplog` sidecar oldest-first, printing each entry's
timestamp and `prev`/`new` hashes; confirmed the printed hashes form a
real chain (each entry's `prev` matches the previous entry's `new`) and
match the actual HEAD values read back independently, not just
plausible-looking output. The dispatcher gained an `operation`
top-level branch that extracts a second-word sub-command (`cmd` only
ever captures the first space-separated word) — only `history` is
implemented; anything else reports an explicit unknown-subcommand
error.

Still not yet done: `hgit operation restore <op>` (jumping to an
arbitrary point in the log, not just one step via undo/redo - a bigger
design question, deliberately not decided yet).

**Named paths (`hgit path list/new/go/close`) done and verified**
(`experiments/34-hgit-paths/`, PASS) — "main" is the always-existing
implicit default (its HEAD stays exactly `<repo_path>.head`, unchanged
from every prior probe); other paths get their own name in a
`<repo_path>.paths` list and their own `<repo_path>.head.<name>` HEAD
file; a `<repo_path>.currentpath` sidecar tracks which one is active.
`path new` correctly copies the current path's real HEAD; duplicate
creation, closing "main", and going to a nonexistent path are all
correctly refused. **Deliberately bookkeeping-only so far**: creating
or switching paths doesn't yet change what `offer`/`status`/`history`/
`see`/`undo`/`redo`/`operation history` operate on — they all still
hardcode "main". Wiring "whichever path is current" into those commands
is the natural next step.

This probe also found a second real test-harness reliability gap,
distinct from probe 31's: a large (~46KB) push sent as one unpaced
`sendall()` can have bytes dropped under host memory pressure, so its
own trailing EOT never arrives and it silently concatenates with the
*next* push instead of producing its own result. Fixed with
`experiments/01-temple-repl/paced_push.py` (small paced chunks instead
of one call) — now standard practice for any push over ~10KB. Full
story: `docs/research/failed-approaches.md`'s second 2026-09-13 entry.

**Current-path awareness wired into `offer`/`status`/`history` — done
and verified** (`experiments/35-path-aware-offer/`, PASS). `Paths.HC`
gained `CurrentHeadRead`/`CurrentHeadWrite`; those three commands now
resolve HEAD through whichever path is current rather than always
"main". Verified with one commit on `main`, a branch to `feature`, one
more commit on `feature`, then confirming `main`'s own `.head` file is
untouched, `history` shows a different entry count depending which
path is current (2 on `feature`, 1 on `main` — same command, same
repo), and `status` correctly reports `MODIFIED` on `main` vs.
`UNCHANGED` on `feature` for the identical working file.
**Deliberately not done**: `undo`/`redo` stay main-only — the
operation log itself is still a single shared-across-paths log, and
making undo/redo path-aware before that log is path-scoped would let
an undo on one path revert a HEAD hash belonging to a different path's
history (a real correctness bug, not just missing scope).

**Operation log made path-scoped, closing the undo/redo gap — done and
verified** (`experiments/36-path-scoped-oplog/`, PASS, after a real
`FAIL` was investigated and root-caused, not adjusted-until-green).
`undo`/`redo` now correctly affect only the current path's own history.

This probe also found a genuine, previously-undocumented TempleOS/
RedSea constraint: **a full path string longer than 33 characters is
silently rejected by `FileWrite`/`FileRead`** (no error - the call
just no-ops). Pinned exactly via binary search. This directly caused
the initial `FAIL` (a per-path oplog filename came out to 34
characters) and is a real, load-bearing risk for **every**
sidecar-file-per-concern design this project has used so far - a
sufficiently long repo path plus a reasonably long path name will
eventually hit it regardless of how short an individual suffix is
made. Worked around for now (shortened suffixes), not resolved at the
architecture level - a durable fix (single combined metadata file, or
hash-derived short suffixes) is real future design work, flagged for a
future ADR. Full story: `docs/research/01-templeos-holyc.md`'s "Path
length limit" section and `docs/research/failed-approaches.md`'s
second-to-last 2026-09-13 entry.

**Proactive length guard on `hgit path new` — done and verified**
(`experiments/37-path-length-guard/`, PASS). `PathNameFits` checks a
new path name against the measured 33-char ceiling *before* creating
anything, so a name that would push its own HEAD file over the limit
is refused immediately and loudly instead of silently leaving behind a
path whose HEAD can never be written or read back. Verified at the
exact boundary (12-char name accepted, 13-char name refused, nothing
partial left in the path list). This is a guard on the symptom nearest
the user, not the underlying architectural fix — a repo whose own path
is already very long, or `main`'s own sidecar files, aren't covered by
this check.

**`hgit operation restore <op>` done and verified**
(`experiments/38-operation-restore/`, PASS) — the last of the brief's
explicitly-named operation-log vocabulary (`undo`/`redo`/
`operation history`/`operation restore <op>`); all four now exist.
Jumps HEAD directly to any logged operation's recorded state by index,
verified as a genuine two-step jump (not secretly repeated undo/redo)
in both directions, with out-of-range indices refused and HEAD left
untouched. Deliberately doesn't reconcile with the undo/redo stacks
afterward — flagged as a known simplification, not an oversight.

**`.HGS` object-layer portability confirmed** (`experiments/39-portable-hgs/`,
PASS) — a raw byte copy of a `.hgs` file, with no sidecar files carried
along, correctly resolves the full commit → tree → entry chain via
`hgit see` given only a hash noted before the copy. Real evidence the
content-addressed design (ADR 0001/0002) holds on disk, not just on
paper. **Scoped honestly**: this is the object layer only — `HEAD`,
the operation log, and named paths are separate sidecar files keyed to
the exact repo path, so a copied `.hgs` file alone has no current
offering/history/paths of its own. A real `hgit export`/`import` that
bundles or reconstructs that tool-state too is still real future work.

**Path-length ceiling: architectural decision made** (`docs/adr/0003-path-length-ceiling.md`,
not yet implemented). Decided: consolidate every per-repo tool-metadata
concern (HEAD, oplog/redolog, path list, current-path) into one
combined metadata file per repo (`<repo_path>.m`), so path names live
inside the file's own structure rather than growing filenames —
removing the part of the ceiling this project's own sidecar-per-concern
design was making worse, without removing the underlying TempleOS/
RedSea constraint itself. Real migration work (touching `Head.HC`,
`Paths.HC`, `OpLog.HC`, and re-verifying every probe that depends on
today's file layout) is the next concrete M2 step, not done yet.

**ADR 0003 implementation started**: `src/hgit-core/Meta.HC`
(`experiments/40-combined-meta-file/`, PASS) implements and verifies
the combined file's HEAD-storage slice standalone — two path names'
HEADs (one 33 characters long) round-trip correctly through one
short, constant-length `<repo_path>.m` file, confirming the core idea
works. Also found a second real bug along the way: an *invalid*
(over-33-char) path passed to `FileRead` can cause a genuine **hang**,
not just probe 36's silent no-op — reproduced on two fresh boots,
worked around by never constructing an over-length path anywhere,
including test code. Not yet wired in: `Head.HC`/`Paths.HC`/`OpLog.HC`
and every dependent command/probe still use today's layout.

**ADR 0003 implementation continued**: `Meta.HC` now also covers path
declaration/listing and the current-path pointer
(`experiments/41-meta-paths-current/`, PASS) — every concern
`Paths.HC`'s sidecars held is now standalone in the combined file.
Found and fixed a second genuine HolyC reserved-identifier trap along
the way: **`pi` is a predefined global `F64` constant (π)**, and a
local variable named `pi` produces a bizarre parse error mentioning
π's own IEEE754 bit pattern rather than a normal redeclaration error —
confirmed real (not session pollution) via a brand-new function name
on a truly clean boot before chasing it further. Now documented in
`docs/research/01-templeos-holyc.md`.

**ADR 0003's storage design is now complete**: `Meta.HC` also covers
the operation log (`experiments/42-meta-oplog/`, PASS) — a new
`MetaSpliceOutLast` primitive (distinct from HEAD/CURRENT's
replace-on-write `MetaSpliceOut`) lets entries accumulate and pop in
correct LIFO order, verified with two different paths' logs sharing
one file with zero cross-talk. Every concern the old sidecar-file
scheme held now has a `Meta.HC` equivalent.

**`Paths.HC` cut over to `Meta.HC` — real commands now use it, done and
verified** (`experiments/43-paths-on-meta/`, PASS). Every public
function in `Paths.HC` (`PathNew`/`PathGo`/`CurrentHeadRead`/
`CurrentHeadWrite`/etc.) is now a thin wrapper over `Meta.HC`, with
zero changes needed to `Hgit.HC`/`Offer.HC`/`History.HC`/`Status.HC`
(same function names/signatures). Verified by reproducing probe 35's
exact scenario identically under the new backing store, **and** the
concrete payoff: a path name that the old per-path-sidecar scheme would
have rejected (46 characters, over the 33-char ceiling) now succeeds,
since names live inside the combined file instead of in filenames.
`Head.HC`'s own sidecar is effectively retired for real commands (no
real call sites left) but not deleted.

**`OpLog.HC` cut over to `Meta.HC` too — ADR 0003 fully complete**
(`experiments/44-oplog-on-meta/`, PASS). `undo`/`redo`/
`operation history`/`operation restore` all now run on the combined
file, reproducing probe 36's/38's exact scenarios identically. Every
real command hgit has now runs on `Meta.HC`; the old sidecar-file
scheme is fully retired from real code paths (`Head.HC` remains
unused-but-present).

**`hgit export`/`import` done and verified** (`experiments/45-hgit-export-import/`,
PASS) — a direct payoff of ADR 0003's completion: since a repo's entire
tool state now lives in exactly two files (the object file + `Meta.HC`'s
`.m` file), a full working copy is just copying both. Verified with a
repo holding two paths and real independent history on each: the copy's
HEADs match exactly, its own `path list`/`history` work correctly
through the real dispatcher, and — going further than probe 39's
read-only object-layer proof — `undo` on the **copy** genuinely
changes its HEAD, a real, independently mutable repository, with the
original confirmed completely unaffected.

**DolDoc research resolved** (`experiments/46-doldoc-format/`, PASS) —
the two real unknowns flagged in `docs/research/02-doldoc-interface.md`
before any DolDoc-generating code could be built are now confirmed with
direct evidence: `$..$` commands are literal plain text in a real
shipped `.DD` file (read directly, not just prose), and a HolyC-written
`.DD` file (color + line-break commands, plain `FileWrite`) renders
correctly via `Ed()` — screenshotted, and its on-disk bytes confirmed
unchanged from what was written. No new writing or viewing mechanism
is needed for a real DolDoc history view; building the actual
`hgit history`-as-DolDoc output is the next concrete step, not done
yet.

**Real DolDoc history view done and verified**
(`experiments/47-hgit-historydoc/`, PASS) — `hgit historydoc <repo>
<dest.DD>` walks the same commit chain `hgit history` does, builds a
colored `$..$`-formatted document (green hash prefix, colored
timestamp, plain message, most-recent-first), and writes it with a
plain `FileWrite`. Verified two ways: the raw file content is correct
(right order, real distinct hashes, timestamps that increase in true
chronological order even though displayed newest-first), and the
**rendered** appearance (screenshotted via `Ed()`) shows the hash and
timestamp genuinely colored, not just a text file containing dollar
signs. This closes out M2's tracked work list.

## M3 — stable entity identity + typed relations (started)

With M2's tracked work complete, M3 begins: stable entity identity and
the typed relation vocabulary (CONTINUES/CORRECTS/REVERTS/RECONCILES),
per the brief's own milestone ordering (ADR 0001 explicitly deferred
this, not designed there).

**First step done**: confirmed TempleOS has a real, usable
random-number source (`RandU32`) to build a stable ID from — verified
both from primary source (`cia-foundation/TempleOS`'s own real usage,
e.g. a filesystem serial number) and empirically on real TempleOS
(`experiments/48-rand-for-identity/`, PASS): three successive reads
returned genuinely distinct values.

**Implemented and verified**: `docs/adr/0004-stable-entity-identity.md`
— `Tree.HC`'s entry format now carries a per-entry 8-byte entity ID
(two `RandU32` reads combined); `Offer.HC` looks up the parent
commit's own tree before building the new one and copies each
still-present name's ID forward, generating a fresh one only for a
genuinely new name (`experiments/49-entity-id/`, PASS — verified the
same name keeps its ID across content changes, a new name gets a
distinct one, and an ID survives two full generations). Explicitly
scoped as a minimal first slice: no rename detection (a renamed file
gets a new ID, indistinguishable from delete+create), no relation
vocabulary yet (CONTINUES/CORRECTS/REVERTS/RECONCILES need IDs to
exist before they can refer to them — that's the next concrete M3
step). This is a real, breaking change to the tree object format
(`FORMAT.md` updated); older repos built under the previous 65-byte
entry shape are not migrated, matching this project's "no released
users yet" stance.

**Typed relation vocabulary implemented and verified**:
`docs/adr/0005-typed-relation-vocabulary.md` — `Commit.HC`'s content
gains an optional trailing `relation_tag`/`relation_target_hash`
(CONTINUES/CORRECTS/REVERTS/RECONCILES, naming an earlier commit not
necessarily the direct parent), costing one byte for the common
`REL_NONE` case. Verified both a real `hgit offer`'s ordinary commit
decodes correctly (regression) and a direct `CommitEncode`/accessor
round-trip with a real `REL_CORRECTS` relation — message, target hash,
timestamp, and parent count all correct together
(`experiments/50-relation-vocabulary/`, PASS). Storage layer only, per
this ADR's own scope: no CLI command produces a relation yet, and
relations aren't scoped to a specific entity ID within a commit.

**Real relation commands done and verified**
(`experiments/51-relation-commands/`, PASS) — `hgit correct`/
`hgit revert`/`hgit reconcile <repo> <target_hex> <find_mask>
<message>` all work through the real dispatcher (sharing one
`HgitOfferRelatedCmd` helper, not tripled logic). A real `hgit correct`
produced a commit whose relation target hash exactly matches the named
prior commit, confirmed both directly and via `hgit see`'s own
independent output (now also prints `SEE_RELATION` when present) — and
the same commit's tree entry still shows its correct ADR 0004 entity
ID, confirming both M3 features work together in one real commit.

**`revert`/`reconcile` independently verified too**
(`experiments/52-revert-reconcile/`, PASS) — closing the gap flagged
above: both pushed through the real dispatcher on their own (not just
inferred from sharing `correct`'s code path), each producing a commit
with the correct relation tag (`REL_REVERTS`/`REL_RECONCILES`) and an
exactly matching target hash.

**Entity-scoped relations done and verified**
(`docs/adr/0006-entity-scoped-relations.md`,
`experiments/53-entity-scoped-relations/`, PASS) — a relation can now
optionally name a specific tracked entity (ADR 0004's per-tree-entry
ID) within the target commit, not just the commit as a whole. Verified
with a real entity ID read straight from an actual tree entry (not
invented) round-tripping correctly through a real `hgit correct`, and
the unscoped (all-zero sentinel) case still working. Along the way,
fixed a real usability issue: entity IDs are `U64` and previously
printed with plain `%d` (a value with the high bit set shows as
negative, hit directly in probe 49's own evidence) — switched to hex
throughout (`Hex.HC`'s new `U64ToHex`/`HexToU64`), matching how hashes
are already handled.

With this, both of the brief's M3 headline features — stable entity
identity and the typed relation vocabulary, now including entity-
scoping — are designed, implemented, wired into real commands, and
verified on real TempleOS.

## M4 — executable DolDoc reconciliation (started)

With M3's identity and relation vocabulary complete, M4 begins: the
brief's other headline feature, an actual DolDoc-rendered
reconciliation view, not just the plain history view M2 already built.

**First step done**: `experiments/54-doldoc-widgets/` tested the two
widget types doc 02 flagged as untested from HolyC-generated output —
`$LK$` (link) and `$TR$` (tree). Result: **`$LK$` genuinely renders as
a real clickable/underlined link** written via plain `FileWrite`,
confirmed by screenshot — enough to build real navigation between two
conflicting commits' entries in a reconciliation view. `$TR$`'s real
argument grammar is **still unresolved** (the guessed syntax rendered
as plain text, not a tree widget) — left open rather than guessed
further; nested `$LK$` links can substitute for M4's first slice.
Also found a real harness quirk: `Ed()` blocks the daemon's command
loop until its interactive session ends (confirmed, not assumed, via
`sendkey esc` over the QEMU monitor) — meaning a reconciliation view
that opens interactively must hand off to a human at the real console
rather than being driven further by the same automated push channel,
a real constraint on how M4's "view and act on a reconciliation" step
gets built and tested going forward.

Not yet done: an actual `hgit`-generated reconciliation document (this
was a standalone widget probe, not wired into any real command), and
resolving `$TR$`'s real syntax if a genuine tree rendering turns out to
be needed rather than nested links.

**A real, wired reconciliation command now exists and is verified**:
`hgit reconciledoc <repo> <commit_hex> <dest.DD>`
(`src/hgit-cli/ReconcileDoc.HC`, `experiments/55-reconciledoc/`, PASS)
builds a real `.DD` document for a commit carrying an ADR 0005/0006
relation - its own hash/message, then a real `$LK$` link tagged with
the relation target's full hash, the relation type name, the target
commit's own message (read back from the same archive), and the scoped
entity ID if any. Verified three ways: the real dispatcher sequence
(`init`→`offer`→`correct`→`reconciledoc`, all `DISPATCH_OK`), the raw
`.DD` bytes read back matching exactly, and the rendered appearance in
`Ed()` (the link underlined, same as probe 54's finding, now from a
real command's actual output).

Getting here required recovering from a genuine new risk found along
the way: `hgit offer *` against a directory holding ~60 accumulated
files from prior probes caused a real kernel-level General Protection
fault (not a graceful error), requiring a full VM reboot to recover -
logged in `docs/research/failed-approaches.md`'s 2026-09-13 entry.
Root cause not yet isolated (a candidate list of fixed-size buffers is
flagged, not confirmed); worked around for this probe by naming one
file explicitly instead of using `*`. **This is a real, open risk**:
`hgit offer *` at scale is untested and now known-unsafe until
root-caused - explicitly not glossed over as solved.

**`$TR$`'s real syntax is now resolved** (`experiments/57-tree-widget/`,
PASS), closing the item probe 54 left open. Found via real shipped
TempleOS system source (`C:/Demo/DolDoc/TreeDemo.HC`, located through
`DolDocOverview.DD.Z`'s own glossary entry for `TR`), not guessed:
`$TR,"<label>"$` is a single self-contained command (no closing tag,
unlike `$LK$`), and nesting comes from a separate `$ID,+2$ ...
$ID,-2$` bracket around the children. Verified rendering: a real `[+]`
collapse marker from `FileWrite`-generated output. `ReconcileDoc.HC`
doesn't use this yet (still plain `$LK$` + manual indentation) -
upgrading it to a real collapsible tree is flagged as real, concrete
follow-up work, not done in this probe.

**`ReconcileDoc.HC` now uses that real tree node**
(`experiments/58-reconciledoc-tree/`, PASS) - the relation section is
now `$TR,"relation: <TYPE>"$` with the link/target-message/entity-scope
as its real `$ID,+2$/$ID,-2$`-nested children, verified end-to-end
(`init`→`offer`→`correct`→`reconciledoc`), by raw bytes, and by a real
`[+]` collapsed rendering in `Ed()`. Found a genuine new harness gotcha
while verifying it: **redefining a function doesn't retroactively fix
up an already-compiled caller's call site** - the edited file alone
compiled clean but the dispatcher kept calling the old compiled
version until it too was re-pushed (no source change needed in it).
Now standing practice for this project's long-running daemon sessions,
documented in `docs/research/01-templeos-holyc.md`.

**A real multi-commit reconciliation view now exists**:
`hgit reconcileoverview <repo> <dest.DD>`
(`experiments/59-reconcile-overview/`, PASS) walks a repo's entire
history (same parent-chain walk `HistoryDoc.HC` does) and emits a real
`$TR$` tree node for every commit that carries a relation, silently
skipping ordinary offers - closing the gap probe 58 flagged
("multiple relations in one document... isn't built"). Verified with a
real four-commit repo (two plain offers, one `correct`, one more plain
offer): the document correctly contains exactly the one
relation-carrying commit, the three ordinary ones entirely absent (not
just hidden), confirmed via raw bytes and a rendered `[+]` node in
`Ed()`. Also added a bounds guard on the same fixed-buffer risk class
probe 56 found in `Offer.HC` (a heuristic stop before `doc[8192]`
overflows, printing a clear truncation notice) - reasoned through and
wired in, though a repo large enough to actually trigger it wasn't
constructed to exercise that path directly. Hit the same `pi`
reserved-identifier collision documented since probe 41 a second time
while writing this, independently - a reminder that documenting a
mistake doesn't reliably prevent repeating it.

**Root-caused and fixed**: `experiments/56-offer-buffer-guard/` (PASS)
confirms it - `Offer.HC`'s `tree_content[2048]`/`blob_tagged[512]`
stack buffers had no bounds check, overflowing at ~24 small matched
files or any single file over 511 bytes, corrupting adjacent stack
memory (a GPF or a silent infinite loop, depending on what got
clobbered - both reproduced deliberately before fixing). Fixed with an
early skip (`OFFER_SKIP file_too_large`/`OFFER_SKIP tree_full`)
instead of a crash; re-verified against both reproductions and a full
regression of probe 55's own end-to-end scenario. Also hit and fixed a
real HolyC quirk while writing the fix - no `continue` keyword,
already documented in `experiments/templeos-devkit`'s own bug-compat
corpus but not previously hit directly in this project's own code.

## Estimated line counts (very rough, will move once real code exists)

Not estimated yet — premature before `hgit-core`'s object model is decided
(needs doc 04's jj/Fossil comparison first). Placeholder removed rather
than filled with a guess.

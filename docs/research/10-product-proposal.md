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
| A repo that simply accumulates ~13+ ordinary offers/corrections (no wildcards, no large files) eventually crosses `Offer.HC`'s `archive[8192]` in-memory copy buffer and causes a real kernel-level GPF | **Fully resolved** — probe 60 first guarded it (clean refusal instead of a crash); ADR 0007/probe 61 then lifted the ceiling entirely (`archive` is now `MAlloc`'d from the repo's real size, freed after use) — verified with 30 corrections growing a repo to 30,808 bytes, no crash, no refusal | `docs/adr/0007-dynamic-archive-buffer.md`, `experiments/60-archive-buffer-guard/`, `experiments/61-dynamic-archive/` |
| `Offer.HC`'s own `old_idx_hashes[64*64]`/`old_idx_offsets[64]` (ADR 0004's parent-tree lookup) is a hardcoded 64-*object*-in-the-whole-repo cap, unrelated to `archive` | **Resolved** — found only once ADR 0007's own fix lifted the `archive` ceiling and let real growth reach this next fixed buffer (~21 offers, ~3 objects/offer); fixed the same way, `MAlloc`'d from the repo's own exact object count (`rcount`, already known from the `.HGS` header) | `experiments/61-dynamic-archive/` |
| The same `idx_hashes[64*64]`/`idx_offsets[64]` pattern also existed in `History.HC`, `HistoryDoc.HC`, `Status.HC`, `See.HC`, and `ReconcileDoc.HC` (twice) | **Resolved** — all six call sites now `MAlloc` from the repo's real object count, same as `Offer.HC`; verified with a real 26-offer/~78-object repo against all five affected commands (`see`/`history`/`status`/`historydoc`/`reconcileoverview`), all correct, no crash | `experiments/62-index-buffer-sweep/` |
| **`Meta.HC`'s own nine `new_buf[16384]` fixed rebuild buffers silently lost data past ~114 real offers — no crash, no error signal at all** | **Resolved — a more severe bug class than every prior crash-based one** — a real 150-offer stress test found `DISPATCH_OK` reported for every single call while 35 of 150 real operation-log entries were silently never recorded and `HEAD` silently stopped advancing 36 offers before the true latest commit; fixed by `MAlloc`-ing all nine from the file's real size, verified growing cleanly past 37,966 bytes with full data-integrity accounting (`OPLOG_COUNT` exactly matching total real operations, `HEAD` correctly resolving to the true last commit) | `experiments/66-meta-dynamic-buffer/` |
| `HistoryDoc.HC`'s `doc[8192]` (no bound against a repo's real commit count) and `Status.HC`'s `tagged[512]` (no bound against a matched file's real size, same class probe 56 fixed in `Offer.HC`) | **Resolved** — found by proactively auditing every remaining fixed-size buffer after probes 60-62/66 closed out `Offer.HC`/`Index.HC`-call-site/`Meta.HC`'s own instances. `historydoc` reproduced a real GPF against the actual ~300-commit repo probe 66 built; fixed with the same truncation-guard pattern `HgitReconcileOverview` already used. `status` fixed the same way probe 56 fixed `Offer.HC` (`STATUS_TOO_LARGE_TO_CHECK`, skip instead of overflow) — **superseded** (probe 108): the skip is gone, `Status.HC` now hashes/classifies a large file correctly, same as `Offer.HC`'s own later fix (probes 105-107); only fuzzy-rename buffering keeps a real, separate, smaller limit. Both verified against real reproductions plus a normal-case regression | `experiments/67-historydoc-buffer-guard/`, `experiments/108-status-large-file-support/` |
| ADR 0004's entity IDs don't survive a rename (a renamed file, same content/different name, got a fresh ID indistinguishable from delete+create) | **Resolved for both exact-content AND fuzzy (edited) renames** — `Tree.HC`'s `TreeFindEntryByHash` carries the entity ID forward on exact content match; `Offer.HC` now also falls back to `FossilSimilarityPercent` (git's own real `-M50%` threshold) for a rename-with-edit. Verified: an exact rename (identical entity ID across two `hgit see` calls), a rename with one word changed (fuzzy match, same entity ID carried forward), and a genuinely new unrelated file in the same offer correctly NOT matching either way. `hgit status` surfaces both kinds too now (probe 85) | `docs/adr/0009-rename-detection.md`, `experiments/70-rename-detection/`, `experiments/83-fossil-similarity/`, `experiments/84-fuzzy-rename-detection/`, `experiments/85-status-fuzzy-rename/` |
| A detected rename wasn't surfaced in any command's own output (ADR 0009's own deferred item) | **Resolved** — `hgit status` (both exact-content and fuzzy) and a new `hgit diff <repo> <commit_hex>` command (per-commit tree diff against the parent's tree, same classification vocabulary and rename logic as `status`) both surface it now. Verified: a commit with a modify/delete/fuzzy-rename/new-file all present reports each correctly, silent for unchanged entries; a root commit (no parent) correctly reports every entry as new | `docs/adr/0009-rename-detection.md`, `experiments/71-status-rename-surfacing/`, `experiments/86-hgit-diff/` |
| `hgit check` skipped `git fsck`'s "dangling"/"unreachable" object categories (only "missing object" referential integrity was built) | **Resolved** — `CheckMarkReachable` walks the real object graph from every declared path's own HEAD (a repo's only real ref concept), reporting anything left unmarked as `CHECK_DANGLING <kind> <hash>`. Verified against a real, naturally-occurring case (`undo` leaves a commit's own unique objects genuinely unreachable, without deleting them — hgit's own non-destructive-history design). A real correctness bug was found and fixed along the way: duplicate-content objects (the store never dedupes) were false-positive-reported dangling until a coalescing pass was added; caught by testing against a long-lived real repo, not a fresh fixture | `experiments/72-check-dangling-objects/` |
| No command discoverability - `DISPATCH_ERR unknown_command` said what was wrong but never what to try, no full command listing existed short of reading `Hgit.HC`'s own source | **Resolved** — `hgit help` (also a bare/empty command, also a new `DISPATCH_HINT` line after `unknown_command`) prints every real command with its literal argument shape. Writing it surfaced a real mismatch between an initial guess and the dispatcher's actual `correct`/`revert`/`reconcile` argument order, corrected against the real code before finalizing | `experiments/73-hgit-help/` |
| No version string embedded in the packaged file (doc 09's own flagged gap) | **Resolved** — `hgit version` (and `hgit help`'s own first line) prints `HGIT_VERSION`, bumped by hand alongside each real release tag | `experiments/74-hgit-version/`, `docs/research/09-packaging-and-releases.md` |
| No install instructions doc existed beyond `tools/build-package.sh`'s own description (doc 09's own flagged gap) | **Resolved** — `INSTALL.md` built around the one transport this project has verified end-to-end (COM2 serial injection). A real attempt to also verify a CD-ROM-based path (`experiments/75-cd-media-attempt/`) did not conclusively work - a real, dated dead end, honestly logged rather than hidden | `INSTALL.md`, `experiments/75-cd-media-attempt/`, `docs/research/failed-approaches.md` |
| ADR 0008's Fossil.HC caller-shape-sensitivity bug had no further investigation lead (no disassembly access) | **RESOLVED** — real root cause found and fixed: a raw byte cast to `(U64)` doesn't reliably zero-extend once composed with other `(U64)`-cast byte reads in one shifted-OR expression, leaking garbage above bit 7 (why it varied by caller shape); explicit `& 0xFF` masking after each cast fixes it, verified against independently-computed ground truth across every previously-failing reproduction. `Canon.HC`'s `GetU32LE`/`GetU64LE` checked directly and confirmed unaffected (each composes bytes in a structurally different, safe way). A real, minimal diff algorithm (`FossilDeltaMakeReal`, single longest-match copy segment) followed once the checksum was trustworthy — ~61% compression verified on a real test case. `Fossil.HC` still not wired into the build — not for reliability or a missing diff algorithm now, but because no real hgit command currently stores or needs delta-compressed objects (a real architectural decision, not a technical gap) | `experiments/76-compiler-source-access/`, `experiments/79-fossil-checksum-isolation/`, `experiments/80-fossil-checksum-root-cause/`, `experiments/82-fossil-real-diff/`, `docs/adr/0008-fossil-delta-format-prototype.md` |

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

~~Still not yet done: `hgit operation restore <op>`~~ **Done** —
implemented soon after this paragraph was written (`Hgit.HC`'s
`operation restore` sub-command, `DISPATCH_OK operation_restore <n>`),
closing the brief's full operation-log vocabulary
(`undo`/`redo`/`operation history`/`operation restore <op>`). Left
here uncorrected as the honest original snapshot, per this doc's own
convention of not editing stale notes to look pre-solved.

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
Root cause not yet isolated at the time (a candidate list of
fixed-size buffers was flagged, not confirmed); worked around for this
probe by naming one file explicitly instead of using `*`. **Note: this
was flagged here as a real, open risk when first found - it no longer
is.** `experiments/56-offer-buffer-guard/`, several probes later,
root-caused and fixed it directly (`tree_content[2048]`/
`blob_tagged[512]` stack buffers with no bounds check) - see that
probe's own entry further down this file. Left here, uncorrected in
place, as the honest original record of what was known at the time
this paragraph was written - not edited after the fact to look like it
was already solved.

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

**A second, different crash found and fixed while testing the above**:
`experiments/60-archive-buffer-guard/` (PASS) - probe 59's own
truncation-guard testing surfaced a real kernel GPF at ~13 ordinary
`correct` calls in a row on a small, fresh repo (no wildcards, no large
files - a different trigger from probe 56's own bug). Bisected
precisely by logging the repo's real file size before every call:
growth is a steady ~600 bytes/offer, and the crash hits exactly once
the existing repo alone exceeds `Offer.HC`'s `archive[8192]` in-memory
copy buffer - flagged as unaddressed in probe 56's own "Not yet done"
section, now confirmed hit in practice. Fixed with a clean refusal
(`OFFER_REFUSED archive_too_large_for_in_memory_buffer`) instead of a
crash; verified against both a fresh from-zero bisection (confirms the
exact crossover point) and a harsher repeated-refusal test, plus a
regression check that normal small offers are unaffected. The
underlying ceiling itself isn't lifted - real follow-up architecture
work, not solved here.

**That ceiling is now actually lifted**: `docs/adr/0007-dynamic-archive-buffer.md`
/ `experiments/61-dynamic-archive/` (PASS) - `archive` is `MAlloc`'d
from the repo's own real size instead of a fixed `U8[8192]`, freed
after use; `MAlloc`/`Free` confirmed working correctly for a
20,000-byte buffer first, standalone, before wiring in. Re-running the
exact 30-correction reproduction that motivated this: growth continued
cleanly past the old crash point - and then hit a **second**, different
fixed-buffer bug at a larger scale (`old_idx_hashes[64*64]`/
`old_idx_offsets[64]`, a hardcoded 64-object-in-the-whole-repo cap
unrelated to `archive`, only reachable once the first ceiling was
lifted). Fixed the same way (`MAlloc`'d from the repo's own exact
object count). Final verification: all 30 corrections complete
cleanly, repo grown to 30,808 bytes, no crash, no refusal, daemon
confirmed still responsive, normal small-repo case unaffected. The
same fixed-array pattern also existed in five other call sites
(`History.HC`, `HistoryDoc.HC`, `Status.HC`, `See.HC`,
`ReconcileDoc.HC` twice), flagged then as a real, not-yet-crashed risk.

**That risk is now closed too**: `experiments/62-index-buffer-sweep/`
(PASS) applies the identical `MAlloc`-from-`rcount` fix to all five
remaining call sites, each pushed standalone to confirm a clean
compile first, then `Hgit.HC` re-pushed too (probe 58's JIT gotcha).
Verified against a real 26-offer/~78-object repo (past the old
64-object cap) run through all five affected commands in one session -
`hgit see`/`history`/`status`/`historydoc`/`reconcileoverview` all
completed correctly (`SEE_COMMIT`/`SEE_RELATION`/`SEE_TREE`,
`HISTORY_END shown=26`, `STATUS_UNCHANGED`, both `DISPATCH_OK`), no
crash, no truncation - closing every call site of this bug class this
project has found so far.

**`$LS$` (list widget) is now resolved too, closing doc 02's last
tracked DolDoc widget-syntax question**: `experiments/63-list-widget/`
(PASS) - found via `DolDocOverview.DD.Z`'s own reference to
`C:/Demo/DolDoc/Form.HC`, real system source. `$LS,D="<name>"$` is a
single self-contained command (no closing tag, like `$TR$`) bound to
an `I64` struct field via `DocForm()`'s `format` mechanism - the
option strings come from a separate `DefineLstLoad` call. Verified it
renders as a real `[]` widget (not literal text) from plain
`FileWrite`-generated output, but empty without a `DocForm()`-bound
value. **Deliberately not adopted into any hgit command**: every hgit
DolDoc view so far is generated once and read, never edited
interactively, and `$LS$` is fundamentally a form-input widget needing
`DocForm()`'s interactive binding (likely blocking the daemon the same
way `Ed()` does, per probe 54) - a real, separate feature this project
hasn't built, not a fit for the read-only views built so far.

**`hgit check` now exists too, closing a real gap**:
`experiments/64-hgit-check/` (PASS) - the original brief's command
list included a "shrine check" (repo-integrity verification) that
never got wired into the command surface as M1-M4 grew around it.
`src/hgit-cli/Check.HC` is a thin wrapper over M0's own already-tested
`Archive.HC` `ArchiveVerify` (its record shape is identical to what
every real object actually stores, so no new hashing logic). Verified
both the success case (a small repo and the real 78-object repo from
probe 62 both report `CHECK_OK`) and a deliberately-induced failure
case (one byte flipped inside a real repo's object section correctly
reports `CHECK_FAIL objects=3 ok=2 corrupt=1`, not a false pass or a
crash).

**`Head.HC` is deleted** (`experiments/65-head-deletion/`, PASS) -
closing a decision every earlier commit touching it deferred as
"separate, not made here" since ADR 0003's own implementation retired
it from real code paths. Confirmed zero real callers by grep first,
then verified on a truly fresh QEMU boot (the rebuilt package was the
first and only source compiled that session) against a real
end-to-end regression covering `init`/`offer`/`undo`/`redo`/
`path new`/`path go`/`history`/`status`/`check`/`historydoc`/`see` -
all correct, nothing broke.

**A more severe bug class found and fixed in `Meta.HC` itself**:
`experiments/66-meta-dynamic-buffer/` (PASS). Auditing `Meta.HC` - the
shared metadata layer underneath every real command - after closing
out probes 60-62's own buffer sweep found the identical fixed-buffer
pattern in nine of its own functions
(`MetaWriteHead`/`MetaPathDeclare`/`MetaPathUndeclare`/
`MetaCurrentSet`/`MetaOpLogAppend`/`MetaOpLogPopLast`/
`MetaRedoLogAppend`/`MetaRedoLogPopLast`/`MetaRedoLogClear`, each with
its own `U8 new_buf[16384]`). A real 150-offer stress test, logging
the metadata file's own real size every 10 offers (same bisection
technique as probes 60/61), found something worse than any prior
crash: **every single one of the 150 offers reported `DISPATCH_OK`**,
while the file silently stopped growing correctly past ~114 offers -
independent verification confirmed 35 of 150 real operation-log
entries were silently never recorded and `HEAD` silently stopped
advancing, 36 offers behind the true latest commit, with zero error
signal anywhere. Fixed the same way as ADR 0007 (all nine `MAlloc`'d
from the file's real size), verified on a truly fresh boot: the same
already-past-the-old-ceiling repo grew cleanly to 37,966 bytes across
another 150 offers, with full data-integrity accounting this time
(`OPLOG_COUNT` exactly matching the true total across both runs,
`HEAD` correctly resolving to the real last commit). Flagged
explicitly as a standing lesson: `DISPATCH_OK` alone was never proof
the underlying write actually persisted correctly at scale - this is
the first confirmed *silent* failure from this bug class, after four
prior *loud* (crash-based) ones.

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

**Two more real buffer bugs found by proactively auditing, not
waiting for a crash to find them**: `experiments/67-historydoc-buffer-guard/`
(PASS). After probes 60-62/66 closed out every fixed-buffer bug this
project had actually reproduced, a direct audit of every *remaining*
fixed-size buffer in the codebase found two more real, live risks.
`HistoryDoc.HC`'s `doc[8192]` had no bound against a repo's real
commit count (unlike its sibling `HgitReconcileOverview`, which
already had probe 59's own truncation guard) - reproduced a genuine
GPF against the real ~300-commit repo probe 66's own stress test left
behind (`RIP:...&StrNew`, same stack-corruption-surfaces-elsewhere
signature as probe 60's crash), fixed with the same truncation-guard
pattern. `Status.HC`'s `tagged[512]` had the identical per-file-size
bug probe 56 already fixed in `Offer.HC`, just never applied here -
fixed the same way (`STATUS_TOO_LARGE_TO_CHECK`, skip instead of
overflow). Both verified against real reproductions (a real crash
turned into a clean truncation notice, confirmed by reading the actual
generated document's raw bytes; a real 600-byte file correctly
reported too-large instead of crashing) plus an unaffected
normal-case regression.

**Fossil's delta format prototyped, honestly partially verified**:
`docs/adr/0008-fossil-delta-format-prototype.md` /
`experiments/68-fossil-delta-format/` (PARTIAL) - per doc 04's own
recommendation, `src/hgit-core/Fossil.HC` implements the format's real
byte-level mechanics (base-64 integer encode/decode, checksum,
three-part delta structure), sourced directly from Fossil's own
`src/delta.c` after two web summaries of the format disagreed with
each other. A minimal, controlled test confirms the algorithm itself
is correct (`APPLY_OK=1`, encode-time and decode-time checksums match
exactly). Along the way found and fixed a real logic bug (trailer
digits come before `;`, not after - backwards in an earlier version),
a real buffer-overrun bug (segment-loop termination scanning for `;`
is ambiguous with the trailer's own checksum digits - caused a real VM
reset), and a genuine new HolyC quirk distinct from Canon.HC's own
documented one (casting a raw byte read directly to `(I64)` gives
garbage; `(U64)` works correctly even when used as I64 afterward -
Canon.HC's own code already avoided this by convention without
documenting why). **Left honestly open, not resolved**: the identical
delta-apply call was found to pass or fail depending on unrelated
local variables declared in the caller - bisected precisely (adding
two unused locals to an otherwise-identical passing test flips the
result) but not root-caused. `Fossil.HC` is therefore **not** wired
into `tools/build-package.sh` or any real command - a real, live
reliability question remains before this format can be trusted inside
an actual hgit command's own (necessarily larger) function bodies.

**`hgit check` now does real referential integrity checking too**:
`experiments/69-check-referential-integrity/` (PASS) - closes the gap
probe 64's own README flagged, modeled directly on real `git fsck`'s
own "missing object" check (confirmed via its real docs). Walks every
commit/tree's own outgoing hash references (tree_hash, parents,
relation-target, tree child entries) and confirms each resolves to a
real object. Verified with a real valid repo (`CHECK_OK`/
`CHECK_REFS_OK`) and a deliberately corrupted `tree_hash`
(`CHECK_FAIL`/`CHECK_REFS_FAIL`, both independent checks correctly
firing). Along the way, found and fixed a genuine test-harness limit:
the package (now 133,804 bytes) had grown past the QEMU injection
daemon's own 128KB receive buffer, causing a real, reproducible
truncated-push compile error on two separate attempts - rebootstrapped
with a 512KB buffer, confirmed the identical package then compiles
cleanly. Also fixed a real build-order bug (`Check.HC` needed
`Hex.HC`'s `HashToHex` but was ordered before it in
`tools/build-package.sh`).

**Exact-content rename detection closes an ADR 0004 gap**:
`docs/adr/0009-rename-detection.md` / `experiments/70-rename-detection/`
(PASS) - `Tree.HC` gains `TreeFindEntryByHash` (the content-addressed
counterpart to the existing by-name `TreeFindEntry`); `Offer.HC`'s
per-file loop tries it after a by-name lookup against the parent tree
fails, carrying the old entity ID forward on a hash match instead of
generating a fresh one. Verified with a positive case (identical
entity ID `bed2cffaf4e6391c` carried from `P70Original.txt` to a
renamed `P70Renamed.txt`, confirmed by exact string comparison of two
`hgit see` outputs) and a negative case (a genuinely different file,
`P70BFileB.txt`, correctly gets a fresh ID `661281709c60602e` despite
an old entry existing under a different name - exercising the real
code path without a false positive). Exact-content matching only, same
scope as Git's own 100%-similarity rename detection; a fuzzy/partial-
similarity heuristic still needs a reliable diff algorithm ADR 0008's
Fossil prototype isn't yet. Regression (probe 65's full command-surface
test) re-run clean afterward; `tools/lint-package.sh` clean before
every push.

**`hgit status` now surfaces detected renames too**:
`experiments/71-status-rename-surfacing/` (PASS) - closes the last
item ADR 0009's own "what this slice does not do" section flagged.
`Status.HC`'s NEW/DELETED classification (previously printed
immediately per file) is now buffered and cross-matched by content
hash before printing, the same exact-content matching `Offer.HC`
already does via `TreeFindEntryByHash`, applied to working-directory-
vs-HEAD-tree status instead of old-tree-vs-new-tree at offer time. A
real test with an unrelated genuinely-new file and an unrelated
genuinely-deleted file present *alongside* the real rename confirms no
false-positive pairing: `STATUS_UNCHANGED`/`STATUS_RENAMED old -> new`/
`STATUS_NEW`/`STATUS_DELETED` all correct in one run. Found the no-
`continue`-keyword gap again in new code (caught by
`tools/lint-package.sh` before ever reaching QEMU) and the "duplicate
member" sibling-block quirk twice more (documented since probe 41, hit
independently again) - both fixed the same established ways. Also
needed a real file-deletion call for the test driver; three guessed
names (`FileDelete`/`FDelete`/`FileDel`) failed before finding the real
one, `Del(path, FALSE, FALSE, FALSE)`, already used correctly (if
undocumented at the standing-facts level) in
`experiments/21-status-deleted/` from much earlier in this project -
now promoted into `docs/research/01-templeos-holyc.md`.

**`hgit check` now detects dangling/unreachable objects too**:
`experiments/72-check-dangling-objects/` (PASS) - closes the gap
`Check.HC`'s own header comment flagged since probe 69. A new
`CheckMarkReachable` walks the real object graph (commit ->
tree/parents/relation-target, tree -> blob children) from every
declared path's own HEAD (`Meta.HC` gains `MetaPathCount`/
`MetaPathListInto` to enumerate them; `Index.HC` gains
`IndexLookupPos` to mark a parallel per-object flag array), reporting
anything left unmarked as `CHECK_DANGLING <kind> <hash>`. Verified
with a real, naturally-occurring case: offering a file twice then
`undo`-ing back one commit leaves that commit's own three unique
objects genuinely unreachable (hgit's own non-destructive-history
design keeps them stored, just no longer HEAD-reachable) -
`CHECK_DANGLING_COUNT 3`, exactly the undone commit's own objects.
**A real correctness bug was found and fixed along the way**: testing
against `P65Repo.hgs` (a long-lived repo this project has reoffered
identical content into across many probes) found 16 of 36 objects
falsely reported dangling - `Object.HC`'s own `ObjectPut` never
deduplicates identical content, so the same hash can occupy multiple
archive positions, and the first version of the reachability walk only
ever marked whichever position it found first. Fixed with one linear
coalescing pass (any position sharing a hash with an already-reachable
position is content-identical, hence reachable too); re-verified
`P65Repo.hgs` then correctly reports `CHECK_DANGLING_NONE`. A second,
separate bug was found in the test driver itself, not the feature
(deleting only `<repo>.hgs` and not `Meta.HC`'s own `<repo>.hgs.m`
sidecar before re-`init`-ing left a stale HEAD pointing at a hash the
fresh object store no longer had) - both logged in
`docs/research/failed-approaches.md`.

**`hgit help` now exists**: `experiments/73-hgit-help/` (PASS) - a
real "modern CLI" gap this project otherwise had (`DISPATCH_ERR
unknown_command` said what was wrong, never what to try instead, and
there was no way to see the full command surface short of reading
`Hgit.HC`'s own source). `HgitHelp()` prints one line per real command
with its literal argument shape, wired in three ways: `hgit help`, a
bare/empty command string, and a new `DISPATCH_HINT` line after
`unknown_command`. Writing the help text surfaced a real mismatch
between a first guess and the dispatcher's actual code:
`correct`/`revert`/`reconcile`'s real argument order is `<repo_path>
<target_hex> <entity_hex> <find_mask> <message>`, not
`<find_mask> <message> <target_hex>` as first assumed - checked
against `HgitOfferRelatedCmd`'s real parameter order and several prior
probes' own test-driver command strings before finalizing the help
text. Verified on real QEMU; regression (probe 65's full
command-surface test) re-run clean.

**`hgit version` now exists**: `experiments/74-hgit-version/` (PASS) -
closes doc 09's own explicitly-flagged gap ("no version string is
embedded in the packaged file itself yet"). `Hgit.HC` defines
`HGIT_VERSION`, printed by a real `hgit version` command and shown as
`hgit help`'s own first line - bumped by hand alongside each real
release tag, same discipline probe 73 established for keeping help
text in sync with the dispatcher. This probe's own version (`0.13.0`)
is the release it ships as - the first real test of that discipline.
Verified on real QEMU; regression re-run clean.

**A real `INSTALL.md` now exists**: closes doc 09's own last flagged
gap ("no install script/instructions doc exists yet"). Built around
the one transport this project has verified end-to-end - COM2 serial
injection via `paced_push.py`, the exact mechanism all 75 of this
project's probes have used. Writing it included a real attempt to also
verify a CD-ROM-based install path
(`experiments/75-cd-media-attempt/`), using a disposable
`-snapshot`-mode QEMU probe VM (confirmed afterward to have left the
main daemon and the long-lived disk image completely untouched) - the
CD path did not conclusively resolve (a real `B:` drive exists but
reported empty content both before and after hot-swapping the attached
ISO's content via the QEMU monitor; the actual CD-ROM's real drive
letter, if different, wasn't found). Logged honestly as a genuine dead
end rather than pushed further or hidden, since the product question
that motivated it already had a real, verified answer (serial
transfer) that didn't depend on solving it.

**A genuinely new debugging capability found for ADR 0008's own open
question**: `experiments/76-compiler-source-access/` - TempleOS ships
its own compiler source (`D:/Compiler/*.HC.Z`), readable via `FileRead`
(which transparently decompresses `.Z` files - confirmed reading a real
36KB optimizer-pass source file as plain text). `OptPass012.HC`'s own
documented "Pass#1&2: constant expressions are simplified, eliminated
opcodes are set to NOP" is a real, named optimizer stage whose known
failure mode matches Fossil.HC's exact bug trigger (a later use of a
value flipping whether an earlier computation of it gets folded away).
Not traced to a full root cause - a substantial reverse-engineering
task across 11 optimizer-pass files and 3 codegen backends, honestly
not attempted in full this session - but no longer an unexplained
black box, a real, concrete lead for a future session.

**`hgit logo` and real project branding**: `experiments/78-hgit-logo/`
(PASS) - the project owner provided two PNG logos and two ASCII-art
renderings (a flame/tree diamond mark); moved into `docs/brand/`,
the PNG shown at the top of `README.md`, and the narrower ASCII
version wired into the CLI as a real `hgit logo` command
(`src/hgit-cli/Logo.HC`). Verified each of the art's many literal `%`
glyphs survives intact - passed through `CommPrint`'s `"%s"` argument,
never as its format string, which would otherwise misparse them as
format specifiers. Regression re-run clean.

**ADR 0008's Fossil.HC bug narrowed further**: `experiments/79-fossil-checksum-isolation/`
(three real hypotheses tested and ruled out - mixed-signedness
comparison, stack-buffer overlap, an intermediate return-value local).
A real new fact found: the wrong checksum is already wrong at the
moment `FossilChecksum` returns *inside the encoder*
(`FossilDeltaMakeTrivial`), not in `FossilDeltaApply`'s own decode
logic as previously assumed - confirmed by instrumenting both
functions. It does **not** reproduce calling `FossilChecksum` directly
from the shape-sensitive caller, only through the
`FossilDeltaMakeTrivial` nesting layer. Real, additional narrowing,
still not a fix - see `docs/adr/0008-fossil-delta-format-prototype.md`.

**ADR 0008's Fossil.HC bug: RESOLVED**: `experiments/80-fossil-checksum-root-cause/`
- the real root cause, finally. `FossilChecksum`'s original word
composition cast three of four bytes to `(U64)` and shifted/OR'd them
together in one expression; a raw `(U64)` cast doesn't reliably
zero-extend once composed this way with other such casts - garbage
above bit 7 (left over from whatever previously occupied that
register/stack slot, hence the caller-shape sensitivity) leaks into
the sum. Verified against an independently-computed ground-truth
checksum (Python, byte-for-byte, for a real 28-byte string): the
unmasked version returned a *different wrong value in every single
caller shape tested, including the supposedly-passing ones* (they'd
only ever agreed with *each other*, never with the true value); explicit
`& 0xFF` masking after each cast, before shifting, matches the ground
truth exactly, every time. Re-ran every one of probe 68's original
nine reproductions plus probe 77's three - all now correct. `Canon.HC`'s
`GetU32LE`/`GetU64LE` (foundational to every hash/length/offset in
hgit's own object format) were checked directly against known values
and confirmed unaffected - each happens to compose bytes in a
structurally different, safe way, now understood rather than just
observed to work. Regression (probe 65's full command-surface test)
re-run clean. `Fossil.HC` still isn't wired into `tools/build-package.sh`
- not for reliability anymore (see the next entry for the diff-
algorithm question this note originally left open too).

**`hgit graph`**: `experiments/81-hgit-graph/` (PASS) - a user-
requested feature ("finishing off with a git graph like thing"), not
a milestone-plan item. Renders a real DolDoc tree view of a repo's
entire commit history across every declared path (not just one
path's own linear chain, like `historydoc`) - "main"'s own chain as
the trunk, every other path attached as its own nested branch at the
exact commit it forked from (`path new` copies the current path's
HEAD at creation time, so a real, findable fork point always exists).
Uses the same `$TR$`/`$ID,+2$`/`$ID,-2$` tree-widget nesting
`reconcileoverview` already verified. Verified against a real fork
(`offer_one` -> `offer_two` on main, then a `feature` path created at
`offer_two` with its own commit) - the rendered tree nests
`[feature]`'s own unique commit exactly one level under `offer_two`,
confirmed by exact string match against the raw output, not visual
inspection. Regression re-run clean. `tools/lint-package.sh` caught a
real "duplicate member" collision in this file's own first draft
before it ever reached QEMU. README.md also redesigned with a
resized logo, a real badge row (release version, language, platform,
tested-on, install), and a command reference table - grounded in real
research (fetched three well-known projects' own READMEs - jj, Sapling,
lazygit - for actual conventions rather than guessing).

**ADR 0008 gets a real diff algorithm**: `experiments/82-fossil-real-diff/`
(PASS) - unblocked by probe 80's checksum fix (building a diff
algorithm on top of an unreliable checksum would have been pointless).
`FossilDeltaMakeReal` finds the single longest matching substring
between source and target (a plain double scan, this project's own
"no premature optimization" stance) and encodes
`[literal][copy][literal]` when the match is worth it, falling back to
`FossilDeltaMakeTrivial`'s all-literal shape otherwise. Verified: a
real 105-byte target with one small edit compresses to a 41-byte delta
(~61% smaller), byte-for-byte round-trip confirmed (not just checksum-
trusted), plus a real no-shared-content negative case correctly
falling back and still round-tripping. This is a *first* real diff,
not the format's final one - only one copy segment, no true multi-hunk
diffing. `Fossil.HC` still isn't wired into any real command - a
genuine, separate product decision now (whether/where hgit's own
object store should use delta compression at all), not a technical
gap. Regression re-run clean.

**A real similarity measure, reusing the diff engine**:
`experiments/83-fossil-similarity/` (PASS) - `FossilSimilarityPercent`
returns the percentage of `target` covered by the same longest-match
scan `FossilDeltaMakeReal` already uses (extracted into a shared
`FossilFindLongestMatch` so the two can never drift apart), matching
git's own real "-M50%"-style similarity concept. Verified with four
real cases in one run: a near-identical pair (one word changed) scores
`76%`, totally unrelated content scores `0%`, identical strings score
`100%`, and a short file with one line appended scores `62%` -
matching `18/29 ≈ 62%` by hand. Closes the reliability blocker ADR
0009 cited for rejecting fuzzy rename detection ("needs a real diff/
similarity algorithm this project doesn't have") - not yet wired into
`Offer.HC`/`Status.HC`'s own rename detection, a separate real design
decision (threshold, multi-candidate disambiguation, real scan cost),
not made in this probe. Regression re-run clean.

**Fuzzy rename detection - `Fossil.HC` wired into a real command at
last**: `experiments/84-fuzzy-rename-detection/` (PASS). `Offer.HC`
gains a third entity-ID fallback: when neither name nor exact content
hash matches an entry in the parent tree, `FossilSimilarityPercent`
(reusing the index already built for the exact-hash path, kept alive
through the whole per-file loop instead of freed early) scores the
file against every old blob, adopting the best match's identity at
git's own real `-M50%` threshold. `tools/build-package.sh` now
includes `Fossil.HC` for the first time - the concrete real-command
need ADR 0008 said would justify adoption. Verified: a real 106-byte
file with one word changed after being renamed correctly carries its
entity ID forward, while a genuinely unrelated new file in the *same*
offer correctly gets a fresh one - no false-positive match despite
being processed in the same batch. Regression (probe 65's full
command-surface test) plus both of ADR 0009's own original exact-
content tests re-run clean, confirming exact matching still takes
priority and neither path interferes with the other.

**`hgit status` surfaces fuzzy renames too**: `experiments/85-status-fuzzy-rename/`
(PASS) - extends probe 71's exact-content rename surfacing with a
second pass reusing `FossilSimilarityPercent`, the same way `Offer.HC`
does (probe 84). `FOSSIL_RENAME_SIMILARITY_THRESHOLD` moved into
`Fossil.HC` itself (a shared constant both callers now reference,
rather than a private copy in `Offer.HC`). Verified with a real
rename-with-edit alongside an unrelated genuinely-new and genuinely-
deleted file in the same status check - all four classifications
correct, no false positives. Regression re-run clean; a genuine
state-pollution artifact was found and worked around while re-
verifying probe 71's own exact-content case (its original test driver,
written before probe 84's `Del()`-cleanup convention, gave a
confusing-but-correct result against the persistent session repo's own
accumulated history - a fresh-repo variant confirmed the real
behavior; logged in `docs/research/failed-approaches.md`).

**`hgit diff` - a real per-commit tree diff**: `experiments/86-hgit-diff/`
(PASS) - closes the risk-register item flagged when `status` first got
rename surfacing ("`hgit history`/`reconciledoc` don't surface it
yet"), not by reworking `history`'s own output format but with a new,
dedicated command. `Diff.HC` shows what changed in one commit relative
to its parent's tree - same NEW/MODIFIED/DELETED/RENAMED vocabulary
and two-pass (exact then fuzzy) rename logic `Status.HC` already uses,
just comparing two committed trees instead of a live directory against
one; simpler in one real way, since both sides are already-stored
blobs resolved on demand via the object index, no live `FileRead`
needed. Caught a real `?:` ternary (HolyC has none) via
`tools/lint-package.sh` before ever reaching QEMU. Verified: a commit
with a modify, a delete, a rename-with-edit (fuzzy match required),
and a genuinely new file all present in one offer reports each
correctly, silent for the one untouched file; a root commit (no
parent) correctly reports every entry as new. Regression re-run clean.

**A real, canonical regression suite consolidates ~86 probes' worth of
scattered testing into one place**: `tests/full-regression.hc` - the
`tests/` directory sat empty this entire project despite thorough,
real testing throughout, because that testing lived scattered one
probe-directory-per-feature across `experiments/`. One pass now
exercises `init`/`offer`/`status`/`history`/`see`/`diff`/`check`/
`undo`/`redo`/`operation history`/named paths/`correct`/the DolDoc
views/`export`/`version`/`logo` on a single fresh repo, verifying real
output at each step (not just `DISPATCH_OK`) - a real modify, delete,
fuzzy rename, and new file all correctly classified by both `status`
and `diff`; `check` correctly reporting dangling objects right after
`undo` and clean again after `redo`; the exported copy's own `check`
passing too. **A real test-hygiene bug was found and fixed while
building it**: cleaning up only the repo file between re-runs in the
same session wasn't enough - the individual working-directory files
the test itself creates needed the same treatment, or a later run
matches leftover files from an earlier one via the same `find_mask`
and silently corrupts its own result. Logged in
`docs/research/failed-approaches.md` as a general lesson, not specific
to this one test.

**Subdirectory support: the primitive question answered, the feature
itself not attempted**: `experiments/88-recursive-directory-walk/`
(PASS on the primitive) - hgit's entire object model has been flat/
single-level only since M0 (`Tree.HC`'s own header comment,
`FORMAT.md`'s "No recursive-tree test" note); this probe confirms the
real prerequisite (`FilesFind` is non-recursive, but `CDirEntry.attr &
16` reliably distinguishes a directory from a file, and a plain
recursive walker built on both correctly descends a real 3-level
directory structure with no crash and no HolyC quirk hit). Does **not**
implement real subdirectory support in `hgit offer`/the object model -
that needs nested `OBJ_TREE` objects (format surface reserved since
ADR 0001/0004 but never actually exercised) and every tree-consuming
command (`Offer.HC`/`Status.HC`/`Diff.HC`/`Check.HC`/`See.HC`/
`HistoryDoc.HC`/`ReconcileDoc.HC`/`Graph.HC`) updated to recurse - a
real, substantial, separate feature, honestly scoped rather than
half-built.

**The other subdirectory-support prerequisite - the object model
itself - is also now confirmed**: `experiments/89-nested-tree-object-model/`
(PASS). A real tree entry with `child_type = OBJ_TREE`, pointing at
another separately-stored tree object, round-trips correctly through
the exact same `TreeEncodeEntry`/`ObjectPut`/`IndexLookup`/
`TreeFindEntry` functions every real command already calls - **zero
code changes needed**, closing `FORMAT.md`'s own long-standing "No
recursive-tree test" note. Verified: a real two-level object graph (a
root tree with one blob entry and one nested-tree entry, that nested
tree holding two of its own blob entries) - the nested entry's type
and hash both correct, resolving it through the real object index
returns the exact right content, and calling `TreeFindEntry` again on
*that* resolved content correctly finds an entry inside the nested
tree, confirming a caller can walk into one with no new parsing logic.
Both real prerequisites for subdirectory support (recursive directory
walking, probe 88; the nested-tree object model, this probe) are now
confirmed working - wiring either into `Offer.HC`/any tree-consuming
command remains real, separate, unattempted work.

**ADR 0010: a real recursive tree-building primitive, and a real
incident along the way**: `docs/adr/0010-subdirectory-support.md` /
`experiments/90-recursive-tree-primitive/` (PASS). `TreeBuildRecursive`
(in `Offer.HC`, not wired into its own live dispatch - a deliberate,
separate CLI-semantics decision per the ADR) recursively builds a real
tree from a real directory, carrying entity IDs forward (exact name,
exact hash, fuzzy) independently at each directory level. Verified: a
real 3-level directory, edited only at its deepest file, correctly
carries every entity ID forward - at both nested-tree levels and every
untouched file - while the edited file's own content hash genuinely
changes. **A real incident**: the test's first version fed a headerless
synthetic archive into offset math that assumes the real `.hgs`
16-byte-header convention, hanging the shared dev daemon (used
concurrently by a peer session) in what was almost certainly a real
infinite loop from garbage read 16 bytes off - recovered via a real
QEMU monitor reset, the standard reboot dance, a full stage-1/stage-2
re-bootstrap, and a regression re-run confirming the persistent disk's
entire repo history survived intact. The peer session caught the hang
independently and moved to its own isolated session without being
asked - real coordination under a real incident. Fixed in the test
itself (a real header, not a `TreeBuildRecursive` change), re-verified
cleanly afterward. Full account in
`docs/research/failed-approaches.md`.

**ADR 0010's real CLI-semantics decision, made and wired in**:
`experiments/91-hgit-offertree/` (PASS). Once probe 90's standalone
primitive proved solid, the decision the ADR deferred (how to expose
recursive offering without touching `hgit offer`'s own live,
heavily-relied-on dispatch) was made: a brand-new, separate command,
`hgit offertree <repo> <dir_path> <message>` (`HgitOfferTree` in
`Offer.HC`, reusing `HgitOfferWithRelation`'s own conventions with
`TreeBuildRecursive` replacing the flat `FilesFind` loop). Verified: a
real nested tree (`SEE_TREE entries=2`, one `OBJ_TREE` subdirectory
entry, one `OBJ_BLOB` file entry) committed through the real command
surface; `hgit check` reporting `CHECK_OK objects=5`/`CHECK_REFS_OK`/
`CHECK_DANGLING_NONE`; a second `offertree` editing only the nested
file confirming both the subdirectory's own tree-entry ID and the
file's ID carried forward identically. The existing
`experiments/65-head-deletion/` full-surface regression re-run clean
immediately after, confirming zero interference with the existing flat
`offer` path. A follow-up re-read of `Check.HC` itself (prompted by an
initial, overly cautious doc claim that it wouldn't recurse into a
nested tree's own children) found and corrected that claim: both its
referential-integrity scan and its reachability/dangling walk are
generic per-object-type, not depth-aware, so a nested `OBJ_TREE`
record gets the exact same treatment as a top-level one automatically
- exactly what probe 91's own `CHECK_OK objects=5`/`CHECK_REFS_OK`/
`CHECK_DANGLING_NONE` already showed in practice.

**The adversarial follow-up, run for real**: `experiments/92-check-
nested-corruption/` (PASS). One byte of `SubA`'s own `inner.txt`
entry's `child_hash` flipped in place (not re-hashed, so `Index.HC`'s
own hash-keyed lookup means every OTHER real reference to `SubA` -
just the top-level tree's own entry - still resolves; isolates exactly
one failure instead of cascading into the whole parent chain). Real
result: `CHECK_BROKEN_REF tree_child_missing <hash>` (the flat scan
found the broken reference *inside* `SubA`'s own content, not just at
the top level) and `CHECK_DANGLING blob <hash>`/
`CHECK_DANGLING_COUNT 1` (the recursive reachability walk correctly
lost `inner.txt`'s real blob once its only real reference broke) - the
negative case now matches probe 91's positive one, closing that item.

**`hgit see` now recurses into nested trees**: `experiments/93-see-
nested-trees/` (PASS) - closes the `See.HC` part of ADR 0010's own
remaining "rendering-command awareness of nested trees" item. Before
this, `hgit see` printed only one flat level of a commit's tree, so a
subdirectory's own contents (buildable since probe 91's `offertree`)
were invisible short of some other, not-yet-built command.
`SeePrintTreeEntries` recurses into any `OBJ_TREE` entry (same
generic-per-object-type pattern `Check.HC`'s own `CheckMarkReachable`
already established), indenting one level deeper each time, with a
real, honest marker for a missing child instead of silently stopping.
Verified on a real 2-level-deep repo (`SubA/SubB/deep.txt`): both
nesting levels render correctly indented, `deep.txt` genuinely reached
through two real recursive lookups. Regression: probe 91's own test
re-run clean (now additionally showing `inner.txt` nested under
`SubA` - the new, correct, additive behavior), and the project's full
command-surface regression (`experiments/65-head-deletion/`)
unaffected - a flat, non-nested tree's own output is byte-identical to
before. Applied the project's own established caller-recompile
discipline again (redefining `See.HC` alone wasn't enough - `Hgit.HC`'s
own dispatcher needed re-pushing too, since it's `HgitSee`'s own
caller). Still open at the time: `HistoryDoc.HC`/`ReconcileDoc.HC`/
`Graph.HC` (still flat) and `Status.HC`/`Diff.HC` (comparing nested
trees across commits) - real, separate follow-up work, one command at
a time.

**`hgit diff` also now recurses into nested trees, and a real
DirTreeDel API-misuse dead end found (then corrected) along the way**:
`experiments/94-diff-nested-trees/` (PASS). `DiffPrintTreeChanges` refactors `Diff.HC`'s
existing NEW/MODIFIED/DELETED/RENAMED logic into a recursive helper,
same generic-per-object-type pattern as `See.HC`/`Check.HC`: a
modified subdirectory recurses (real changes reported with their full
nested path, e.g. `SubA/inner.txt`, not one opaque "`SubA` changed"
line); a wholly new or deleted subdirectory recurses against an empty
tree so every real nested entry gets its own line; a same-name kind
change (file<->directory) reports a new, honest `DIFF_TYPE_CHANGED`
signal rather than guessing. Verified on a real 2-level-deep repo:
`DIFF_NEW SubA/SubB/deep.txt` + `DIFF_MODIFIED SubA/inner.txt` for one
commit, `DIFF_DELETED SubA/SubB/deep.txt` + `DIFF_DELETED SubA/inner.txt`
for a later one. Also found and fixed a real "duplicate member"
sibling-block-same-local-name collision (probe 5's own documented
HolyC quirk, recurring) on first push.

A real dead end surfaced while building this, then self-corrected:
the test's original design called `DirTreeDel("...path...")` (a bare
string) to remove a whole subdirectory from disk, which **hung the
shared daemon**. First concluded (wrongly) that `DirTreeDel` itself
was broken - a "minimal, zero-hgit-code" follow-up test seemed to
confirm it, but had silently repeated the exact same mistake in
smaller form. The real root cause, found by re-reading this project's
own existing code: `DirTreeDel` takes a `CDirEntry*` (the list
`FilesFind` returns) and frees it - it has nothing to do with deleting
anything from disk, and every prior real usage in this codebase
(`WorkDir.HC`/`Offer.HC`/`Status.HC`) already calls it correctly.
Passing a string path let HolyC's weak typing compile it anyway, then
walked garbage bytes as a fake linked list - a real, reproducible way
to hang, unrelated to any actual defect in `DirTreeDel`. A second,
self-inflicted incident happened during the first recovery attempt (an
under-sized 128KB bootstrap buffer receiving a 222KB package push
caused a real GPF) - recovered correctly the second time with the
bootstrap's own `Db`/RX-FIFO sized to match `daemon_v2.hc`'s real
512KB bound. Both incidents, and the self-correction, fully logged in
`docs/research/failed-approaches.md`'s 2026-09-14 entry, with the
persistent disk's own repo history confirmed intact after each
(`CHECK_OK objects=138 → 144 → 150`). The test itself still deletes
files individually rather than the whole directory - not because
`DirTreeDel` needed avoiding, but because this project still has no
proven "delete a real directory entry from disk" primitive at all.

Also corrected an assumption in ADR 0010's own "not yet done" list
while writing this up: `HistoryDoc.HC`/`ReconcileDoc.HC`/`Graph.HC`
don't touch tree/file content at all (they render commit chains,
relations, and branch structure, never a file listing) - "still flat"
didn't actually apply to them, and this item doesn't either. Only
`Status.HC` (comparing a live directory against nested trees) remained
genuinely open on that list at the time.

**`hgit statustree` closes that last item**: `experiments/95-
statustree/` (PASS). A new, separate command (`hgit statustree <repo>
<dir_path>`, not a change to `hgit status`'s own `find_mask`/
`dir_prefix` semantics - the same CLI-semantics decision `offertree`
and `Diff.HC`'s own recursion already made). `StatusTreeWalk`
(`Status.HC`) recurses the same generic-per-object-type way as
`Check.HC`/`See.HC`/`Diff.HC`: a real subdirectory with a matching
committed subtree recurses into it; a wholly new real subdirectory
recurses against an empty tree so every real nested file gets its own
`STATUS_NEW <path>` line; a tree-only entry no longer present on disk
in any form recurses against an empty real directory listing, so
every entry it used to contain gets its own `STATUS_DELETED <path>`
line - existence checked via a real `FilesFind`-based directory probe,
not the flat command's own `FileRead`-succeeds check (which only ever
meant something for plain files before ADR 0010). Verified: a real
2-level-deep repo with an edited nested file, a brand-new file two
levels deep, and a deleted top-level file, all correctly and
separately reported (`STATUS_NEW SubA/SubB/deep.txt`,
`STATUS_MODIFIED SubA/inner.txt`, `STATUS_DELETED top.txt`); after
actually offering that state, a second `statustree` call reports a
clean tree. The full command-surface regression
(`experiments/65-head-deletion/`) re-run clean, `hgit status`'s own
flat output unaffected. No HolyC compile-time gotchas this time -
probe 94's sibling-block-local-name lesson was applied proactively.

ADR 0010's own "rendering-command awareness of nested trees" item is
now **fully closed** across every command that shows file-level
content (`See.HC`/`Diff.HC`/`Status.HC`). Real, separate scope
remaining at the time, unchanged from ADR 0010's own original
decision: cross-directory rename/move detection, and `offertree`'s own
relation-tag support.

**`offertree` gains relation-tag support, closing ADR 0010's last item
but one**: `experiments/96-offertree-relations/` (PASS).
`HgitOfferTreeWithRelation` parameterizes `HgitOfferTree`'s own body
with `relation_tag`/`relation_target`/`relation_entity_id` - the same
relationship `HgitOffer` already has with `HgitOfferWithRelation`.
Three new commands, `correcttree`/`reverttree`/`reconciletree`, taking
the same argument shape as flat `correct`/`revert`/`reconcile` (with
`dir_path` replacing `find_mask`), dispatch through a shared
`HgitOfferTreeRelatedCmd` helper mirroring `HgitOfferRelatedCmd`.
Verified: a real nested repo, a `correcttree` editing a nested file
and relating it back to the first commit (unscoped), `SEE_RELATION
tag=2 target=... entity=0000000000000000` correctly recorded and read
back, `hgit check` clean. Full command-surface regression re-run
clean. With this, every item ADR 0010 ever deferred except
cross-directory rename/move detection is closed - ADR 0010's own scope
is now complete.

**Research: Mercurial's obsolescence markers** (`docs/research/04-vcs-comparison.md`,
real primary sources -
`wiki.mercurial-scm.org/ChangesetEvolution`,
`mercurial-scm.org/help/topics/evolution`). With ADR 0010's own
implementation arc fully closed, picked up the next unblocked item
from doc 00's own tracked research gaps rather than inventing new
implementation scope. A marker records a predecessor, its
successor(s) (zero for a prune, multiple for a split, one covering
several for a fold), a timestamp, and the acting user; an obsolete
changeset is hidden, not deleted, and markers propagate over push/pull
independently of the changesets they describe. Comparison: structurally
close to hgit's own existing model (non-destructive `undo`/`redo`,
ADR 0004's entity IDs, `Check.HC`'s own `CHECK_DANGLING` reachability
report) via a different mechanism - neither ever destroys an object,
both treat "no longer on real history" as recoverable. One real gap
surfaced: hgit has no concept matching Mercurial's phases (draft/
public/secret, the mechanism protecting already-shared history from
divergent rewrites) - flagged as a future concern only if hgit ever
grows a real multi-remote push/pull model (`export`/`import`, probe
45, are whole-repo file copies, not that), not designed now with no
current evidence it's needed - the same "don't design ahead of
evidenced need" stance this project already takes toward object-store
compression and cross-directory rename detection.

**Research: GitButler's virtual branches** (`docs/research/04-vcs-comparison.md`,
real primary sources - `docs.gitbutler.com/features/virtual-branches/virtual-branches`,
`docs.gitbutler.com/overview`). A "target branch" is the workspace's
own production reference (typically `origin/main`); virtual branches
("lanes") apply simultaneously to ONE working directory (unlike real
Git's single `HEAD`/index), each with its own staging area - files (or
hunks) get assigned to different lanes, then each commits
independently by computing a real, full synthetic tree "as if" only
that lane's own changes existed. Comparison: a real, structural
difference from hgit's own model, not just naming - `path new`/`path
go` (`Paths.HC`) are sequential, one path active at a time, the whole
working directory committed against it on every `offer`/`offertree`.
Supporting GitButler-style per-file assignment from one snapshot would
mean `Offer.HC`/`TreeBuildRecursive` filtering which real on-disk files
belong to which path per offer - a real, substantial redesign, not a
small addition, and no current evidence any real hgit workflow needs
it. Flagged as a real, well-scoped M5-or-later candidate, not designed
now.

**Research: git's merge-base/three-way merge, plus a real object-model
prerequisite check** (`docs/research/05-git-internals-and-product-
practice.md`, `experiments/97-multiparent-commits/`, PASS). hgit
currently has NO merge command at all - named paths (`Paths.HC`) can
diverge but never rejoin. Real source
(`git-scm.com/book/en/v2/Git-Tools-Advanced-Merging`): Git's
three-way merge compares base/ours/theirs per file - unchanged-from-
base or changed-on-only-one-side resolves automatically, changed
differently on both sides is a real conflict, marked with literal
`<<<<<<<`/`=======`/`>>>>>>>` text, not auto-resolved.

Before designing an actual merge algorithm, checked the one real,
cheap prerequisite question first (same pattern ADR 0010's own probes
88/89 used): does hgit's object model already support a real
multi-parent commit? Answer: **yes, with zero code changes anywhere**
- `Commit.HC`'s own `CommitEncode`/`CommitParentHash` were never
hardcoded to one parent, and `Check.HC`'s own reachability and
referential-integrity passes already loop over every real parent.
Verified by manually constructing a real 2-parent commit (same direct-
archive-injection technique probe 92 used) from two genuinely diverged
paths: `SEE_COMMIT ... parents=2`, `CHECK_REFS_OK`,
`CHECK_DANGLING_NONE` (the reachability walk followed BOTH parents).
Full command-surface regression re-run clean.

Real, separate work still needed at the time: an actual merge
ALGORITHM (a real merge-base/lowest-common-ancestor search, and a real
three-way tree-level merge reusing `Diff.HC`'s own recursive pattern,
with a conflict representation this project doesn't have yet) - a
real, well-scoped candidate for a future session now that its one
prerequisite has real, verified evidence behind it rather than being
assumed.

**The merge-base half is now built**: `experiments/98-merge-base/`
(PASS). `FindMergeBase` (new file, `src/hgit-core/MergeBase.HC`) walks
each of two commits' own `parent[0]` chains backward (same convention
`History.HC`/`HistoryDoc.HC`/`Graph.HC`'s own fork-point search
already use), finding the first commit on one chain that's already an
ancestor of the other. Verified against a real, asymmetric fork (one
path advanced twice, the other once, past the same real fork point) -
the found base matches the true root commit exactly, not a naive
"shorter chain" guess; the trivial self-merge-base case verified too.
Scoped the same way ADR 0010 narrows its own first slices: correct for
the real, common case (`Paths.HC`'s `PathNew` guarantees a single,
findable fork point per path), not real criss-cross histories with
ambiguous multiple bases - no evidence yet hgit's real usage needs
that. Hit and fixed the same "duplicate member" sibling-block
collision (documented since probe 5, recurring since probe 94) on
first push - two sibling parent-chain-walking loops each declaring the
same local names; fixed by suffixing one side's locals, same pattern
as probe 94. Full command-surface regression re-run clean.

Real, separate work still needed at the time: the actual three-way
TREE merge (reusing `Diff.HC`'s own recursive pattern, with a conflict
representation this project doesn't have yet), and wiring
`FindMergeBase` into any real `hgit merge` command.

**`hgit merge` now exists**: `experiments/99-hgit-merge/` (PASS).
`Merge.HC`'s `HgitMerge` wires `FindMergeBase` into a real three-way
tree merge - flat trees only in this first slice (any name involving
a subdirectory reports a real, honest unsupported-conflict, not
silently skipped). Trivial cases (already up to date, fast-forward)
handled without a merge commit, matching every real VCS's own standard
behavior. Any real conflict aborts the whole merge with zero side
effects - no conflict resolution mechanism exists yet.

Verified on four real, independent scenarios: a real non-conflicting
merge (`MERGE_OK`, `parents=2`, both sides' own edits present in the
merged tree, `CHECK_OK`); a real conflict (`MERGE_CONFLICT`/
`MERGE_ABORTED`, HEAD provably unchanged by direct hash comparison,
object count unaffected); a real fast-forward (`MERGE_FASTFORWARD`,
the moved HEAD verified to exactly equal the other path's own head);
and already-up-to-date. Full command-surface regression re-run clean.

A real test-design lesson surfaced building the non-conflicting case:
`hgit offer` replaces its entire tree with whatever `find_mask`
matches (confirmed by re-reading `Offer.HC`, not assumed - no old-tree
carry-forward for unmatched names), and switching paths doesn't
restore working-directory files to that path's own committed state
(no checkout step exists). The test's first draft used single-file
masks per offer, silently dropping the other file from later commits
- a real mistake in the test's own modeling, not a `HgitMerge` bug;
fixed with a wildcard mask and an explicit restore of the untouched
file's real content before the other path's own offer.

Two real HolyC gotchas hit and fixed before this compiled: `continue`
isn't a real keyword (documented since probe 5, confirmed again
against the exact `holyc-parser` bug-compat corpus entry that predicts
it) - caught by lint before ever reaching QEMU, fixed by nesting each
loop's remaining body in a guard instead of an early skip. The
recurring "duplicate member" sibling-block collision (probes 94/98) -
this time fixed by declaring the shared scratch locals ONCE above the
loop and reusing them, a cleaner fix than per-branch suffixing when
the colliding blocks are true siblings under one shared loop.

Real, separate work still needed at the time: nested-tree three-way
merging, and any real conflict resolution mechanism (today a conflict
just aborts).

**ADR 0011 written up, plus `hgit merge` now recurses into nested
trees**: `docs/adr/0011-merge.md`, `experiments/100-merge-nested-trees/`
(PASS). Wrote the real ADR probes 97-99 had already earned but not yet
documented, matching this project's own standing discipline (every
real, substantial scoping decision gets one, same as ADR 0007/0010).
While writing it up, found and fixed a real doc-accuracy issue:
`Merge.HC`'s own header comment and the probe 99 README both claimed a
distinct `MERGE_CONFLICT_UNSUPPORTED_NESTED` tag for the nested-tree
case that never actually existed in the code - a nested conflict
always printed the same generic `MERGE_CONFLICT <name>`. Corrected in
both places.

Then closed ADR 0011's own first documented follow-up:
`MergeTreesRecursive` extends the flat per-name three-way decision one
directory level deeper wherever every side that has a name at all
agrees it's a real `OBJ_TREE` - the identical logic, not a special
case, reusing the same generic-per-object-type recursion pattern this
project already established (`Check.HC`/`See.HC`/`Diff.HC`/
`Status.HC`). A same-name kind mismatch (tree vs. file) is still a
real, honest conflict.

**A real bug found by this probe's own test, not by inspection**: the
first real run of a genuinely nested conflict reported
`MERGE_CONFLICT SubB/` instead of the real `SubB/z.txt` - two places
copied the prefixed `full_name` into the conflict buffer using the
LOCAL entry name's own length instead of `full_name`'s real, full
length, invisible at the top level (empty prefix, so the two lengths
coincided) and only exposed by a genuinely nested case. Fixed;
re-verified correct.

Verified (real QEMU runs): a non-conflicting merge inside a shared
subdirectory (both sides' own nested edits survive into a real,
newly-computed nested tree object, `CHECK_OK`), and a real conflict
inside a shared subdirectory (`MERGE_CONFLICT SubB/z.txt`, the whole
merge aborting with zero side effects - HEAD provably unchanged,
object count unaffected). Probe 99's own full four-case flat test and
the project's full command-surface regression both re-run clean after
the fix.

Real, separate work still needed: real criss-cross histories with
ambiguous multiple merge bases, and any real conflict resolution
mechanism (a conflict at any depth still fully aborts the merge).

**Research: Pijul's patch theory** (`docs/research/04-vcs-comparison.md`,
real primary source - `pijul.org/manual/theory.html`). Comparison
only, per the brief's own explicit caution against adopting patch
theory without evidence - Pijul's line-level directed-graph object
model is nothing like hgit's own content-addressed blob/tree/commit,
adopting it would be a from-scratch rewrite, not a feature. The one
detail worth naming honestly, directly relevant to ADR 0011's own
just-finished merge work: Pijul's conflicts aren't a special state
needing immediate resolution - they're real, well-defined graph
conditions (two alive vertices with no path between them; a cycle;
"zombie" vertices) the repository can represent and carry forward as
real, valid, non-destructive state. ADR 0011's own real decision sits
at the opposite extreme - any real conflict aborts the WHOLE merge
with zero side effects, forcing immediate all-or-nothing resolution
outside hgit. Not adopted or designed further - added as a real,
concrete alternative shape to ADR 0011's own "what would justify
revisiting this" list, should a total abort ever become a real
practical burden.

**Research: Sapling's "stacks" feature** (`docs/research/04-vcs-comparison.md`,
real primary source - `sapling-scm.com/docs/overview/stacks/`). Closes
the last item doc 04's own "Not yet done" list had flagged within an
already-covered VCS. A "stack" is a linear sequence of dependent
commits; editing one in the middle (`sl goto`, edit, `sl amend`)
automatically cascades a rebase through every commit above it in the
same stack. Comparison: a real, structurally different concept from
anything hgit has - hgit has no `amend`/rebase at all, a committed
object is immutable (the closest analogues, `correct` and `hgit
merge`, both only ever ADD new commits). Adopting cascading-amend
would mean hgit committing to real, in-place history rewriting for the
first time - a substantial departure from this project's own "nothing
is ever rewritten, only added to or pointed away from" stance (the
same stance the non-destructive `undo`/`redo` model and ADR 0011's own
total-abort-on-conflict decision both already rest on). Not adopted -
flagged as a real, well-scoped M5-or-later candidate, distinct in kind
(not just scope) from every other deferred candidate on doc 04's own
list. Doc 04 now has all seven of its most load-bearing comparisons
done; only Darcs/Breezy remain, both lower priority.

**A real "delete a directory from disk" primitive, found and
verified** (`experiments/101-real-dir-delete/`, PASS). This project
has repeatedly flagged "no proven primitive for deleting a real
directory entry from disk" as an open gap (`docs/research/failed-
approaches.md`'s 2026-09-14 entry, probe 94's own "Not yet done" list)
since the earlier `DirTreeDel` API-misuse incident. Reading TempleOS's
own real kernel source directly (`Kernel/BlkDev/DskCopy.HC`) found it:
the real `Del(files_find_mask, make_mask=FALSE, del_dir=FALSE,
print_msg=TRUE)` signature has a `del_dir` parameter this project had
never once investigated in its entire history of calling
`Del(path, FALSE, FALSE, FALSE)`. Tracing into `FileSysRedSea.HC`'s
own `RedSeaFilesDel` confirmed exactly what it does (a matched
directory entry is only actually deleted if `del_dir` is set), then a
real, isolated QEMU test confirmed it in practice, not just from
reading source: a real directory existed (`FilesFind` found it),
`Del(dir_path, FALSE, TRUE, FALSE)` was called (after deleting its own
real file individually first, the already-established safe practice),
and the directory entry was genuinely gone afterward (`FilesFind` no
longer found it). Full command-surface regression re-run clean.
Real, honest scope note: whether `del_dir=TRUE` alone (skipping the
individual-file-deletion step) also safely recovers a directory's own
contained files' storage is a related, separate question this probe
doesn't answer - the established safe practice (empty first, then
delete the directory) remains correct.

**Put straight to use**: `experiments/102-diff-nested-directory-gone/`
(PASS) uses probe 101's own new primitive to directly exercise the one
gap probe 94's own README had honestly left open - `hgit diff`'s
not-found-by-name "wholly vanished directory" DELETED-recursion
branch, previously only tested indirectly (an emptied-but-still-
present directory). With `SubA` genuinely removed from disk entirely
(not just emptied), a real `hgit diff` correctly recursed against an
empty tree for it, reporting both nested files as `DIFF_DELETED
SubA/x.txt`/`SubA/y.txt` with their real full paths - the true branch,
directly confirmed, not just inferred from the structurally symmetric
NEW-branch test. A post-commit `statustree` and `hgit check` both
confirmed clean. Full regression re-run clean.

**Same closure for `hgit statustree`**: `experiments/103-statustree-nested-directory-gone/`
(PASS). `Status.HC`'s own `StatusTreeWalk` already had the same real
`FilesFind`-based directory probe since probe 95, but had never been
given the adversarial input it was built for - a genuinely vanished
subdirectory. With `SubA` truly removed from disk (probe 101's
primitive) and left uncommitted, a real `hgit statustree` correctly
reported `STATUS_DELETED SubA/x.txt`/`SubA/y.txt`, comparing the live
(now-`SubA`-less) directory against the still-committed tree. Full
regression re-run clean.

**ADR 0012: named paths, written up retroactively.**
`docs/adr/0012-named-paths.md` documents a real design this project
has already built and relied on since M2 (probes 34/35/37, re-
platformed onto `Meta.HC` in probe 43) - `Paths.HC` predates this
project's own ADR discipline entirely, a gap ADR 0011 itself noted in
passing while building `hgit merge` on top of it ("`Paths.HC`, ADR-less
since it predates this project's own ADR discipline"). Documents the
real decisions: a path is exactly a name plus a HEAD pointer (no
richer branch object); one current-path pointer per repo that every
real command's own `CurrentHeadRead`/`CurrentHeadWrite` transparently
goes through; `path new` copying the current path's own HEAD at
creation time (not an empty history) - the real guarantee `Graph.HC`'s
fork-point search and `MergeBase.HC`'s lowest-common-ancestor walk
(ADR 0011) both depend on; the real Meta.HC re-platforming (probe 43)
that collapsed ADR 0003's own path-length constraint from
`repo_path + name` down to just `repo_path`, with zero observable
behavior change for any real caller. `Paths.HC`'s own header comment
now points to this ADR. Comment-only source change, still re-verified
on the shared daemon (`COMPILE_OK`) and against the full regression,
per this project's own standing discipline of never skipping real
verification even for changes that "obviously" can't affect behavior.

**Research: Darcs' patch theory** (`docs/research/04-vcs-comparison.md`,
real primary source - `pijul.org/faq`). Comparison only, same caution
as Pijul - Darcs is Pijul's own direct ancestor in spirit (both built
on patch commutation), but Darcs' theory operates on patches alone,
where Pijul's later theory adds a generalized-file structure
specifically to fix a real, documented performance pathology Darcs
has: a "conflict fight" - patch commutation across genuinely
conflicting changes can cost Darcs exponential time in the number of
conflicting patches. Pijul's own FAQ states its real guarantee
directly: logarithmic time for non-conflicting patches, never worse
than linear even in conflicting cases. Not adopted (a from-scratch
rewrite, the brief's own caution applies identically) - added as a
real, cautionary data point to ADR 0011's own "what would justify
revisiting this" list alongside Pijul's: any future move toward
representing conflicts as real, commutable state should be checked
against real, adversarial conflict counts first, not just assumed safe
by analogy to Pijul's own fix. Doc 04 now has all eight of its
originally-scoped comparisons done; only Breezy remains, lowest
priority.

**ADR 0013: repository integrity check (`hgit check`), written up
retroactively.** `docs/adr/0013-repository-integrity-check.md`
documents another real design this project already built and relied
on - `Check.HC`'s own header comment has said "see the ADR addendum
below" since probe 72, a dangling internal reference with no actual
governing ADR behind it until now (the same class of gap ADR 0012
closed for `Paths.HC`). Documents the real, three-slice incremental
build: hash integrity (probe 64, a thin wrapper over M0's own
`ArchiveVerify`), referential integrity (probe 67, a real analogue of
`git fsck`'s own most common real failure mode), and dangling/
unreachable detection (probe 72, a real reachability walk from every
declared path's own HEAD) - each shipped only once the previous slice
proved solid and a real trigger existed, not built all at once ahead
of evidence. Also documents a real correctness bug found and fixed
along the way: an object store with no content dedup (the same file
re-offered across many probes shares one hash at multiple archive
positions) caused real false-positive dangling reports until a real
coalescing pass was added - caught against a real, long-lived repo,
not a fresh fixture. `Check.HC`'s own header comment now points to
this ADR instead of a dangling self-reference. Comment-only source
change, still re-verified on the shared daemon (`COMPILE_OK`) and
against the full regression.

**Doc 04's VCS comparison research fully closed: Breezy's file-ids.**
Fetched real primary source (`breezy-vcs.org/developers/overview.html`
plus its own release/format docs, not assumed from name recognition):
Breezy assigns every tracked file a persistent file-id, distinct from
its content hash, and the CLI is itself rename-aware - a rename
carries the SAME id forward, making the id the actual rename-tracking
mechanism, not a side effect of one. Compared honestly against hgit's
own `docs/adr/0004-stable-entity-identity.md`: similar in spirit (a
persistent id independent of content). **This entry originally went
on to claim a "previously-undocumented gap" - that hgit's rename
detector (ADR 0009) never updates entity ids - and that claim was
wrong**, caught the same day by actually reading `Offer.HC`'s code and
probe 84's own real test output before letting the comparison stand:
a detected rename, exact-content or fuzzy, already carries the SAME
entity id forward (probe 84's driver confirms a renamed-and-edited
file keeps its pre-rename id byte-for-byte). Corrected in
`docs/adr/0004-stable-entity-identity.md`, `docs/research/04-vcs-comparison.md`,
and `docs/research/failed-approaches.md`. The real, narrower
difference from Breezy that survives: Breezy's CLI treats rename as
an explicit, tool-driven operation, while hgit's detection is an
after-the-fact, same-offer best-match heuristic (ADR 0009's own
documented "no cross-file disambiguation" limitation) - a real gap in
robustness, not in whether the two mechanisms are connected at all.
Breezy's other distinguishing pieces
(shared-repository stacking, by-reference nested trees) don't raise a
new design question hgit doesn't already have real evidence on (ADR
0010's own subdirectory support, ADR 0001's own one-archive-per-repo
stance). This closes doc 04's originally-scoped comparison list
entirely - all nine comparisons (jj, Fossil, Sapling, Mercurial,
GitButler, Pijul, Darcs, Breezy, plus Sapling's own separate stacks
sub-comparison) are now done, doc 04 promoted from 🟡 to ✅ in the
research index.

**A real hash table for `Index.HC`, built and verified standalone**:
`experiments/104-index-hash-table/` (PASS) closes doc 06's own
long-standing "Not yet done" item. `IndexBuildHashTable`/
`IndexLookupHashTable` (open addressing, linear probing, hashed on the
first 8 bytes of the already-uniform stored BLAKE2b hash) verified
against a real repo's real index: 75 real objects from 25 genuinely-
distinct offers, every one of the 75 real stored hashes resolving to
the identical byte offset both ways, plus two fabricated
definitely-absent hashes both correctly reported "not found" by both
paths. **Deliberately not wired into any real call site** - all six
existing `IndexLookup` callers still use the linear scan, same
"verify standalone before adopting" pattern this project already used
for `Fossil.HC` (ADR 0008): no real evidence yet that hgit's current
real scale (low hundreds of objects per repo) makes the linear scan a
practical bottleneck. `Index.HC`'s own header comment corrected to
describe the current state accurately. Regression re-run clean.

**Doc 05 (Git internals) promoted to fully done.** Its own "Not yet
done" section had gone stale in the same way doc 06's had (still
saying nested-tree merging was "ongoing" after probe 100 had already
resolved it) - corrected. Also checked doc 05's own deprioritization
of packfiles/commit-graph/protocol v2 against real primary source
(`git-scm.com/book/en/v2/Git-Internals-Packfiles`) rather than leaving
it an unverified assumption: Git's own docs describe packfiles as
mattering once a repo reaches thousands of commits and needs efficient
network transfer - neither condition holds for hgit today (real repos
have stayed in the low hundreds of objects; doc 03 already found hgit
needs no network transport of its own). Doc-only change, promoted from
🟡 to ✅ in the research index.

**A real, shared object-content ceiling found and fixed:
`ObjectPut`'s own `tagged[4096]`.** While investigating why `Offer.HC`
silently caps every file at 511 bytes (`fsize+1 > 512`), found that
`Object.HC`'s own `ObjectPut` - called by every blob/tree/commit write
in this codebase - had a SEPARATE, deeper `tagged[4096]` fixed stack
buffer, a real shared ceiling every caller inherited regardless of its
own local caps. `experiments/105-objectput-dynamic-tag/` (PASS):
`MAlloc(dlen+1)` replaces the fixed array, verified with a real
10,000-byte object round-tripping through `ArchiveVerify` (`total=1
ok=1`), well past the old 4095-byte ceiling; `HgsPut` itself checked
directly and confirmed to have no fixed buffer of its own. Regression
re-run clean.

**Deliberately does NOT yet let real commands offer files over 511
bytes** - `Offer.HC`'s own two separate `blob_tagged[512]` stack
buffers (flat `HgitOfferWithRelation` and recursive
`TreeBuildRecursive`) and its `fsize+1 > 512` skip guard are unchanged,
a real, separate, deliberately-scoped-out follow-up: raising that cap
would also require re-deriving `ARCHIVE_HEADROOM` (currently a fixed
20,000-byte constant computed from the OLD 511-byte/27-entry worst
case) to avoid silently under-provisioning the `archive` `MAlloc` for
a genuinely large file - the exact class of memory-corruption bug ADR
0007/probes 60-61 already fixed once, not one to risk reintroducing by
rushing a caller-level cap-lift in the same slice as the deeper fix.
Logged here explicitly so it isn't mistaken for already resolved.

**Flat `hgit offer`'s own 511-byte-per-file cap: lifted, safely.**
`experiments/106-offer-large-file-support/` (PASS) does the deferred
follow-up above, for the flat path only. `HgitOfferWithRelation`'s
`blob_tagged` is now `MAlloc`'d at the file's own real size instead of
a fixed `[512]` array, and - the real risk flagged above -
`archive`'s own capacity is now a genuinely computed sum (a first
`FilesFind` pass over the same `find_mask` sums every matched entry's
own real `CDirEntry->size`, no `FileRead` needed just to size) instead
of the old fixed `ARCHIVE_HEADROOM`, so a large file's bytes are
accounted for exactly rather than assumed to fit a stale worst case.
Verified: a real 5,000-byte file (well past the old 511-byte ceiling)
offers cleanly, a second edited offer of the same large file also
succeeds (entity-ID continuity intact), and a small file offered
afterward in the same repo still works - `CHECK_OK` (hash-integrity-
verified) after each step. Both the standing regression and the full
command-surface suite (`tests/full-regression.hc`) re-run clean.
**Deliberately still does NOT fix `offertree`'s own recursive path** -
`TreeBuildRecursive` keeps the old cap and, worse, silently drops an
oversized file with no message at all (unlike the flat path's old
`OFFER_SKIP`) - a real, separate, explicitly-flagged follow-up, not
silently left implicit.

**That follow-up, now closed too.** `experiments/107-offertree-large-file-support/`
(PASS): `TreeBuildRecursive`'s own `blob_tagged` is now `MAlloc`'d the
same way, and a new recursive sizing helper (`SumTreeFileBytes`, mirrors
`TreeBuildRecursive`'s own recursion) sums every real file's size
across the WHOLE subtree plus a real subdirectory count, so
`HgitOfferTreeWithRelation`'s `archive_cap` scales correctly with
however many tree objects a real nested offering creates - not just
one, unlike the flat path. Verified: a real 6,000-byte file nested
inside a real subdirectory, previously silently dropped with zero
error signal, now commits cleanly and round-trips through `hgit
check` (hash-integrity-verified), including after a real edit to the
same nested large file (entity-ID continuity intact at depth). A
real, separate, pre-existing limitation surfaced (not introduced) by
this test: `hgit statustree` still reports `STATUS_TOO_LARGE_TO_CHECK`
for the same file - `Status.HC`'s own already-documented separate cap
(probe 67), untouched here, a real follow-up if content comparison at
this size is ever needed too. Both the standing regression and the
full command-surface suite re-run clean.

**That follow-up, now closed too.** `experiments/108-status-large-file-support/`
(PASS): both of `Status.HC`'s own per-file hashing sites (flat `hgit
status`, and `StatusTreeWalk`'s per-level file branch) had the same
fixed `tagged[512]` shape as `Offer.HC`'s old bug - `MAlloc`'d at the
file's own real size instead, same fix as probes 105-107. A real,
separate structural limit deliberately NOT removed: fuzzy-rename
buffering (`new_contents`) is still a fixed 512-byte-per-slot array,
a genuinely bigger structural change (jagged/variable-offset layout)
than this probe scopes to - a candidate too large for one slot still
gets a real hash and a real NEW/MODIFIED/UNCHANGED report, just no
fuzzy-similarity rename matching (`new_content_lens=0`, confirmed safe
against `FossilSimilarityPercent`'s own zero-length handling). Verified:
a real 5,000-byte file reports `STATUS_UNCHANGED`/`STATUS_MODIFIED`/
`STATUS_NEW` correctly (previously `STATUS_TOO_LARGE_TO_CHECK` and
nothing else), including nested inside a real subdirectory via
`statustree` - closing the exact case probe 107's own test surfaced.
Both the standing regression and the full command-surface suite
re-run clean.

**A real, confirmed correctness bug in `FindMergeBase`, found and
fixed.** `experiments/109-merge-base-stale-ancestor/` (PASS): ADR
0011's own documented "criss-cross ambiguity, no evidence yet needed"
stance turned out to understate the real risk once actually tested -
the parent[0]-only chain walk isn't just ambiguous in a rare
criss-cross case, it's flatly WRONG the moment either side's history
passes through ANY real merge commit at all, since a merge's own
second parent is invisible to it. Built a real, minimal reproduction:
a path forking from another path's own PRE-merge commit, later merged
back after that other path had already been merged once - the TRUE
common ancestor (reachable only via the earlier merge's second parent)
gets replaced by a stale, older root, producing a confirmed, real,
wrong `MERGE_CONFLICT` where a clean auto-merge should happen (not a
hypothetical - directly observed: `MERGE_CONFLICT`/`MERGE_ABORTED`
before the fix, `MERGE_OK` with the correct edit adopted after, same
scenario, same repo).

Fixed: `MergeBase.HC` rewritten to do a real ancestor-SET BFS over
EVERY parent (not just index 0) from both sides, backed by two small
reusable hash-set helpers. Genuine multi-LCA criss-cross ambiguity
remains a real, separate, still-undecided limitation (ADR 0011's own
still-accurate caveat) - this fix only stops ignoring real,
unambiguous ancestry that was reachable all along. A real HolyC quirk
caught by `tools/lint-package.sh` before QEMU: a loop variable named
`pi` collides with TempleOS's own reserved `pi` constant (this
project's own previously-documented quirk) - renamed to `pidx`.
Verified the fix produces the SEMANTICALLY correct result, not just
"no conflict": `hgit diff` against the merge's own first parent
confirms the real edit was actually adopted. Full command-surface
suite (including its own existing merge/fast-forward cases) and the
standing regression both re-run clean.

## Estimated line counts (very rough, will move once real code exists)

Not estimated yet — premature before `hgit-core`'s object model is decided
(needs doc 04's jj/Fossil comparison first). Placeholder removed rather
than filled with a guess.

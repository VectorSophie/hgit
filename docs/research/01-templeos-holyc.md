# TempleOS & HolyC

## Verified documentation

Source: `templeos.info/Wb/Doc/HolyC.DD.HTML`, `CmdLineOverview.DD.HTML`,
`Reliability.DD.HTML` (community-maintained doc mirror of the original
TempleOS `.DD` DolDoc help files).

**Types.** `I0,I8,I16,I32,I64` signed, `U0,U8,U16,U32,U64` unsigned,
`F64` — no 32-bit float. `class` replaces `typedef`; unions behave like
classes with no trailing union label. `lastclass` lets a parameter default
from the previous argument's class type.

**No `main()`.** "Any code outside of functions gets executed upon
start-up, in order." Top-level statements are live code, not declarations.
This is the same mechanism the command line REPL uses (see below) — a
`.HC` file and a line typed at the prompt are the same kind of thing.

**Memory.** No virtual memory, so no stack growth — large locals must be
heap-allocated via `MAlloc()`. `Free(NULL)` is legal. `MSize()` reveals the
real (power-of-two-rounded) allocation size. Each task owns its own heap.

**Exceptions.** `try{}catch{}`/`throw` are *not* C++-shaped: `throw` takes
an inline literal ≤8 bytes; the caught value is read from `Fs->except_ch`
inside `catch`. This is a small, fixed-size signaling mechanism, not a
general exception-object hierarchy — implies hgit-core error handling
should use small fixed tags/codes, not throw arbitrary structured error
payloads, if it wants to stay idiomatic.

**Command line is the compiler.** "The cmd line feeds into the HolyC
compiler line-by-line as you type. A stmt outside a function executes
immediately." There is no separate shell language. Bare identifiers can
call zero-arg functions without parens (`Dir` ≡ `Dir()`).

**Reliability philosophy** (Terry Davis, verbatim): *"My primary design
criteria is simplicity. If it is simple enough for only 100,000 people to
learn, lets try to make it simpler so that 1 million can learn it."*
Filesystem allocation is deliberately "the simplest possible technique, a
contiguous-file-only allocation bitmap" (RedSea). Users are told to *"keep
your entire drive limited to, maybe, 100 Meg of files"*. Explicit trade-off
stated: *"You can be a good toy or you can be a good professional tool, but
not both."*

## Facts confirmed in source (GitHub mirrors, not yet cloned/browsed in depth)

`github.com/cia-foundation/TempleOS` — top-level layout: `0000Boot`,
`Adam`, `Apps`, `Compiler`, `Demo`, `Doc`, `Downloads`, `Kernel`, `Linux`,
`Misc`. Repo is public-domain. Its own README states the source "can only
be compiled by the TempleOS compiler" — no host-side build path for the
canonical dialect (contrast with `holyc-lang`, see doc 07). **This has not
yet been verified by actually reading Kernel/Compiler source** — only the
GitHub-rendered README/structure was fetched. Reading actual `.HC`
lexer/parser source is still open work.

## Experimental evidence (this session)

TempleOS 5.03 (official ISO, `templeos.org/Downloads/TempleOS.ISO`,
sha256 `5d0fc944e5d89c155c0fc17c148646715bc1db6fa5750c0b913772cfec19ba26`)
boots to a live, usable desktop under QEMU 8.2.2/TCG on this Linux host
with zero patches, `-m 512`, no KVM. Full detail and screenshots:
`experiments/00-qemu-boot/`. The live command-line screenshot shows
`T:/Home>Cd;#include "Once";` at the prompt — directly confirming the
"cmd line is the compiler" doc claim against the running system, not just
the manual.

## Confirmed HolyC quirk: `pi` is a reserved global identifier (real F64 constant)

Found in probe 41 (`experiments/41-meta-paths-current/`) after a long,
properly-isolated debugging chase (multiple fresh reboots to rule out
session pollution, since the symptom initially looked like stale
compiler state): declaring a **local variable named `pi`** produces a
bizarre, misleading parse error rather than a normal shadowing/
redeclaration error:

```
&LexExcept PrsType PrsVarLst PrsStmt ERROR: Expecting '*' at "INT:400921FB54442D18"  (0x400921FB54442D18(F64))
```

The hex constant in that message, `0x400921FB54442D18`, is exactly the
IEEE754 double-precision bit pattern for **π** (3.14159265358979...) —
proof TempleOS predefines `pi` as a real global `F64` constant, and a
local variable declared with the same name collides with it, confusing
the parser into this cryptic message instead of a clean error. Isolated
by bisecting a failing function down to a two-line minimal repro
(`U8 buf[64]; I64 pi; for (pi=0; pi<3; pi++) buf[pi] = 'x';`) and
confirming renaming just the loop variable (to `qi`, then `ni` in the
real fix) made it compile instantly, with no other change. **Avoid
`pi` as a local/parameter name anywhere in this project** — it isn't
merely bad style here, it actively breaks compilation in a way that
looks like an unrelated bug.

## Test-harness quirk, confirmed by deliberate reproduction: stage-1 `ExePutS` has no compile-error capture

Found while chasing down two "hangs" during probe 31
(`experiments/31-oplog-in-offer/README.md`,
`docs/research/failed-approaches.md` 2026-09-13): this project's
stage-1 COM2 injection daemon (`D()`, see `experiments/01-temple-repl/`)
calls `ExePutS(Db)` directly with no error handling. When the pushed
source has a real compile error, TempleOS drops into its own
interactive debugger on the framebuffer — headlessly, with no one to
dismiss it, this parks `D()`'s receive loop forever with **zero**
host-visible signal (no error, no `D_DONE`, COM1 gets nothing). This
was confirmed by deliberately reproducing it: a malformed test payload
produced exactly this symptom, and a screendump (not `serial.log`)
showed the live debugger stopped on `ERROR: Undefined identifier`.
Without a screendump, this is indistinguishable from a genuine hang —
which is exactly how it was first logged (twice, in failed-approaches.md,
before this was understood).

**Fix / standing practice going forward:** upgrade from stage-1 `D()`
to the stage-2 daemon (`D2()`/`_DRun`, from
`templeos-devkit/scripts/temple-run.py`'s `DAEMON_V2_SOURCE`) before
pushing any new or changed source. `_DRun` wraps `ExePutS` with
`Fs->catch_except`/a redirected `put_doc`, and reports
`COMPILE_OK`/`COMPILE_FAIL` (with the actual compiler error text)
instead of silently freezing. One gotcha hit live while switching over:
the handshake reuses the same `_D_exit` variable to break stage-1's
loop and to gate stage-2's — it must be reset to `FALSE` before calling
`D2()`, or `D2()` observes it still `TRUE` and exits immediately
(printing `D_EXIT` right after `D2_OK`).

A second, distinct test-harness reliability gap found in probe 34: a
large push (~46KB) sent as one unpaced `sendall()` over the COM2 socket
can have bytes dropped somewhere between the host and the guest's
software FIFO under host memory pressure — the chunk's own trailing
EOT byte never arrived, so its content silently concatenated with the
*next* push instead of producing its own compile result (confirmed:
the 46KB file itself had no stray EOT byte inside it). Fix, now
standard practice for any push over ~10KB:
`experiments/01-temple-repl/paced_push.py` sends the file in small
(2KB) chunks with a short delay between each rather than one call.

A third test-harness gotcha, found in probe 58
(`experiments/58-reconciledoc-tree/`): **redefining a function does not
retroactively patch an already-compiled caller's call site.** Pushing
an edited helper function alone reports a clean `COMPILE_OK`, but a
caller compiled earlier in the same daemon session still calls the
*old* compiled address - confirmed directly (the caller's real output
stayed unchanged) rather than assumed, then fixed by re-pushing the
caller too (with no source changes needed in it), which re-resolves
its call to the new address. **Standing practice**: after editing any
function in a long-running daemon session, re-push every
already-compiled caller of it, not just the function itself - a clean
compile of the edited file alone is not sufficient evidence the change
took effect.

**Confirmed (probe 68, `experiments/68-fossil-delta-format/`)**:
postfix-casting a raw byte read (e.g. `buf[i]` from a `U8 *`) directly
to `(I64)` produces garbage - not the zero-extended byte value -
while casting the exact same read to `(U64)` works correctly, even
when the result is then used in I64 arithmetic afterward. Isolated
precisely across every index-expression shape tried (bare literal,
variable, arithmetic expression, explicitly parenthesized) - all
`(I64)` forms gave the same class of huge garbage number, all `(U64)`
forms gave the correct value every time. This is distinct from (though
easy to confuse with) the U32-return-value quirk `Canon.HC` already
documents from probe 3 - that one is about a function's *return type*
not being truncated for the caller; this one is about the *cast target
type* itself when the source is a raw array byte read. Canon.HC's own
working code already avoided this by convention (it only ever casts to
`(U64)`, never `(I64)`, for this purpose) without documenting why -
probe 68 re-derives and confirms the actual reason. **Standing rule**:
cast a raw byte/array read to `(U64)`, never `(I64)`, even if the
result will immediately be used as I64 - a clean `(U64)` value
composes safely into I64 arithmetic/comparisons afterward.

**RESOLVED (probes 68, 77, 79, 80)**: a real function call
(`FossilDeltaApply`) was originally found to return a different result
depending on code elsewhere in the *caller*, after the call - nine
separate reproductions (probe 68) then three more (probe 77) narrowed
this well past "any extra local," "any extra function call," or a
mixed-signedness comparison. **The real root cause (probe 80,
`experiments/80-fossil-checksum-root-cause/`)**: a raw byte cast to
`(U64)` does not reliably zero-extend once its result is shifted and
composed with *other* `(U64)`-cast byte reads in the same expression -
e.g. `(data[pos](U64) << 24) | (data[pos+1](U64) << 16) | ...`. Stray
garbage bits above bit 7 (left over from whatever previously occupied
that register/stack slot - hence the caller-shape sensitivity) leak
into the result. A single isolated `(U64)`-cast byte read (probe 68's
own original verification) never exposed this, because one clean value
printed alone looks correct even with garbage above bit 7 - it only
corrupts a *composed multi-cast* expression. **Standing rule,
refined**: casting one raw byte to `(U64)` is safe in isolation or when
combined with at most one other such cast in an expression (confirmed
safe: `Canon.HC`'s `GetU32LE`, which casts only its highest byte this
way, the other three uncast); composing **multiple** explicit
`(U64)`-cast byte reads together in one shifted-OR expression is
**not** safe - explicitly mask each with `& 0xFF` immediately after
the cast, before shifting, to force a clean value. Verified against an
independently computed ground-truth checksum: the unmasked version
never matched (a different wrong value in every caller shape tested);
the masked version matched exactly, every time.

## Facts confirmed in source (via `experiments/templeos-devkit`, ZealOS fork — close enough to stock HolyC to be informative, flagged where TempleOS-specific)

Reading `NOTES.md`/`Daemon.ZC`/`temple-run.py` (see doc 08 for full
detail) surfaced concrete, source-traced HolyC/kernel behavior beyond the
doc-mirror prose:

- **Boot-phase execution is a distinct, restricted compiler mode**, gated
  on a real flag (`Bt(&sys_run_level, RLf_SYSTEM_SERVER)`), with its own
  error path in `src/Compiler/CExcept.ZC`. Top-level `for(;;)`, `goto`+
  label, and `return` inside a function all fail in this mode with
  specific named errors traced to `src/Compiler/ParseStatement.ZC`.
  `Sys("source")` and `Once("source")` both defer execution to a
  post-boot context where these restrictions don't apply — **this is the
  closest thing found so far to an answer for the open "how does an
  AOT-style executable's startup sequence interact with boot-phase
  restrictions" question**, though it's ZealOS's `MakeHome.ZC` boot
  sequence, not literally hgit's own future invocation path.
- **`ExePutS`'s error capture mechanism is real application-visible API,
  not compiler-internal-only**: `Fs->catch_except` (bool, set on a caught
  `'Compiler'` throw) and `Fs->put_doc` (redirectable to an in-memory
  `CDoc` instead of the screen) together let calling code capture lexer
  error text programmatically. Confirmed by reading working code that
  does exactly this.
- **The interactive command line has a real, hit buffer limit around
  ~256 characters per typed line** — confirmed by needing to split a
  bootstrap sequence into small pieces to avoid truncation, and directly
  observed in this session's own reproduction (see doc 08, probe 01).
- **A newly-observed quirk (this session, not from the devkit's own
  docs)**: a bare top-level statement pushed through a live `ExePutS`
  loop can fail to resolve a symbol (`Undefined identifier`) that
  resolves fine when referenced *inside a function body* compiled
  through the identical `ExePutS` call. Identifier resolution appears to
  differ between "immediately-executed top-level statement" and
  "reference inside a not-yet-called function body," even within the
  same compilation mechanism. See `experiments/01-temple-repl/` and
  `failed-approaches.md`.
- **Confirmed (probe 03, `experiments/03-canonical-encoding/`)**: no
  C-style prefix typecast — HolyC is postfix-only (`x(Type)`, not
  `(Type)x`) — and a function's declared narrow return width (e.g.
  `U32`) is not automatically truncated/masked on return; callers can
  see garbage high bits unless the callee masks explicitly before
  returning.
- **Confirmed (probe 05, `experiments/05-tiny-archive/`)**: a bare
  top-level `while` loop that declares its own local variables can
  silently misbehave — not a compile error, a wrong-result bug — even
  well outside boot phase. Moving the identical logic into a real
  function fixed it. This is a broader, more dangerous cousin of the
  boot-phase-only top-level-loop restriction above: it doesn't error,
  it just quietly computes garbage.
- **Confirmed (probe 24, `experiments/24-hgit-dispatch-more/`)**: local
  variables declared in different `else if` branches of the *same*
  function do not appear to get separate block scope the way they
  would in C — declaring the same name (e.g. `repo_path`) in two
  sibling branches threw `ERROR: Duplicate member`, even though the
  branches are mutually exclusive and the variable is never live in
  both at once. Unlike the two quirks above, this one *does* error at
  compile time rather than silently corrupting — the safer failure
  mode, but still a real difference from C-shaped assumptions. Fix:
  give every branch's locals distinctly-named variables; don't reuse a
  name across sibling `if`/`else if` blocks in one function.
- **Confirmed (probe 30, `experiments/30-oplog-undo/`)**: the `?:`
  ternary operator is not supported — `I64 x = cond ? 1 : 2;` fails to
  parse (`ERROR: Missing '(' at ','`). Not a new discovery: already
  documented in `holyc-parser`'s own bug-compatibility corpus
  (`experiments/templeos-devkit/holyc-parser/tests/corpus/failing/`
  `009-bug-compat-bug-ternary-not-supported.hc`), found and hit
  independently here. Use plain `if`/`else` for conditional assignment.
- **Confirmed (probe 56, `experiments/56-offer-buffer-guard/`)**: no
  `continue` keyword — `if (cond) { ...; continue; }` inside a loop
  fails with `ERROR: Undefined identifier at ";"`, the same message
  probe 41's `pi` quirk produces for an unrelated reason (both look
  like a generic parse failure until traced). Not a new discovery
  either — already in `holyc-parser`'s own bug-compatibility corpus
  (`007-bug-compat-bug52-continue-keyword.hc`), but the first time this
  project's own code hit it directly rather than reading about it.
  Fix: restructure the loop body as `if (skip_cond) {...} else if
  (skip_cond2) {...} else { <rest of the loop body> }` instead of an
  early-return-style `continue`.

## Facts confirmed in source (the actual `cia-foundation/TempleOS` mirror, cloned and read directly)

Resolving a risk flagged since this dossier's first draft:

- **RedSea files literally cannot grow once created.** Primary source,
  `Doc/RedSea.DD`: *"a simple, 64-bit, file system which is similar to
  FAT32, but with absolute block addresses instead of clus, fixed-sized
  64-byte directory entries and no FAT table, just an allocation
  bitmap... Files are stored in contiguous blocks **and cannot grow in
  size**."* This is not an inference from the reliability-philosophy
  doc's tone, it's the literal filesystem behavior. **Direct
  consequence for `hgit`'s `.HGS` archive**: appending to an existing
  repository file in place is not just "constrained," it is not
  supported by the filesystem at all — growing a `.HGS` file requires
  writing a new, larger file and replacing the old one (rename or
  delete+recreate), not an in-place append. This resolves the "needs
  confirmation from actual RedSea source" risk below and should shape
  the next storage-layer probe.
- The on-disk directory entry (`CDirEntry`, "64-byte fixed-size"): `U16
  attr`, `U8 name[38]`, `I64 clus`, `I64 size`, `CDate datetime`.
  `FilesFind(mask, flags)` (`Kernel/BlkDev/DskFind.HC`) returns a
  `CDirEntry*` tree/list; real usage
  (`Adam/Opt/Utils/DocUtils.HC`) traverses it as
  `while (tmpde) { ...tmpde->full_name...tmpde->datetime...
  tmpde=tmpde->next; }` and frees it with `DirTreeDel()`. The in-memory
  traversal node clearly carries more fields (`full_name`, `next`) than
  the bare 64-byte on-disk struct shown in `RedSea.DD` — expected (a
  tree-building wrapper around the raw disk format), but the exact full
  in-memory class wasn't found in this mirror's plain-text sources (may
  be assembled at a lower level not in this checkout). Treat `full_name`/
  `next`/`datetime` as confirmed; anything else needs testing before use.

## Path length limit, confirmed by binary search (probe 36)

A real, previously-undocumented RedSea/TempleOS constraint, found
while debugging a genuine test failure (`experiments/36-path-scoped-oplog/`):
**a full path string longer than 33 characters is silently rejected by
`FileWrite`/`FileRead`** — no error, no exception, the call simply
does nothing (a subsequent read finds nothing). Pinned exactly via a
dedicated probe that wrote/read back paths of lengths 28, 30, 31, 32,
33, 34, 36 (fixed `C:/Home/` prefix + `'a'`-padded filename): **33
round-trips correctly, 34 does not**, reproduced consistently. (First
attempt at this same probe used a bare top-level `for` loop with local
declarations and produced nonsense `len=0` output for every case —
exactly the pre-existing documented quirk below about bare top-level
loops corrupting data; the correct result only appeared once the same
logic was wrapped in a real function.)

This silently broke `OpLog.HC`'s new per-path sidecar files
(`<repo_path>.oplog.<name>`) the first time a moderately-long repo path
was combined with a path name — e.g. `C:/Home/P36Repo.hgs.oplog.feature`
is 34 characters, one over the limit, and simply never got created;
`C:/Home/P34Repo.hgs.head.feature` (32 characters, the shape used in
earlier probes) fit and worked. Worked around in probe 36 by shortening
the non-main suffix (`.oplog.<name>`/`.redolog.<name>` →
`.ol.<name>`/`.rl.<name>`), which buys headroom but does not remove the
ceiling — this is a real, load-bearing constraint on **every**
sidecar-file-per-concern design this project has used (`.head`,
`.oplog`, `.redolog`, `.paths`, `.currentpath`, and their per-path
variants): a sufficiently long repository path combined with a
reasonably long path/branch name will eventually exceed it regardless
of how short an individual suffix is made. A durable fix (a single
combined per-repo metadata file instead of N growing sidecar files, or
short hash-derived suffixes instead of literal names) is real future
design work, not decided or built yet — flagged here for a future ADR.

## Unresolved risk

- ~~How does an **AOT-compiled, argv-taking** `hgit` executable fit into
  a system whose native command line is described purely as a live
  line-by-line JIT REPL?~~ **Resolved, and the premise was wrong**:
  confirmed directly from primary source (`Doc/CmdLineOverview.DD`) —
  TempleOS has **no argv/space-separated shell syntax at all**. Every
  native "command" is a literal HolyC function call with normal
  parens and string-literal arguments: `Dir("*.DD.Z");`, `Cd("B:/Tmp");`,
  `Ed("NewFile.HC.Z");`. There is no traditional `main(argc, argv)`
  convention to design around, because the cmd line already *is* the
  full language. The actual entry-point question for hgit was never
  "how do we parse argv" — it's "what's the idiomatic function-call
  shape for a git-like vocabulary in a system with no shell syntax,"
  and the answer that was actually built and verified
  (`experiments/23-hgit-dispatch/`) is a single dispatcher function
  (`Hgit(cmdline)`) taking one string, splitting its first word as a
  command name (`init`, `status`, ...) and dispatching to the
  already-verified `Hgit*()` functions — called at the cmd line exactly
  like any other TempleOS command: `Hgit("init C:/Home/MyRepo.hgs");`.
- ~~Contiguous-file-only allocation (RedSea) directly constrains the
  archive format~~ **Resolved, and turns out to be a non-issue at the
  API level**: `Doc/RedSea.DD` confirms the underlying filesystem
  primitive genuinely cannot grow a file in place, but `FileWrite`
  itself abstracts this away — tested directly
  (`experiments/14-file-growth/`): calling `FileWrite` twice on the
  *same* path with a larger buffer the second time works transparently
  (`PASS filewrite_grows_existing_file`). At the time this was written,
  "presumably via delete+recreate under the hood" was an inference, not
  a confirmed mechanism - **since confirmed directly from the real
  kernel source** (2026-09-14, `Kernel/BlkDev/FileSysRedSea.HC`'s own
  `RedSeaFileWrite`/`RedSeaFilesDel`, see doc 06's own matching entry):
  `RedSeaFileWrite` unconditionally deletes any existing same-named
  file first (freeing its real cluster allocation via
  `RedSeaFreeClus`), then allocates a brand-new, exactly-sized
  contiguous cluster range and writes the whole new content in one
  shot - a real, confirmed delete-and-reallocate, not a guess anymore.
  `hgit-core`'s existing pattern of calling `FileWrite` with a growing
  buffer on each save (as every probe from 05 onward already does)
  needs no architectural change because of this constraint — it was a
  real risk to check, and checking it was cheap and worthwhile, but it
  doesn't change anything.
- `throw`'s 8-byte-literal limit needs to be checked against how deep
  hgit-core's error paths need to be (repository corruption, hash
  mismatch, etc.) — may push toward return-code-based error propagation
  instead of exceptions for anything beyond simple aborts.

## Confirmed HolyC fact: real file deletion is `Del(path, FALSE, FALSE, FALSE)`

There is no `FileDelete`/`FDelete`/`FileDel`-named API — all three are
plausible-looking guesses that fail (`experiments/71-status-rename-surfacing/`,
`docs/research/failed-approaches.md`'s 2026-09-13 entry). `DiskDelete`
also fails, differently (a stranger `Invalid lval`/`Compiler Parse
Error` pair pointing at the identifier itself, not explained further).
The real kernel API, confirmed working, is `Del(filename, FALSE,
FALSE, FALSE)` — first used correctly (with a note flagging the same
"not FileDel" confusion) all the way back in
`experiments/21-status-deleted/`'s own test driver, just never
promoted to this standing-facts doc until probe 71 hit the same
guessing dead end independently.

## Confirmed capability: TempleOS ships its own compiler source, readable at runtime

`D:/Compiler/` (the real system drive - `C:` is an alias/redirector,
not a separate physical drive, confirmed in probe 75) holds the
compiler's own source as ordinary `.HC.Z` files: `CMain`/`Lex`/
`PrsExp`/`PrsStmt`, 11 optimizer passes (`OptPass012` through
`OptPass789A`), codegen backends (`BackA`/`BackB`/`BackC`), and
assembler files (`Asm*`, `UAsm`), plus `OpCodes.DD.Z`. `FileRead`
transparently decompresses `.Z` files - no separate step needed;
confirmed by reading `OptPass012.HC.Z` (36,330 bytes) as plain text,
complete with its own DolDoc-style comments (`experiments/76-compiler-source-access/`).
A genuinely new capability for this project: any future HolyC-quirk
investigation can read the actual compiler source that produces the
behavior, instead of pure black-box test bisection.

## Confirmed: `FilesFind` is non-recursive; `CDirEntry.attr & 16` tells a directory from a file

`FilesFind("<dir>*", 0)` lists a directory's own immediate entries
only - a subdirectory appears as one entry (size 0), not its contents
(confirmed directly, `experiments/88-recursive-directory-walk/`: a
real file placed inside a subdirectory never showed up in a wildcard
scan of the parent). `CDirEntry` has a real, working `attr` field -
`attr & 16` is set for a directory, `0` for a plain file (confirmed
directly, not assumed from a DOS-attribute-bit-convention guess;
`file_attr`, a first guess at the field name, does not exist - a real
"Invalid member" compile error). A real recursive walker built on
these two primitives (plain function recursion, skipping `.`/`..`)
correctly descends a 3-level real directory structure with no HolyC
quirk hit and no crash - the real, confirmed prerequisite for ever
lifting hgit's own current "flat, single-level tree only" limitation
(`Tree.HC`'s own header comment), though actually building that
support (nested `OBJ_TREE` objects, every tree-consuming command
updated to recurse) remains real, separate, unattempted work - see
that probe's own README.

## Architectural implications so far

- Treat `hgit` as being invoked two ways that may need different code
  paths: (a) as a compiled command an AOT-executable convention, (b) as
  source `#include`d/run at the interactive cmd line. Needs the AOT
  research above before deciding whether these share one entry point.
- Given the 100MB-drive philosophy and contiguous-only files, hgit's
  archive format must default to being *small* and rewrite-in-place
  friendly rather than assuming Git-style unbounded loose-object sprawl.
- HolyC's `class`/`lastclass` and small-value `throw` are idioms to lean
  into, not work around — reinforces the brief's warning against
  translating POSIX idioms verbatim.

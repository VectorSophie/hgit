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
  (`PASS filewrite_grows_existing_file`), presumably via delete+recreate
  under the hood. `hgit-core`'s existing pattern of calling `FileWrite`
  with a growing buffer on each save (as every probe from 05 onward
  already does) needs no architectural change because of this
  constraint — it was a real risk to check, and checking it was cheap
  and worthwhile, but it doesn't change anything.
- `throw`'s 8-byte-literal limit needs to be checked against how deep
  hgit-core's error paths need to be (repository corruption, hash
  mismatch, etc.) — may push toward return-code-based error propagation
  instead of exceptions for anything beyond simple aborts.

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

# Probe 76 — TempleOS ships its own compiler source, readable at runtime

Status: **New capability confirmed, real (not final) lead on ADR 0008's
open Fossil.HC question.** Not a fix, not a full root cause - a genuine
new tool for future HolyC investigation, plus concrete, sourced
evidence narrowing where the bug likely lives.

## What was found

`D:/Compiler/` (the real system drive - see `docs/research/01-templeos-holyc.md`'s
note that `C:` is an alias/redirector, not the real physical drive)
contains TempleOS's **own compiler's source code**, as ordinary `.HC.Z`
files - `CMain.HC.Z`, `Lex.HC.Z`, `PrsExp.HC.Z`, `PrsStmt.HC.Z`,
`OptPass012.HC.Z` through `OptPass789A.HC.Z` (11 optimizer passes),
`BackA.HC.Z`/`BackB.HC.Z`/`BackC.HC.Z` (codegen backends), `Asm*.HC.Z`,
`UAsm.HC.Z`, plus `OpCodes.DD.Z` (a real DolDoc reference). Full
listing: `serial-log-compiler-listing.txt` (39 files,
`test_list_compiler_dir.hc`).

**`FileRead` transparently decompresses `.Z` files** - no separate
decompress step needed. Confirmed by reading `OptPass012.HC.Z`
(36,330 bytes) directly as plain HolyC source text, complete with its
own DolDoc-style inline comments and hyperlink markup
(`test_read_optpass012_head.hc`/`_docs.hc`/`_ic_code.hc`, evidence in
`serial-log-optpass-excerpt.txt`).

This means every future HolyC-quirk investigation in this project no
longer has to be pure black-box test bisection - the actual compiler
source that produces the behavior is sitting on the same disk,
readable the same way any other file is. A genuinely new capability
for this project going forward, not just for the one bug below.

## What this reveals about ADR 0008's open Fossil.HC question

`OptPass012.HC`'s own header comment documents its passes directly:

> Pass#0: ...determine the type of the expression...
> Pass#1&2: Constant expressions are simplified. Eliminated opcodes
> are set to NOP. Types are determined by reconstructing an
> expression tree for operators.

Reading further into Pass#1&2's actual code (`ic_flags`, `ic_class`,
`ic_code` fields on an intermediate-code node `tmpi`, calls like
`OptSetNOP1(tmpi)`) confirms this compiler runs a real
constant-folding / dead-code-elimination pass over an intermediate
representation before codegen - exactly the class of optimization
whose known failure mode is "a later use of a value changes whether an
earlier computation of it gets folded away or kept," which matches
ADR 0008's own precisely-bisected trigger: calling `FossilChecksum`
again later, **using its result**, flips an *already-computed-and-
printed* earlier `FossilDeltaApply` result. That's no longer an
unexplained "genuine code-generation-level effect" with no further
lead - it's now a specific, named optimizer stage (`OptPass012`'s
Pass#1&2, or one of the later numbered passes) with real, readable
source, not a black box.

## What would justify calling this actually root-caused

Reading `OptPass012.HC`/`OptPass3.HC` through `OptPass789A.HC` and
`BackA/B/C.HC` in full, tracing the specific intermediate-code nodes
`FossilDeltaApply`'s own checksum verification and the extra
`FossilChecksum` call would produce, and confirming which pass merges
or eliminates which node depending on the later call's presence. That
is a real, substantial reverse-engineering task - deliberately not
attempted in full here (~36KB in this one file alone, 10 more files in
the same family) - logged as a concrete next step with a real, named
starting point, rather than pushed further in this session.

## Not yet done

- The specific opcode-level trace connecting `OptPass012`'s documented
  behavior to `Fossil.HC`'s own exact bug was not completed.
- The other 10 compiler-internals files (`OptPass3` through
  `OptPass789A`, `BackA/B/C`, `Asm*`) were found and listed but not
  read.
- `Fossil.HC` remains **not** wired into `tools/build-package.sh` or
  any real command - this probe changes the *investigability* of the
  open question, not its resolution.

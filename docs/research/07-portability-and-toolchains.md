# Portability and external HolyC toolchains

## holyc-parser (found via templeos-devkit, not the original brief's list) — the strongest evidence-backed option so far

Source: `experiments/templeos-devkit/holyc-parser/` (Rust; cloned and read
directly — `Cargo.toml`, `src/lex/`, `src/parse/`, `docs/lex-spec.md`,
`docs/parse-spec.md`, `tests/corpus/`). Not mentioned in the original
research brief — found by actually reading the devkit repo rather than
stopping at its README. This is a from-scratch lexer/parser/symbol
resolver/linter for HolyC, distinguishing itself from `holyc-lang` in one
important way: **it doesn't just claim compatibility, it ships evidence**.

- 210 fixture snippets in `tests/corpus/{passing,failing}/`, each with an
  `.expected` file, organized by category (`atom-`, `expr-`, `stmt-`,
  `decl-`, `bug-compat-`, `errors-`, `surprises-`).
- `bug-compat-*` snippets encode *specific numbered bugs in the real
  TempleOS compiler* that the port deliberately reproduces rather than
  "fixes" (e.g. `bug51-toplevel-return`, `bug54-for-decl-filescope`,
  `bug511-switch-range-huge`) — meaning someone already did the work of
  finding real TempleOS/ZealOS compiler quirks and encoding them as
  regression tests.
- `tests/corpus/surprises.md` documents 5 concrete VM-vs-written-spec
  divergences, each reproduced against the actual running VM (not
  inferred), with a hypothesis for the parser-internal cause and a
  `src/Compiler/...` pointer where relevant. Aggregate: "5 surprises
  across 210 snippets ≈ 2.4%" — i.e. the spec is quite accurate, with a
  short, enumerated, evidence-backed exception list.

This is a parser/linter, not a full compiler+codegen — it cannot itself
run HolyC. What it *does* give hgit: a fast, dependency-light, host-side
way to catch syntax errors and boot-phase-class quirks in HolyC source
**before** paying the ~1-minute QEMU round-trip cost, which is exactly
what its own `holyc-lint.py`/linter integration is for in the devkit.

## holyc-lang (from the original brief — still only partially verified)

Source: `holyc-lang.com` homepage only; the actual repo
(`github.com/Jamesbarford/holyc-lang`) has not yet been cloned and read.
Confirmed from the homepage: compiles HolyC to **x86_64 assembly** (AOT,
not JIT), positioned explicitly for running/testing HolyC outside
TempleOS, C-interop capable. Still unconfirmed: platform matrix, exact
HolyC subset, license. Given `holyc-parser`'s corpus-backed evidence is
now in hand, `holyc-lang` is now the *second* priority for the "can we
actually run/compile HolyC on the host" question, not the first — worth
checking primarily for whether it can produce a runnable binary (which
`holyc-parser`, being parse/lint-only, cannot).

## `holyc-parser` actually adopted into this project's own workflow

Doc 07 recommended a "host-side lint + QEMU ground truth" two-tier
loop early on but never actually built it - `tools/lint-package.sh`
now does. Built `holyc-parser`'s own CLI (`holycc`, `cargo build
--release`, no license issue - `Cargo.toml` says `Unlicense`, public
domain) and ran it directly against this project's real, full 23-file
`hgit-core`+`hgit-cli` corpus:

- Linting the raw source directories (unordered) produced **60 false
  positives** - almost all "unresolved identifier," because the tool
  enforces the same "no forward declarations" rule real HolyC has
  (independently confirmed the hard way in this project,
  `docs/research/01-templeos-holyc.md`) across the whole file set in
  whatever order they're given.
- Linting `packaging/HgitAll.HC` directly - the same dependency-ordered
  concatenation `tools/build-package.sh` already produces - collapsed
  that to **exactly 8 findings, all real gaps in the tool's own
  built-ins manifest** (`FilesFind`/`DirTreeDel`/`cnts` - genuine
  TempleOS kernel globals this parser doesn't know about yet), **zero
  real errors** in hgit's own source. `tools/lint-package.sh` wraps
  this, filtering the three known manifest gaps out of its pass/fail
  decision.
- Verified the tool actually catches real problems, not just always
  passing: injected a variable named `pi` into a throwaway copy and it
  reported `[reserved-name-collision]` - the *exact* `pi`-is-a-
  reserved-constant quirk this project found the hard way in probe 41,
  with a message good enough to have shortened that investigation from
  several QEMU round-trips to instant. Also injected the "two sibling
  blocks declaring the same local name" quirk (probe 40/41's own
  "Duplicate member" finding) and got a `[block-shared-scope]` warning
  with an accurate root-cause explanation.
- **A real, honestly-confirmed gap**: injected a bare `continue;`
  inside a `for` loop (the quirk probe 56 found - HolyC has no
  `continue` keyword) and the linter reported **nothing at all**, even
  though its own `docs/parse-spec.md` (§5.2) explicitly documents that
  HolyC lacks `continue`. The knowledge is in the tool's own spec docs
  but not wired into `holycc lint`'s actual rule set - a real limit on
  what this tool currently catches, not something to oversell.

**Adopted as standing practice**: run `bash tools/lint-package.sh`
after every `bash tools/build-package.sh`, before pushing new/changed
source to QEMU - catches a real, non-trivial class of errors (name
collisions, cross-file reference mistakes, the no-forward-declarations
rule) in under a second, for free, without spending the ~1-minute QEMU
round trip. Does not replace QEMU verification - it has no coverage
for `continue`, no runtime/execution checking at all, and its built-ins
manifest is incomplete - but it's a real, verified net time-saver for
the class of errors it does catch.

## Unresolved risk

- `holyc-parser` cannot execute anything — it only validates syntax/basic
  semantics. hgit-core development still needs either (a) a real
  TempleOS/ZealOS target (proven reachable, see doc 08) for ground-truth
  execution, or (b) a working `holyc-lang` (or similar) AOT path for fast
  host-side execution. Neither fully replaces the other; probe 01 shows
  the QEMU path works end-to-end today, so it's the not-blocked option.
- `holycc lint`'s own rule set has real, confirmed gaps (no `continue`-
  keyword check, despite the tool's own docs knowing about it; an
  incomplete built-ins manifest) - it complements QEMU verification,
  it doesn't replace it.
- License unconfirmed for `holyc-lang` (unlike `holyc-parser`, whose
  `Unlicense` was checked directly, `holyc-lang`'s own license was
  never actually confirmed) before depending on it for hgit's own
  tooling.

## Architectural implications so far

- **Done, not just recommended**: `tools/lint-package.sh` adopts the
  two-tier dev-loop model — host-side lint (`holycc lint`, built from
  `experiments/templeos-devkit/holyc-parser/`) + QEMU ground truth
  (unchanged) — verified against this project's own real 23-file
  corpus with zero real errors, and confirmed to actually catch real
  problems (the `pi` and "Duplicate member" quirks specifically), with
  its own honestly-documented gaps (no `continue` check).
- `hgit-core`'s HolyC should be written against the **documented, real**
  quirk list (boot-phase restrictions, the `for`/`switch`/`class`
  surprises, the ~256-char REPL line limit) rather than assumed C-like
  behavior — these are no longer inferred, they're evidenced.

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

## Unresolved risk

- `holyc-parser` cannot execute anything — it only validates syntax/basic
  semantics. hgit-core development still needs either (a) a real
  TempleOS/ZealOS target (proven reachable, see doc 08) for ground-truth
  execution, or (b) a working `holyc-lang` (or similar) AOT path for fast
  host-side execution. Neither fully replaces the other; probe 01 shows
  the QEMU path works end-to-end today, so it's the not-blocked option.
- License unconfirmed for both `holyc-parser` (check `templeos-devkit`'s
  own license — the parser lives inside that repo, not a separate one)
  and `holyc-lang`, before depending on either for hgit's own tooling.

## Architectural implications so far

- Adopt a two-tier dev-loop model, now that both tiers have real evidence
  behind them: **host-side lint** (via something like `holyc-parser`, for
  fast syntax/quirk feedback) **+ QEMU ground truth** (proven in probe
  01, for actual execution and compile-error capture) — mirroring
  exactly what `templeos-devkit`'s own `make lint` / `make repl` split
  already does, not a novel design.
- `hgit-core`'s HolyC should be written against the **documented, real**
  quirk list (boot-phase restrictions, the `for`/`switch`/`class`
  surprises, the ~256-char REPL line limit) rather than assumed C-like
  behavior — these are no longer inferred, they're evidenced.

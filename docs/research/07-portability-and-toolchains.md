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

## holyc-lang (from the original brief — now actually read, not just the homepage)

Source: `github.com/Jamesbarford/holyc-lang`'s own real README (fetched
2026-09-14, not the marketing homepage this doc previously stopped at).
Real, confirmed facts:

- **License**: BSD-2-Clause (permissive, no copyleft concern for hgit).
- **Platforms**: real cross-platform support - Linux (x86_64) and macOS
  (Intel and M1) directly tested per the README's own words ("tested on
  amd linux and an intel mac. An M1 mac and fedora linux on an M4 using
  QEMU"), plus Windows via WSL2. Targets both x86_64 AND AArch64 -
  genuinely broader host coverage than this project has needed so far.
- **Produces real, runnable native binaries** - an AOT compiler (uses
  `clang` internally to assemble/link), plus a real JIT mode (`hcc
  -jit`). This is the one real capability `holyc-parser` (lint/parse
  only) cannot offer - a way to actually EXECUTE HolyC on the host,
  not just catch syntax errors before the QEMU round trip.
- **Real, active project**: 1.2k stars, 75 forks, 222 commits, ongoing
  development (19 open issues, 4 open PRs at fetch time) - not
  abandoned or purely aspirational.
- **A real, significant caveat this doc didn't know before**:
  `holyc-lang` is NOT a strict, bug-compatible reimplementation of
  TempleOS's own real HolyC - it's an extended superset, adding
  `auto`, `typeof()`, range-based `for`, and a `#link` directive beyond
  what real TempleOS HolyC has. Its own README admits real rough edges
  too: "The Compiler is in a working state and most features are
  implemented. Errors are a bit hit and miss!" This is the opposite
  design stance from `holyc-parser`'s own explicit `bug-compat-*`
  corpus (which deliberately REPRODUCES real TempleOS compiler quirks
  as regression tests) - `holyc-lang` extending the language is a real,
  useful capability for its own stated goal (host-side HolyC
  development), but a real, unverified compatibility risk specifically
  for hgit's own source, which is written against and tested for real
  TempleOS's own quirks (the `pi` reserved-constant collision, the
  "duplicate member" sibling-block-scope rule, postfix typecasts,
  `continue` not being a keyword, and more - all documented in doc 01
  and this project's own `failed-approaches.md`). No real test has
  been run to confirm hgit's own actual source compiles correctly (or
  at all) under `holyc-lang` - a real, separate, not-yet-done
  experiment, not assumed either way.

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

**Now also automated in real CI** (2026-09-14,
`.github/workflows/lint.yml`): this project had no CI at all until
now, despite the lint step above being cheap, fast, and QEMU-free -
exactly the kind of check that belongs in CI rather than only being
run by hand. A real, previously-undocumented wrinkle the workflow had
to account for: `holyc-parser` (via `experiments/templeos-devkit/`) is
deliberately NOT vendored into hgit's own git history (see
`.gitignore`'s own comment) - so unlike checking out this repo itself,
CI needs a separate step to clone `github.com/rshtirmer/templeos-devkit`
before `tools/lint-package.sh` can run at all. The workflow also
rebuilds `packaging/HgitAll.HC` fresh and fails if that differs from
what's committed - catching the real, human mistake this project has
always relied on itself remembering not to make (changing source
without rebuilding the package before committing). Does not attempt
real QEMU verification in CI - genuinely more plausible than it first
looks (TCG-only boot, no KVM needed, a small 17MB ISO - see doc 08's
own "Not yet done" #5 for the real, evidence-backed feasibility note),
but real, non-trivial infrastructure (a persistent disk-image caching
strategy across ephemeral CI runners, visual-not-just-text install
automation) makes it a genuinely separate, larger project, not
something to bolt onto this workflow - this closes only the host-side
half of the gap, deliberately.
**Verified with a real run, not just a green checkmark**: the
workflow's first-ever run (`gh run view`, run id `34818692577`)
genuinely cloned `templeos-devkit` fresh, built `holycc` via `cargo
build --release`, rebuilt `packaging/HgitAll.HC` from source, confirmed
it matched the already-committed file, and ran the real lint pass -
`lint-package.sh: no real errors (only the three known built-in-manifest
gaps, if any) - safe to push`, the exact same output this project's own
local runs already produce, now happening automatically.

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
- ~~License unconfirmed for `holyc-lang`~~ **Resolved** (2026-09-14):
  BSD-2-Clause, confirmed directly from the real repo, not the
  homepage - permissive, no real concern for hgit's own tooling if
  ever adopted.
- **Real, still-open compatibility question**: `holyc-lang` is
  confirmed to produce real, runnable native binaries (AOT via
  `clang`, plus a JIT mode) - a real capability `holyc-parser` cannot
  offer. But it's an extended superset of real TempleOS HolyC (adds
  `auto`/`typeof()`/range-`for`/`#link`), not a bug-compatible
  reimplementation the way `holyc-parser`'s own corpus deliberately
  is - whether hgit's own real source (written and tested against
  real TempleOS's own specific quirks) actually compiles correctly
  under it is genuinely unverified, not assumed either way. A real,
  separate experiment (build hgit's own package under `holyc-lang`,
  compare behavior against the real QEMU ground truth) would be needed
  before trusting it for anything beyond exploratory host-side
  development - not attempted here, no evidence yet that the existing
  two-tier lint+QEMU workflow has a real gap this would close.

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

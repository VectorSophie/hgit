# QEMU testing

## Experimental evidence — probe 00 (boot)

Full detail: `experiments/00-qemu-boot/`. Official TempleOS 5.03 ISO boots
to a fully usable live desktop under `qemu-system-x86_64` 8.2.2 (TCG, no
KVM, `-m 512`, `-display none` + HMP `screendump` for headless
verification) on this host, in well under 15 seconds, with zero patches.

## Experimental evidence — probe 01 (install + injection + capture, reproduced end to end)

Full detail: `experiments/01-temple-repl/`. This closes the rest of the
brief's probe #6/#7/#8: not just boot, but **scripted install onto a
persistent disk, scripted keyboard bootstrap of an in-guest daemon, raw
HolyC source injected over a COM2 socket, JIT-compiled and executed
natively inside TempleOS, and its output round-tripped back to a
host-readable file** — with zero human interaction anywhere in the loop.
The concrete result, verbatim from the host's `serial.log` after pushing
one HolyC statement over COM2:

```
D_OK
PASS hgit_probe_canonical_encoding
D_DONE
```

This is a live, working instance of the brief's own
`HGIT_TEST_BEGIN`/`PASS ...`/`HGIT_TEST_EXIT` protocol shape — proven,
not just designed. Two real quirks surfaced during reproduction (typing
too soon after boot reproduces a "still in boot phase" failure even at
the fully interactive prompt; a bare top-level statement pushed through
a live `ExePutS` loop can fail to resolve a symbol that resolves fine
inside a function body through the identical mechanism) — see
`experiments/01-temple-repl/README.md` and `failed-approaches.md` for
detail. Neither blocks the core finding.

## Verified documentation / facts confirmed in source — prior art

Source: `github.com/rshtirmer/templeos-devkit` (cloned into
`experiments/templeos-devkit/`, not just its README — actually read
`Daemon.ZC`, `scripts/temple-run.py`, `scripts/send.py`, `NOTES.md`,
`CLAUDE.md`). This turned out to be a full, previously-debugged reference
implementation of almost exactly the harness M0 needs, built by someone
(another Claude instance, per its own README: "I (Claude) write HolyC
less reliably than I write Python") who already fought through the same
problems. Load-bearing facts, all confirmed by reading the actual
scripts/source rather than inferring from prose:

- **FAT32-shuttle injection genuinely doesn't work on stock TempleOS.**
  Confirmed reason, not just assertion: TempleOS's FAT32-on-secondary-IDE
  read path is unreliable, and mounting the CD as an extra data source
  gives `File System Not Supported`. The devkit's fix — push raw bytes
  over a COM2 chardev socket, `ExePutS()` to JIT-compile in memory — is
  what probe 01 reproduced successfully.
- **The interactive command line has a ~256-char per-line buffer.** This
  is why the daemon bootstrap is typed in small pieces (via `sendkey`,
  which *is* line-buffer-limited) and only the daemon body itself — once
  alive and reading from COM2 — has no such limit, since `ExePutS` on an
  already-assembled in-memory buffer bypasses the typed-line path
  entirely.
- **Two-stage daemon design, with a real architectural reason, not just
  caution:** stage-1 (`D()`) is minimal and typed in via keystrokes
  (small enough to survive the line-buffer limit); stage-2 (`D2()`/
  `_DRun()`, which adds `Fs->put_doc` redirection to capture compiler
  error text instead of letting it hit the framebuffer) is *pushed* as
  one large chunk over the already-working stage-1 channel — sidestepping
  the line-buffer limit entirely for the larger payload.
- **`ExePutS`'s error-reporting mechanism**: on a parse/compile failure it
  sets `Fs->catch_except = TRUE` and routes lexer error text through
  `Fs->put_doc`, which is redirectable to an in-memory `CDoc` instead of
  the screen. This is the actual mechanism, not a guess — confirmed by
  reading `Daemon.ZC`'s `_DRun`-equivalent code, which does exactly this
  redirect-capture-restore dance around every pushed chunk.
- **Boot-phase parser restrictions are real and documented with
  reproducers** (`NOTES.md`): top-level `for(;;)`, `goto`+label, and
  `return` inside a function invoked from boot-phase (`MakeHome.ZC`
  context) all fail with specific, named errors, traced to
  `src/Compiler/ParseStatement.ZC` and `src/Compiler/CExcept.ZC` in
  ZealOS's own source. Workarounds that do compile: `Sys("source")`
  (queues for post-boot execution on `sys_task`) and `Once("source")`
  (persists to `~/Registry.ZC`, runs at first user term). **Directly
  relevant to hgit's own AOT-executable-vs-cmd-line open question from
  doc 01** — `Sys()`/`Once()` are exactly the kind of deferred-execution
  primitive an AOT `hgit` binary's startup sequence might need to
  understand if it's ever invoked from a boot-phase context.
- **`holyc-parser`** (in the same repo, `experiments/templeos-devkit/holyc-parser/`):
  a from-scratch Rust lexer/parser for HolyC, with its own grammar docs
  (`docs/lex-spec.md`, `docs/parse-spec.md`) and — critically — a
  210-snippet corpus (`tests/corpus/{passing,failing}/`) cross-validated
  against the real TempleOS VM, including a `surprises.md` documenting 5
  concrete places the real VM disagrees with the written spec (e.g.
  `for (I64 i=0; …)` is rejected at function scope too, not just file
  scope; `class C { I64 x }` without a trailing `;` is accepted). This is
  a substantially better-grounded answer to doc 07's "host-side toolchain"
  question than `holyc-lang`'s marketing page — see doc 07's update.

Host requirements: `qemu-system-x86_64`, `python3` (stdlib only —
`socket`, no extra deps), `curl`/`qemu-img`. The devkit's own README is
macOS-flavored (`hdiutil`, `brew`, AppleScript window resize) but every
piece actually exercised in probe 01 (`send.py`, `temple-run.py`'s
protocol, the QEMU flags themselves) is platform-agnostic and worked
unmodified on this Linux host.

## Not yet done (next QEMU-track probes, in order)

1. Snapshot-based fast iteration (`qemu-img`/monitor `savevm`/`loadvm`) —
   the devkit's `vm-warmup`/`vm-revert` pattern — to remove the ~1-minute
   boot-and-settle tax per probe before doing repeated HolyC experiments.
2. Actually exercise the `COMPILE_FAIL` capture path (stage-2's whole
   purpose) — probe 01 defined it but never got a failing chunk through
   it, due to the exit-handshake quirk. Retry with a full reboot between
   stage-1 and stage-2 instead of the in-place `_D_exit` toggle.
3. Wire the proven `D_OK`/`PASS ...`/`D_DONE` pattern into the brief's
   exact `HGIT_TEST_BEGIN`/`PASS`/`HGIT_TEST_EXIT:N` contract, with a
   host-side timeout and conventional process exit code — a thin wrapper
   over what's already proven, not new risk.
4. Malformed/adversarial input tests (truncated archive, cyclical delta,
   oversized length field) — deferred until there's an actual decoder to
   attack.
5. **Real QEMU/TempleOS boot-and-test automation in CI** - genuinely
   more plausible than it first looks (2026-09-14 re-check, prompted by
   adding host-side lint CI, `.github/workflows/lint.yml`): probe 00's
   own real finding - TempleOS boots correctly under plain QEMU/TCG, no
   KVM/hardware virtualization needed - is exactly the enabling fact a
   standard GitHub Actions `ubuntu-latest` runner needs (no nested
   virtualization available there either), and the official ISO is a
   small, fast 17MB download. **But not a quick add**, checked honestly
   rather than assumed either way: probe 01's own real install
   automation needs VISUAL screendump-based polling (not just text) to
   drive the installer's own prompts, found a real, empirically-tuned
   timing quirk (a ~45-60s post-boot settle wait, not a fixed sleep) that
   may not transfer cleanly to a CI runner's own different real
   performance characteristics, and - the biggest real blocker - needs a
   PERSISTENT installed disk image to skip re-running that install on
   every single CI run; `*.qcow2` is deliberately gitignored in this
   repo for size reasons, so a real CI version would need its own
   caching strategy for a real, multi-GB artifact, not yet designed or
   sized. A real, well-scoped future project on its own, not something
   to bolt onto the existing lint workflow - logged here with real
   evidence for whoever picks it up next, not attempted in this pass.

## Architectural implications so far

- `hgit-transport`'s "QEMU bridge" should use **serial (COM2) injection**
  as the TempleOS-compatible baseline — now proven, not just planned —
  with FAT32-shuttle-disk injection as a ZealOS-only fast path.
- The test protocol markers from the brief (`HGIT_TEST_BEGIN` etc.) map
  directly onto the now-proven `CommPrint`-over-COM1 pattern. Adopt as
  designed.
- The test harness must include a real idle/ready check before driving
  any scripted input — a fixed sleep is not reliable (probe 01's boot-
  phase-quirk false start).
- `hgit-core`'s error-handling design (doc 01's `throw`/8-byte-literal
  question) now has a second, richer data point: `Fs->catch_except` +
  `Fs->put_doc` redirection is the real mechanism programs use to
  *capture* compiler-level errors — worth understanding before deciding
  how hgit's own error paths should look, since this may be the same
  general exception-capture primitive HolyC application code has access
  to, not just something internal to the compiler.
- **The daemon's own receive buffer has a real, hit-in-practice size
  limit**, found in probe 69: the stage-1/stage-2 `Db` buffer was
  `MAlloc(131072)` (128KB) from this harness's earliest bootstrap, and
  the real hgit package eventually grew past it (133,804 bytes),
  causing a confusing, *reproducible* (not random) truncated-compile
  error deep in otherwise-stable code. Rebootstrapped with 512KB
  (`Db=MAlloc(524288)`, matching `Di<524287` bound in both `D()` and
  `D2()`) - if a future push of a large, still-growing package produces
  a strange parse error in code that's never had problems before, check
  the package's real byte size against the daemon's current buffer size
  before assuming a source bug.

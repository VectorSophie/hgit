# Probe 56 — root-causing and fixing `hgit offer`'s buffer overflow

Status: **PASS** — root-causes the crash flagged as open/unresolved in
probe 55, reproduces it deliberately in isolation (both of its failure
modes), fixes it with a bounds check, and re-verifies against both
reproductions plus a full regression of probe 55's own scenario.

## What this closes

Probe 55 hit a real GPF from `hgit offer *` against ~60 accumulated
files and flagged the root cause as "not fully isolated... a candidate
list of fixed-size buffers." This probe isolates and confirms it, and
fixes it.

## Reproduction 1: many small files → an infinite loop, not a crash

`test_driver_many_files.hc` creates 40 tiny (`"x"`, 1 byte) files and
offers them via a wildcard (`P56F*`). Against the **unfixed**
`Offer.HC`, this reproducibly hung the daemon - no debugger fault (a
screendump showed the stale pre-crash desktop, unchanged across
multiple checks), no `D_DONE`, no further output at all, including to
a follow-up ping pushed to confirm the daemon's own receive loop was
still even alive (it was not responding). **A real, different failure
mode from probe 55's own GPF, from the same underlying bug** - the
overflow corrupts whatever happens to sit next on the stack, and what
that is (a loop pointer vs. something else) decides hang vs. crash.

## Root cause, confirmed by direct calculation

`src/hgit-cli/Offer.HC`'s `HgitOfferWithRelation` builds every offered
file's tree entry into a fixed `U8 tree_content[2048]` stack buffer
with **no bounds check**. Each entry costs
`1 (name_len byte) + name_len + 1 (type) + 64 (hash) + 8 (entity_id)`
bytes - for an 8-character name, ~82 bytes/entry, so `2048/82 ≈ 24`
entries is exactly where it should start overflowing. The 40-file
reproduction's `OFFER_SKIP` log (see below) confirms this precisely:
files 1-23 succeed, file 24 onward are the first to no longer fit -
matching the arithmetic, not just the symptom.

A second, independent fixed buffer has the same problem:
`U8 blob_tagged[512]` (built per-file, holds the type tag + file
content for hashing) silently overflows for any single file whose
content is over 511 bytes - confirmed separately with a dedicated
600-byte file, which the **unfixed** code did not crash on immediately
(different memory layout luck) but is the same class of bug, and
probe 55's original crash scenario likely involved at least one
already-large `.hgs`/`.m` file matched by its own bare `*` mask.

## The fix

Added an early skip (not a silent truncation, not a crash) for either
condition, restructured as `if / else if / else` around the rest of
the per-file loop body rather than an early `continue` - see "harness
lesson" below for why. A file that doesn't fit prints a clear
`OFFER_SKIP file_too_large <name>` or `OFFER_SKIP tree_full <name>`
and is excluded from this offer, rather than corrupting memory.
Deliberately minimal: does not resize the buffers or redesign the
storage scheme (a `find_mask` matching more files than 2048 bytes'
worth of entries can hold is now a clean, visible skip rather than
silent corruption - genuinely fixing the crash without taking on a
buffer-resizing project this fix doesn't need).

## Real HolyC quirk hit while writing the fix: no `continue` keyword

The first attempt used `if (bad) { ...; continue; }` to skip a file.
This was already a **documented, known** quirk in
`experiments/templeos-devkit`'s own bug-compatibility corpus
(`holyc-parser/tests/corpus/failing/007-bug-compat-bug52-continue-keyword.hc`)
that this project hadn't hit directly before - HolyC has no `continue`
keyword, and using it produces the exact same
`ERROR: Undefined identifier at ";"` this probe hit, confirmed by
comparing directly against the corpus file's own expected output.
Fixed by nesting the rest of the loop body in an `else` branch instead
of early-`continue`-ing past the guards - now the standing pattern for
any future per-item skip-and-continue logic in this codebase.

## Verified

- `serial-log-passing-run.txt` — the corrected code's real run: files
  24-39 each produce `OFFER_SKIP tree_full <name>`, then the offer
  still completes (`DISPATCH_OK offer`, `PASS p56b_many_small_files`)
  instead of hanging.
- The same run also re-verified the large-single-file guard
  (`OFFER_SKIP file_too_large C:/Home/P56CBig.txt`, `PASS
  p56c_large_file_skip`) and re-ran probe 55's own original end-to-end
  scenario unchanged (`init`→`offer`→`correct`→`reconciledoc`, all
  `DISPATCH_OK`, `PASS reconciledoc_e2e`) as a regression check - no
  behavior change for the normal case.

## Not yet done

- The third related buffer, `archive[8192]` (the whole growing
  in-memory copy of the repo plus new objects), is not bounds-checked
  here - flagged in `Offer.HC`'s own header comment as a known,
  pre-existing limit, not newly discovered by this probe, and a bigger
  design question (resizing/redesigning the whole append scheme) than
  this fix's scope.
- The exact threshold (2048/512 bytes) is not tunable or reported to
  the caller as a capacity - a real repo with many/large files still
  needs multiple smaller `offer` calls, not one `*` that silently
  drops most of them. Acceptable for now (loud skip beats silent
  corruption), not a final design.

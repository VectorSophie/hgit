# Probe 55 — `hgit reconciledoc`: a real, wired DolDoc reconciliation view

Status: **PASS**, after one genuine crash found, root-caused, and worked
around (not silently avoided) — a new real risk this project didn't
know about before this probe.

## What this closes

Probe 54 confirmed `$LK$` renders as a real link from generated HolyC
output but never wired it into an actual command. This probe does that:
`src/hgit-cli/ReconcileDoc.HC`'s `HgitReconcileDoc(repo_path,
target_hash, doc_path)` builds a `.DD` document for one commit —
its short hash and message, then, if it carries an ADR 0005/0006
relation, a real `$LK$` link tagged with the relation target's full
hex hash, the relation type name, the target commit's own message
(read back from the same archive), and the scoped entity ID if any.
Wired into `Hgit(cmdline)` as `hgit reconciledoc <repo> <commit_hex>
<dest.DD>` (`Hgit.HC`), added to `tools/build-package.sh`'s dependency
order (after `Hex.HC`/`HistoryDoc.HC`, before `See.HC`).

## Real bug found and fixed before this could compile: "Duplicate member" again

`ReconcileDoc.HC`'s first draft reused a local `U8 *m = "...";` in five
separate error-return blocks in one function. Same quirk as probe
40/41's own finding (sibling declarations in one function don't get
separate scope) — except here the five blocks weren't even
if/else-if siblings, just five independent `if { ...; return; }`
blocks in sequence, showing the quirk isn't limited to the
if/else-if shape specifically. Fixed by renaming to `m1`..`m5`.
Also deliberately avoided a function-like `#define` macro tried in an
even earlier draft (untested territory — no other file in this
codebase uses one) in favor of the established explicit-loop style
`HistoryDoc.HC` already uses.

## Real crash found: `hgit offer` with a broad wildcard find_mask against an accumulated directory

The first end-to-end attempt (`P55Test`, not kept as the final test
driver) used `find_mask = "*"` against `C:/Home` after ~54 probes'
worth of leftover files had accumulated there (60+ files: `P36Repo.*`,
`P43Repo.*`, dozens of `P##FileA.txt`, etc.). `hgit offer` walked into
a real **General Protection fault inside `GetU32LE`**, dropping the
whole session into TempleOS's own kernel debugger — not a compile
error, not a graceful failure, a genuine crash. `evidence/gpf-crash-from-wildcard-offer.png`
is the debugger screen (`Fault:0x0D General Protection
RIP:1SBA2093:&GetU32LE+0x001B`).

**Recovery required a full VM reboot** — unlike probe 54's `Ed()`
finding, `sendkey esc` does nothing to a real kernel-fault debugger.
Rebooted from the persistent installed disk (no reinstall needed),
redid the full stage-1→stage-2 daemon bootstrap by hand (this time
correctly, see "harness lesson" below), reloaded `HgitAll.HC`, and
re-ran the test with a specific `find_mask` (`P55BFileA.txt`, naming
one real file) instead of `*` — passed cleanly.

**Root cause not fully isolated** — plausible causes not
distinguished from each other: `WorkDir.HC`'s directory-enumeration
buffer sized for a smaller expected file count, `Offer.HC`'s tree-build
path assuming a bounded entry count, or `Index.HC`'s own fixed-size
`idx_hashes`/`idx_offsets` arrays (`[64*64]`/`[64]` — a hardcoded cap
of 64 *objects*, not 64 *matched working files*, but worth checking
either way) being overrun by a much larger object count than any
previous probe's repository ever held. **Flagged as real, unresolved
follow-up work**, not glossed over: `hgit offer *` against a directory
holding many dozens of files is untested and now known-unsafe until
this is root-caused and fixed. This is a genuine gap in this project's
own test coverage (every prior `offer` probe used a small, deliberately
constructed working directory), not a hypothetical concern.

## Harness lesson: raw `sendkey <string>` doesn't type text

Also found and fixed a mistake in the *recovery* process itself, worth
recording since it wasted real time: `qemu-system-x86_64`'s HMP monitor
`sendkey` command only accepts real key names (`ret`, `esc`, `shift-a`),
not an arbitrary string as one argument — sending
`sendkey "some long command"` silently does nothing (no error, nothing
typed). The correct approach, already built and sitting unused in
`experiments/templeos-devkit/scripts/send.py`, maps each character to
its own `sendkey <name>` call. Re-discovered and used correctly on the
second attempt; recorded here so a future reboot doesn't lose time on
the same mistake.

## Verified

- `serial-log-passing-run.txt` — the real dispatcher sequence:
  `init` → `offer` (single named file, not `*`) → `correct` (with a
  real target hash and unscoped `0000000000000000` entity) →
  `reconciledoc` → `PASS reconciledoc_e2e`.
- `raw-doc-content.txt` — the actual `.DD` bytes read back via
  `FileRead`: correct short hash, correct message, `relation: CORRECTS
  -> $LK,"<full 128-hex target hash>"$<12-char short hash>$LK$`, and
  the target commit's own message (`offer_one`) resolved correctly
  from the same archive.
- `evidence/rendered-reconciliation.png` — the same document open in
  `Ed()`: the relation line's target hash renders underlined (a real
  link), matching probe 54's own finding, now from a real command's
  actual output rather than a hand-written test string.

## Not yet done

- Does not implement following the link (see probe 54's own scoping
  note - `Ed()` blocks the daemon, so this needs a human at the real
  console, not automation, to test click-through).
- The `hgit offer *`-against-many-files crash is unresolved, not just
  undiscovered - a real open risk flagged above, not previously known.
- `$TR$`'s real syntax (probe 54's other open item) still isn't
  resolved; this probe didn't need it.

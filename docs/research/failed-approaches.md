# Failed approaches log

Append-only. Each entry: what was tried, what happened, why it failed,
what worked instead (if anything).

## 2026-09-10 — Direct `curl` download of TempleOS.ISO truncated repeatedly

**Tried:** `curl -sI`/`curl -s -o TempleOS.ISO https://templeos.org/Downloads/TempleOS.ISO`
(both default HTTP/2 and plain).

**Happened:** Connection closed mid-transfer every time, at varying byte
offsets (5.9MB, then 6.9MB after 6 retries with `-C -`), against an
expected 17,350,656-byte file (confirmed via `Content-Length` on a
`--http1.1` HEAD request). Exit code 18 ("transfer closed, N bytes
remaining"), and once exit code 92 (HTTP/2 stream error) on the very first
attempt.

**Why:** Not conclusively diagnosed — consistent with either a flaky
upstream connection or a sandboxed-network per-connection duration/size
cap in this execution environment. Not investigated further since a
workaround was cheap.

**Worked instead:** A loop of many short (`--max-time 6`), resumable
(`-C -`) `curl --http1.1` calls against the same URL, re-checking file size
each iteration until it matched `Content-Length`. Completed in 5 short
hops. If this recurs for larger assets (a future ZealOS ISO, a release
tarball), use the same loop pattern rather than one long-lived transfer.

## 2026-09-10 — holyc-lang.com homepage fetch was too thin to answer real questions

**Tried:** `WebFetch` against `https://holyc-lang.com/` asking for platform
support, HolyC subset coverage, and license.

**Happened:** The fetched page (apparently a marketing/landing page, not
docs) didn't contain that information — the tool honestly reported it
couldn't answer rather than guessing.

**Why:** Landing pages summarize, they don't specify. Should have gone
straight to the GitHub repo (README + LICENSE file) instead.

**Not yet worked around:** doc 07 is marked partial pending an actual repo
read — noted here so the gap isn't silently forgotten.

## 2026-09-10 — Typed daemon bootstrap immediately after reaching the TempleOS desktop failed with boot-phase-style errors

**Tried:** Booted the freshly-installed disk, selected Drive C at the
bootloader, waited ~6s, then typed `templeos-devkit`'s `BOOTSTRAP_CMDS`
(4 short HolyC statements) via QEMU monitor `sendkey`.

**Happened:** Real TempleOS Debugger faults — "Note: Still in boot
phase", "Undefined identifier" — on code that is plain, correct HolyC
(confirmed by the *identical* keystrokes compiling cleanly one attempt
later). Screenshots show garbled/interleaved text suggestive of either
dropped keystrokes or genuine boot-phase restrictions still in effect at
the interactive prompt.

**Why:** Not conclusively isolated between two candidates: (a) background
first-boot housekeeping ("Uncompressing Dictionary", tip-of-the-day
popups) still running and the system not fully out of a boot-phase-like
state, or (b) `sendkey` timing/keystroke loss under `-display none`
headless mode specifically. Not worth root-causing further — the
workaround is cheap and the actual cause doesn't change hgit's design.

**Worked instead:** Rebooted clean, waited a full ~45-60s after reaching
the desktop prompt (through the tip-of-the-day and any tour prompt)
before typing anything. Identical commands then compiled with zero
errors. **Rule for any future scripted TempleOS interaction: don't drive
input on a fixed short timer — wait for genuine idle, or budget ~60s
after first reaching an interactive prompt.**

## 2026-09-10 — Stage-1→stage-2 daemon exit handshake never completed (`_D_exit=TRUE;` push)

**Tried:** Following `temple-run.py`'s documented protocol exactly: push
`_D_exit=TRUE;` as a bare statement over the already-working COM2 channel
to break the stage-1 daemon's `while(!_D_exit)` loop, expecting a
`D_EXIT` marker.

**Happened:** The push registered (a `D_DONE` did appear, and the
screen showed an `ERROR: Undefined identifier` referencing the pushed
line), but `_D_exit` was apparently never actually set to `TRUE` — no
`D_EXIT` ever appeared, even after retrying with slower, per-byte-paced
delivery (which did produce a cleaner, single `D_DONE` with the same
underlying error visible on screen).

**Why:** Unconfirmed. `_D_exit` compiles fine when referenced *inside* a
function body pushed through the same `ExePutS` mechanism (stage-2's
`D2()` source, pushed just before this, defined without error). The
failure is specific to a bare top-level assignment statement referencing
it. Possibly a HolyC identifier-resolution difference between
immediately-executed top-level code and deferred function-body code, but
this is a hypothesis, not a verified cause.

**Not yet worked around:** Left open rather than chased — it's a
refinement of an already-answered question (probe 01's core finding,
injection + capture, was already proven via the stage-1 path alone), not
the feasibility question itself. Next attempt should try a full VM
reboot between stage-1 and stage-2 instead of the in-place exit/restart,
or investigate whether `Sys("_D_exit=TRUE;")` (deferred execution,
confirmed elsewhere to behave differently from immediate execution)
succeeds where the bare push didn't.

## 2026-09-12 — C-style prefix typecast rejected by the real compiler

**Tried:** `(U32)buf[off+3]` inside a canonical-decode helper
(`experiments/03-canonical-encoding/`), pushed via the proven COM2
injection channel.

**Happened:** Compile error: `ERROR: Use PostFix typecast(eg 'U32')`.

**Why:** HolyC doesn't have C's prefix typecast syntax at all — it's
postfix-only (`value(Type)`).

**Worked instead:** Rewrote as `buf[off+3](U32)`, confirmed against
`holyc-parser`'s validated corpus entry
`079-expr-expr-postfix-typecast.hc` rather than guessing a second time.
Cheap fix, but cost a full QEMU round trip to discover — worth
running new hgit-core source through `holyc-parser`'s lint *before*
pushing it into the VM, to catch exactly this class of mistake for free.

## 2026-09-12 — `U32`-returning function silently leaked garbage high bits

**Tried:** A `GetU32LE` function declared `U32` return type, computed by
OR-ing shifted `U8` bytes together (including one postfix-cast to widen
before the final `<<24` shift), then compared against a 32-bit literal.

**Happened:** The comparison failed. A diagnostic print showed the
*correct* low 32 bits followed immediately by ~20 bits of unrelated
garbage — i.e., the function's declared `U32` return type was not
enforced; the actual value returned was wider than 32 bits.

**Why:** This HolyC implementation does not appear to truncate/mask a
function's return value to its declared width automatically — the
caller receives whatever the underlying (likely 64-bit) register held.
Not confirmed against original compiler source, only against this
observed behavior.

**Worked instead:** Accumulate into a `U64` local and explicitly
`& 0xFFFFFFFF` before `return`. Confirmed via an isolated diagnostic push
before rolling the fix into the full round-trip. **This is now a
standing rule for all of `hgit-core`, documented directly in
`src/hgit-core/Canon.HC`: never trust a narrow return type to mask
itself — always mask explicitly at every width boundary.**

## 2026-09-12 — Bare top-level `while` loop silently corrupted local variables (not a boot-phase error, a silent wrong-result bug)

**Tried:** A verification loop for the tiny-archive probe
(`experiments/05-tiny-archive/`) written as a bare top-level statement:
`I64 pos=0...; while (pos < read_size) { U64 len=...; U8 recomputed[64];
B2Hash512(...); ...; }`.

**Happened:** No compile error at all. The loop ran, printed plausible-
looking values for `len`/`pos` (correct!), but the hash comparison
failed for every record. A diagnostic print showed `recomputed[0]` held
the first byte of BLAKE2b("abc")'s digest — a value that appears nowhere
in this test's actual data — while an *otherwise identical* manual check
done outside any loop, on the same underlying data, computed the correct
hash and matched.

**Why:** Not root-caused to compiler internals, but conclusively
isolated by elimination: ruled out local-variable-argument passing (a
separate test called the same function with local pointer/length
variables outside a loop and got the right answer), ruled out `FileRead`
data corruption (raw bytes read back correctly when printed directly).
The one variable that changed was "loop declares locals at bare top
level" vs. "same logic inside a real function."

**Worked instead:** Moved the identical loop body into a real
`U0 ArchiveVerify(...) { while (...) { ... } }` function. Passed cleanly
on the same data. **Rule now enforced project-wide in
`src/hgit-core/Archive.HC`'s comments: any loop declaring its own locals
must live inside a real function, never as a bare top-level statement —
regardless of boot phase.** This generalizes the previously-known
boot-phase-only top-level-loop restriction (doc 01/08) to a broader,
silent-failure-mode caution that applies even in ordinary post-boot
execution — and is more dangerous precisely because it doesn't error.

## 2026-09-12 — BLAKE2b test vector typed from memory was wrong

**Tried:** Hand-typed a third BLAKE2b-512 test vector (unkeyed hash of
the empty string) into `experiments/02-blake2b-oracle/oracle.py` from
memory, alongside one just fetched from RFC 7693.

**Happened:** `oracle.py` reported FAIL. The computed and expected hex
strings *looked* identical at a glance (same first 16 characters) but
differed in length — 128 hex chars computed vs. 126 typed — a
one-byte-short transcription.

**Why:** Recalled the value from memory instead of fetching it from a
primary source, and truncated it slightly when typing it out.

**Worked instead:** Dropped the untyped-from-memory vector entirely and
fetched a real one (the official BLAKE2 KAT file's first entry — a
*keyed* empty-string hash, different from what was attempted) via
`WebFetch`, then verified it independently before trusting it. **Rule
reinforced: any cryptographic constant "recalled from memory" is
unverified until fetched from a primary source, no matter how confident
it looks** — this is exactly the class of mistake the brief's "use
official vectors" instruction exists to prevent, and it nearly slipped
through anyway.

## 2026-09-13 — Hand-computed byte offset crashed the guest (General Protection fault)

**Tried:** In `experiments/12-index/`, located a tree object inside a
reloaded archive buffer by manually adding up expected record sizes
(`16-byte header + 5+8+64 bytes per blob record × 2`) instead of using
the index being built in the same test.

**Happened:** Real TempleOS Debugger fault: `Fault 0x0E General
Protection`, `RIP:...:&TreeFindEntry+0x315F`. The daemon didn't recover
afterward — pinging it over COM2 got no response; a full VM reboot and
re-bootstrap was required to continue.

**Why:** The manual arithmetic assumed each blob record was 77 bytes
(8 length + 5 data + 64 hash), forgetting that `ObjectPut` prepends a
1-byte type tag before the data is ever stored — actual record size is
78 bytes. The resulting pointer was 2 bytes into the next record's
bytes, so `TreeFindEntry` read a garbage `name_len` and walked far past
any valid buffer, corrupting memory badly enough to fault.

**Worked instead:** Rewrote the test to never hand-compute an offset at
all — every object's location comes from `IndexLookup`, and every
object's length comes from its own stored length field via `GetU64LE`,
not a remembered variable. This isn't just a bugfix, it's the actual
point of building an index: **the moment there are two probes'-worth of
prior context to keep straight (header size, per-record overhead, a
prepended tag byte), hand-tracking offsets stops being reliable.**
`src/hgit-core/Index.HC` exists specifically so nothing has to do this
arithmetic by hand again.

## 2026-09-13 — Typed bootstrap into an undismissed "Take Tour" prompt, twice in a row

**Tried:** After booting for `experiments/15-dir-enumeration/`, glanced
at a screendump, judged the screen "idle enough," and typed the full
daemon bootstrap sequence without re-confirming a live `C:/Home>` prompt
was actually showing.

**Happened:** Cascading compile errors (`Undefined identifier`) sourced
from `::/Doc/Comm.HC.Z` itself — a file that had `#include`d cleanly
dozens of times in every prior probe. Retried once more from what
looked like a recovered prompt; failed identically again.

**Why:** Re-examining the screendump that had been judged "idle"
straight after taking it — not after acting on it — showed it was
actually still sitting at `Take Tour (y or n)? ■`, not the command
line. Both bootstrap attempts were typed into that prompt's input
context, not the interpreter, garbling everything downstream. This
wasn't a new HolyC/TempleOS quirk at all — it was reading a screenshot
too quickly and trusting a snap judgment ("looks idle") over actually
checking for the specific known prompt text.

**Worked instead:** Full VM reboot, and this time reading the
screendump for the literal prompt text before typing anything — not a
vibe check. Identical bootstrap sequence worked immediately.
**Rule reinforced, again: never drive scripted input off an assumption
about screen state — read the actual expected text (a specific prompt
string, or a specific idle marker) every time, no shortcuts, even after
this has already worked dozens of times in a row.**

## 2026-09-13 — Repeated probe 12's index-offset mistake while building `hgit history`

**Tried:** `HgitHistory`'s first version took `IndexLookup`'s returned
offset and used it directly as an index into the full `.HGS` file
buffer (`rbuf[off+8]`).

**Happened:** `HISTORY_ERR not_a_commit` — the byte at that position
wasn't a valid type tag. A diagnostic dump showed outright garbage at
the looked-up offset.

**Why:** This is the *identical* mistake logged for probe 12: `IndexBuild`
records offsets relative to whatever buffer it was handed
(`rbuf+16`, the object section — the 16-byte `.HGS` header excluded),
not the whole file. Despite that already being written up in this very
file, it was made again, fresh, while writing new code that used the
same index.

**Worked instead:** The same one-line fix as probe 12
(`I64 off = 16 + off_rel;`), this time written directly into
`History.HC`'s own source comments at the point of use, not only in
this research doc. **Lesson about the lesson**: documenting a mistake
in a separate research file didn't prevent repeating it in new code —
the fix that actually sticks is the one placed at the exact call site
where the mistake is possible, where the next reader (human or a future
version of this same agent) hits the warning before hitting the bug,
not after.

## 2026-09-13 — Same-named locals in sibling `else if` branches: "Duplicate member"

**Tried:** Extending `Hgit()`'s dispatcher (`experiments/24-hgit-dispatch-more/`)
with a `history` branch that declared `U8 repo_path[256];` — the same
name already declared in the earlier `status` branch of the same
function, inside a different `else if` block.

**Happened:** Compile error: `ERROR: Duplicate member at ';'`. No test
output at all for that push; a screendump was needed to find the
error.

**Why:** In C, `if`/`else if` blocks are separate scopes, so reusing a
local variable's name across sibling branches is completely normal and
common. HolyC does not appear to treat `if`/`else if` branches within
one function as separate scopes for this purpose — both declarations
apparently land in one flat per-function namespace, so the second one
collides with the first even though the two branches are mutually
exclusive and the variable is never live in both.

**Worked instead:** Renamed the second declaration to a distinct name
(`hist_repo_path`). Compiled and ran correctly. **Rule now recorded
directly in `Hgit.HC`'s own comments (not only here): every branch's
locals need distinctly-named variables in HolyC — don't assume
`if`/`else if` blocks give a fresh scope the way they do in C.**

## 2026-09-13 — Long multi-push daemon session produced a silent no-output failure — ~~not fully root-caused~~ **CORRECTED below, see probe 27**

**Tried:** While building `experiments/26-hgit-see-dispatch/`, reused an
already-running daemon session across several pushes, re-including some
files inconsistently between them (one push omitted `Init.HC` and
correctly errored; the next included it and compiled, but a separate
push after that produced zero output from new test code with no
compile error either — the code simply appeared not to run, or ran
without any of its `CommPrint` calls landing in the log).

**Happened:** No error, no crash, no test output.

**Why (original, wrong, guess):** Speculated the cause was redefining
several already-loaded top-level test variables/functions a second
time, inconsistently, across a long sequence of pushes in one daemon
session — logged as an unconfirmed hypothesis.

**Why (actual, confirmed in probe 27):** That guess was wrong. Building
`experiments/27-hgit-offer-dispatch/` hit the *identical* silent
symptom **on a freshly rebooted, single-push session** — ruling out any
session-history effect entirely, since there was no prior push to
interfere. The real, confirmed cause: `Hgit()`'s dispatcher compiles
all its `if`/`else if` branches as one function body, so HolyC must
resolve every symbol *any* branch calls at compile time — testing one
command still requires every other branch's dependencies present
(`Init.HC`, `Status.HC`+`WorkDir.HC`, `History.HC`, `See.HC`+`Hex.HC`,
`Offer.HC` — all of them, every time). The silent-no-output case in
probe 27 was simply one more missing file (`Status.HC`) that hadn't
produced a *visible* screen error yet when first checked; a second
screendump found the real `Compiler Parse Error at 'HgitStatus'`.
Probe 26 almost certainly hit the same thing and the compile error was
missed rather than genuinely absent.

**Worked instead:** Include every file `Hgit()`'s body references, every
time — not "the file being tested," the complete set. **Rule replacing
the wrong one above: a silent no-output result from `Hgit()` (or any
function with untested branches) is not a mysterious session-state
issue — check for a missed compile error (screendump again) and for a
missing dependency before assuming anything more exotic.** Rebooting to
a clean session is still good hygiene, but it wasn't what actually fixed
either case — completing the dependency list was.

## 2026-09-13 — Packaging (probe 28): three distinct bugs stacked on top of each other

**Tried:** Saving the ~54KB combined hgit package to a real file on the
TempleOS disk, via three attempts, each fixing one real bug and
uncovering the next:

1. Push the package, then push a follow-up `FileWrite("...", Db, len)`
   referencing the daemon's own receive buffer. **Failed silently** (no
   error, file never created) — the follow-up push overwrites `Db`
   starting at byte 0 before the write executes, so by the time
   `FileWrite` runs, `Db` no longer holds the original package.
2. Fix: copy `Db` into a separately-allocated stable buffer, in the
   *same* push, then `FileWrite` from that. **Failed with `Undefined
   identifier` on the copy buffer** — its `U8 *x = MAlloc(...)`
   declaration came *after* the function using it, textually, in the
   pushed source. HolyC resolves top-level declarations in the order
   they appear, not via a two-pass scheme — confirmed again, this time
   for a global referenced inside a function defined earlier in the
   same chunk (the earlier-confirmed cases were all about `if`/`else
   if` branches; this is the same underlying sequential-processing
   behavior showing up in an ordinary declare-before-use way).
3. Fix: move the declaration first. **Still failed** — this time with a
   compile error *inside `Canon.HC`'s `PutU32LE`*, a function that had
   compiled cleanly in every one of probes 03 through 27. This was the
   fourth consecutive redefinition of the entire package within one
   daemon session.

**Worked instead:** A full VM reboot, then pushing the (already-fixed)
source exactly once. Worked immediately — `SAVED`, file confirmed on
disk at the exact expected byte count.

**Why the third failure happened:** Not determined. Logged as an open
question rather than a false confidence: possibly JIT redefinition
fatigue after several large (~54KB, ~40-symbol) pushes in one session,
possibly memory fragmentation from repeated large `MAlloc`s, possibly
something else. **Practical rule, stated honestly as a heuristic, not
an explanation: if a compile error appears inside code that has been
stable across many prior probes, try a clean reboot before assuming the
new code broke it.**

## 2026-09-13 — A genuine, unexplained daemon hang (probe 29)

**Tried:** Pushed the rebuilt `HgitAll.HC` package (~55KB) with a short
test tail appended in the same chunk, to verify quoting support
end-to-end in one push.

**Happened:** No `D_OK`, no `D_DONE`, ever — and the daemon didn't even
respond to a trivial follow-up `CommPrint` ping sent minutes later. This
is qualitatively different from every other failure logged in this
file: those all produced *some* signal (a compile error, garbage
output, or at minimum a `D_DONE`). This looked like a genuine hang.

**Why:** Not determined at all. Re-pushing the exact same package
**alone** (no test tail) immediately after a clean reboot worked
quickly and cleanly; the test code then worked fine as a separate,
smaller follow-up push. Whether the hang was caused by the combined
push's specific size/shape, a QEMU/TCG scheduling hiccup unrelated to
the guest code, or something else was not investigated further.

**Worked instead:** Reboot, then push the package and the test as two
separate chunks rather than one combined one. **Logged as an open
question, not a resolved mystery** — if a future push produces no
signal at all (not even an error), don't assume it's "still compiling"
indefinitely; treat a genuinely unresponsive daemon (no reply to a
trivial ping) as reason to reboot rather than wait longer.

## 2026-09-13 — Self-inflicted string-escaping confusion, not a HolyC quirk

**Tried:** Testing a HolyC fix by embedding the test source directly in
a Python string literal, manually escaping the double quotes the
HolyC code itself needed (`Hgit5("init \"...\"")` required as bytes,
constructed via nested Python `\"`/`\\\"` escapes).

**Happened:** Cascading, confusing compiler errors that didn't obviously
match anything wrong with the actual HolyC logic being tested.

**Why:** The manual multi-layer escaping (shell → Python → HolyC) had
produced the wrong bytes on the wire - a mistake in the test harness,
not a HolyC behavior.

**Worked instead:** Wrote the test as a plain `.hc` file (via the normal
file-editing tool, no manual escaping needed) and pushed its raw bytes
- this project's standard pattern everywhere else. The confusion
disappeared immediately. **Reinforced: when a test itself needs to
contain quote characters, write a real file - never hand-construct the
escaped bytes through multiple layers of string literals.**

## 2026-09-13 — Probe 31 (wire OpLog into Offer): QEMU verification blocked, not obtained (RESOLVED below)

**Tried:** Verifying `Offer.HC`'s new internal `OpLogAppend` call (see
`experiments/31-oplog-in-offer/README.md`) the normal way - boot,
bootstrap the stage-1 daemon, push real HolyC, read `serial.log`.
Two full attempts, including a fresh reboot specifically to rule out
leftover state, and splitting the push into a smaller (27KB,
function-definitions-only) chunk the second time.

**Happened:** Neither attempt ever produced a `D_DONE`, a compile
error, or any other signal after the daemon's own `D_OK` - not even
after ~11 minutes of real wall-clock waiting on the second attempt,
far past every prior probe's compile time for a similar or larger
chunk (probe 28 loaded 55238 bytes as one push successfully). QEMU's
own CPU-time counter kept advancing throughout (so it wasn't simply
paused), but no output ever appeared and no error window showed up in
repeated screendumps.

**Why:** Not determined. A real confound was found and is logged
honestly rather than assumed to be the cause: the host was under
severe memory pressure during the second attempt (swap 1.9/2.0 GiB
used, ~2 GiB RAM free, several unrelated heavy processes competing),
and this session's own background shell wait-loops were killed twice
by the host's low-memory watchdog mid-probe. That's a real constraint,
but it doesn't fully explain an 11-minute silence with active CPU
usage and zero guest-side error output - it may be the same class of
unexplained hang logged in the 2026-09-12 combined-push entry above,
or it may be purely host resource starvation. Both are logged as open,
neither is claimed as the answer.

**Worked instead (RESOLVED, same session, next iteration):** The real
cause was found by deliberately reproducing the exact symptom rather
than accepting "blocked": stage-1's `D()` daemon has **no compile-error
capture** in its `ExePutS(Db)` call. A malformed hand-typed sanity
payload (a self-inflicted shell/Python escaping mistake - not a HolyC
bug) produced this exact signature on demand - `D_OK`, then silence,
forever - while the screen (checked via screendump, not assumed)
showed a live HolyC debugger stopped on a real parse error. Headless
and with no one to dismiss it, that's indistinguishable from a hang by
`serial.log` alone. **Fix, now standard practice:** bootstrap straight
through to the devkit's stage-2 daemon (`D2()`/`_DRun`, using
`Fs->catch_except` to capture and report `COMPILE_OK`/`COMPILE_FAIL`
instead of dropping to the debugger) before pushing anything with new
or changed source. Full writeup: `experiments/31-oplog-in-offer/README.md`
(updated from its own original "blocked" version once this was found).
Whether this also explains the 2026-09-12 combined-push hang logged
above is a strong plausible explanation, not a confirmed re-diagnosis
of that specific incident - left as originally written there.

## 2026-09-13 — Probe 34: large unpaced pushes can silently drop bytes (RESOLVED)

**Tried:** Pushing the ~46KB `hgit-cli` chunk (with the new `Paths.HC`
added) as one `sendall()` over the COM2 socket, reusing a long-lived
stage-2 session already proven working in probes 31-33.

**Happened:** The push took over 10 minutes with no `COMPILE_OK`/
`COMPILE_FAIL` - the first time stage-2 itself (which reports both
quickly, by design) seemed stuck. A fresh reboot was done to rule out
the long-lived session degrading; the retry (still one unpaced
`sendall()`) appeared, from a `tail` check, to succeed - but that check
was reading stale output from an *earlier*, smaller push, and the real
chunk's own result hadn't landed yet. The next push (a small test
driver) sent immediately after produced a **combined, garbled compile**:
warnings from mid-way through the cli chunk's own functions, then the
test driver's first statement failing with `Undefined identifier` -
with no `COMPILE_OK`/`COMPILE_FAIL` for the cli chunk ever appearing.
This means the cli chunk's own trailing EOT byte (`0x04`) never reached
the guest; both pushes' bytes were treated as one continuous stream.

**Why:** The 46KB file itself was confirmed byte-clean (no stray `0x04`
inside it). The likely cause: a single large, unpaced `sendall()` over
the emulated serial line can have bytes dropped somewhere between the
host socket and the guest's software FIFO under host memory pressure -
a real, distinct reliability gap from the compile-error-capture finding
logged just above (that one was about *executing* a chunk that fully
arrived; this one is about the chunk not fully arriving in the first
place).

**Worked instead:** `experiments/01-temple-repl/paced_push.py` - sends
the file in small (2KB) pieces with a short delay between each, rather
than one call. Re-pushing the identical 46KB chunk with this script
produced a clean, fast `COMPILE_OK` on the very next attempt. **New
standing practice: use paced_push.py, not a single sendall(), for any
push over ~10KB.** Full writeup: `experiments/34-hgit-paths/README.md`.

## 2026-09-13 — Probe 36: path-scoped oplog test genuinely FAILED, root cause a real 33-char path limit (RESOLVED)

**Tried:** Making `OpLog.HC`'s undo/redo logs path-scoped
(`<repo_path>.oplog.<name>`/`.redolog.<name>`), verified with a real
test through the `Hgit(cmdline)` dispatcher (offer on main, branch to
`feature`, offer/undo/redo on `feature`, confirm main untouched).

**Happened:** A real `FAIL`, reported honestly rather than adjusted
until it passed: `feature_head_restored_by_own_redo=0` and
`feature_untouched_by_main_undo=0`. `feature`'s own undo *had* worked
(reverted the right HEAD, left main alone) but its `.redolog` file
didn't exist afterward.

**Why:** Chased with five diagnostic pushes, narrowing from "does
`OpLogUndo` write the redo log" down to "does a bare literal
`FileWrite` to this exact path string work at all" (it didn't - ruling
out every layer of this project's own code). Cross-checking a
previously-working sibling shape (`.head.feature`, from probes 34/35)
against a longer suffix (`.head.feature2`) showed it *also* failed -
the common factor was total path length, not the word "oplog". A
dedicated binary-search probe pinned it exactly: **a full path string
of 33 characters round-trips through FileWrite/FileRead correctly; 34
characters silently fails** - no error, the file is simply never
created/found. (That probe's first version used a bare top-level `for`
loop with local declarations and printed nonsense `len=0` for every
case - the pre-existing documented quirk about bare top-level loops
corrupting data, not a new bug; wrapping it in a real function fixed
it immediately.) `C:/Home/P36Repo.hgs.oplog.feature` is 34 characters -
one over the limit.

**Worked instead:** Shortened the non-main sidecar suffix from
`.oplog.<name>`/`.redolog.<name>` to `.ol.<name>`/`.rl.<name>`. Re-ran
the identical test after the fix: real `PASS`. This is a genuine,
previously-undocumented TempleOS/RedSea constraint (now in
`docs/research/01-templeos-holyc.md`'s "Path length limit" section),
not fully resolved at the architecture level - it constrains every
sidecar-file-per-concern design this project uses, and shortening one
suffix only buys headroom, not a removed ceiling. Full writeup:
`experiments/36-path-scoped-oplog/README.md`.

## 2026-09-13 — Probe 40: an over-length path can genuinely HANG, not just silently no-op

**Tried:** Verifying `Meta.HC` (ADR 0003's combined-metadata-file
primitive) with a deliberately long repo path
(`C:/Home/AVeryLongRepositoryName.hgs`, 35 characters - already over
probe 36's 33-character ceiling on its own) to contrast against the old
per-path sidecar scheme.

**Happened:** A real hang, reproduced on two separate fresh boots
(ruling out session degradation): execution froze inside the very
first `MetaWriteHead` call and never returned - no compile error, no
`COMPILE_OK`/`COMPILE_FAIL` (stage-2 only prints those once `_DRun`
returns), just silence, indefinitely.

**Why:** Not independently isolated all the way down, but a real
confound was found and is the leading explanation: probe 36 established
that `FileWrite`/`FileRead` on an over-length path silently do nothing
and return cleanly (`buf == NULL`) - but that finding used paths that
were *valid-length-but-nonexistent*. This probe's path was *invalid*
(over the length ceiling) from the start, a case not separately tested
before. The working theory is that `FileRead` on an invalid path may
not reliably zero its output `size` parameter the way it does for a
valid-but-nonexistent one, so downstream code trusting `size` without
checking `buf == NULL` first could read/loop over garbage. `Meta.HC`
itself already guards correctly (`if (buf == NULL) total_old = 0; else
total_old = size;`), so this remains a theory about the mechanism, not
a confirmed root cause chased down further.

**Worked instead:** Re-ran the identical test with a realistic,
valid-length repo path (23 characters) on a fresh boot - completed
cleanly, real `PASS`. **New standing practice, beyond probe 37's
`PathNameFits` guard on new path names specifically**: never construct
or pass a path string that might exceed 33 characters into
`FileRead`/`FileWrite` anywhere in this project, including throwaway
test/diagnostic code - the risk isn't limited to real repo paths. Full
writeup: `experiments/40-combined-meta-file/README.md`.

## 2026-09-13 — Probe 41: `pi` is a reserved identifier, and it took real discipline to prove it wasn't session pollution

**Tried:** Verifying `Meta.HC`'s path-list/current-path functions
(`experiments/41-meta-paths-current/`). One specific function
(copying a record's name into a local buffer via a loop variable named
`pi`) failed to compile with `ERROR: Expecting '*' at
"INT:400921FB54442D18" (0x400921FB54442D18(F64))`.

**Happened:** The failure came with a red herring - an intermittent
"Fun header args mismatch" warning on some retries strongly suggested
stale session state (a function redefined after an earlier failed
attempt at the same name). Ruling that out took several fresh-reboot
cycles: pushing a brand-new, never-before-used function name
(`ZzzNestedCopyTest`, never referenced anywhere before) as the very
FIRST push on a truly clean boot still reproduced the identical error -
proving it was real, not stale state, before continuing to chase it.

**Why:** Bisected the function body down to a two-line minimal repro
across six more small, cheap pushes on that same clean session
(`U8 buf[64]; I64 pi; for (pi=0; pi<3; pi++) buf[pi] = 'x';`), then
renamed just the loop variable to `qi` - compiled instantly, same
everything else. `0x400921FB54442D18` is exactly IEEE754 double `pi`
(3.14159...) - TempleOS predefines `pi` as a real global `F64`
constant, and declaring a local variable with that name collides with
it, confusing the parser into this specific misleading message instead
of a clean shadowing/redeclaration error.

**Worked instead:** Renamed the loop variable to `ni`. **New standing
practice: never use `pi` as a local variable or parameter name
anywhere in this project** - now documented in
`docs/research/01-templeos-holyc.md`. Full writeup:
`experiments/41-meta-paths-current/README.md`.

## 2026-09-13 — `hgit offer *` against ~60 accumulated files caused a real GPF, not a graceful error

**Tried:** Probe 55's first end-to-end `hgit reconciledoc` test
(`experiments/55-reconciledoc/`) called `hgit offer C:/Home/P55Repo.hgs
*` against `C:/Home` after ~54 prior probes' leftover files (60+
entries: repos, sidecar files, test fixtures) had accumulated there in
this same long-running QEMU session.

**Happened:** A real General Protection fault inside `GetU32LE`
(`Fault:0x0D General Protection RIP:1SBA2093:&GetU32LE+0x001B`),
dropping straight into TempleOS's own kernel debugger - not a compile
error, not one of this project's own clean `DISPATCH_ERR` paths, a
genuine crash. Unlike probe 54's `Ed()`-blocks-the-daemon finding,
`sendkey esc` does nothing to a real fault debugger - recovery required
a full VM reboot (the persistent installed disk meant no reinstall,
but the entire stage-1→stage-2 daemon bootstrap had to be redone by
hand).

**Why:** Not fully isolated. Plausible causes, not yet distinguished:
`WorkDir.HC`'s enumeration buffer, `Offer.HC`'s tree-build path, or
`Index.HC`'s fixed-size `idx_hashes[64*64]`/`idx_offsets[64]` arrays (a
hardcoded cap of 64 objects) being overrun by a much larger object
count than any previous probe's repository ever held - every prior
`offer` probe used a small, deliberately constructed working directory,
never one with 60+ pre-existing files.

**Worked instead:** Re-ran the same test with a specific `find_mask`
naming one real file (`P55BFileA.txt`) instead of `*` - passed cleanly.
**Not fixed at the root** - `hgit offer *` against a directory holding
many dozens of files remains untested and now known-unsafe until this
is root-caused. Flagged as real, unresolved follow-up work, not a
workaround presented as a fix. Full writeup:
`experiments/55-reconciledoc/README.md`.

**Bonus harness lesson from the recovery itself:** `qemu-system-x86_64`'s
HMP monitor `sendkey` command only accepts real key names, not an
arbitrary string as one argument - `sendkey "some command"` silently
types nothing. The fix already existed, unused, in
`experiments/templeos-devkit/scripts/send.py` (maps each character to
its own `sendkey` call) - re-discovered and used correctly on the
second attempt.

## 2026-09-13 — `Offer.HC`'s crash/hang root-caused: two unbounded stack buffers, plus a `continue`-keyword parse error while fixing it

**Tried:** Root-causing the prior entry's `hgit offer *` GPF
(`experiments/56-offer-buffer-guard/`). Deliberately reproduced the bug
in isolation twice: 40 tiny files matched by a wildcard, and separately
one 600-byte file.

**Happened:** The 40-file case did **not** reproduce a GPF - it
reproduced a silent infinite loop instead (no debugger fault, no
further daemon output at all, confirmed unresponsive even to an
unrelated follow-up ping). A genuinely different failure mode from the
prior entry's crash, from what turned out to be the same root cause.

**Why:** `Offer.HC`'s `tree_content[2048]` and `blob_tagged[512]` stack
buffers had no bounds check - `tree_content` overflows at ~24 small
matched files (confirmed by direct arithmetic: ~82 bytes/entry,
2048/82≈24, matching exactly where the log showed the first skip once
fixed), `blob_tagged` overflows for any single file over 511 bytes.
Which one overflows, and what it happens to corrupt on the stack,
decides crash vs. hang - not a single deterministic bug.

**A second failure hit while writing the fix**: the first attempt used
`if (bad) { ...; continue; }` to skip an oversized file, which failed
to compile (`ERROR: Undefined identifier at ";"`) - HolyC has no
`continue` keyword. Already documented in
`experiments/templeos-devkit`'s own bug-compatibility corpus
(`holyc-parser/tests/corpus/failing/007-bug-compat-bug52-continue-keyword.hc`),
but this project's own code had never hit it directly before.

**Worked instead:** Added an explicit bounds check before building each
file's blob/tree entry, restructured as `if / else if / else` (no
`continue`) so an oversized file is skipped with a clear
`OFFER_SKIP file_too_large`/`OFFER_SKIP tree_full` message instead of
overflowing anything. Re-verified against both reproductions
(previously-hanging/untested cases now complete cleanly) and a full
regression of the prior entry's own end-to-end scenario (no behavior
change for the normal case). Full writeup:
`experiments/56-offer-buffer-guard/README.md`.

## 2026-09-13 — Redefining a called function doesn't fix up an already-compiled caller

**Tried:** Upgrading `ReconcileDoc.HC` to real `$TR$`/`$ID$` tree
formatting (`experiments/58-reconciledoc-tree/`). Pushed the edited
file alone, got a clean `COMPILE_OK`, then re-ran the real
`init`→`offer`→`correct`→`reconciledoc` end-to-end test through
`Hgit(cmdline)`.

**Happened:** The `.DD` output, read back via `FileRead`, was still
the **old** flat format - not the new tree structure the edited source
should have produced. Compiling clean did not mean the fix was live.

**Why:** `Hgit.HC`'s dispatcher (which calls `HgitReconcileDoc`) had
already been compiled earlier in this same long-running daemon
session, with a direct call instruction pointing at the *old*
compiled address of `HgitReconcileDoc`. Redefining the callee under
the same name compiles fresh code and registers a new symbol, but
doesn't retroactively patch call sites already baked into a
previously-compiled caller.

**Worked instead:** Re-pushed `Hgit.HC` itself (no source changes
needed in it) to force it to recompile and re-resolve its call to the
new address - confirmed by reading the `.DD` bytes back again, this
time matching the new format. **New standing practice**: after editing
any function in a long-running daemon session, re-push every
already-compiled caller of it too, not just the function itself - a
clean compile of the edited file alone is not sufficient evidence the
change is live. Full writeup: `experiments/58-reconciledoc-tree/README.md`.

## 2026-09-13 — A second, different GPF: `archive[8192]` overflows after ~13 ordinary offers alone

**Tried:** Testing probe 59's own truncation-guard follow-up
(`experiments/60-archive-buffer-guard/`): running many `hgit correct`
calls in a row on a small, fresh repo, no wildcards, no large files -
just ordinary repeated corrections, to see `ReconcileDoc.HC`'s bounds
check actually trigger.

**Happened:** A real kernel GPF hit first, before that check could
even be exercised - around the 13th correction in a row, `RIP:...
&CommitEncode+0x0126`. A genuinely different crash from probe 56's own
(different trigger, different function in the fault trace).

**Why:** Logged the repo's real file size (`FileRead`'s own `size`
param) before every call in a loop to bisect precisely rather than
guess: growth is steady and exact, ~599-600 bytes per `offer`/
`correct`. `Offer.HC`'s `HgitOfferWithRelation` copies the *entire
existing repo* into a fixed `U8 archive[8192]` stack buffer before
adding anything new - once the repo alone (before this call even
starts copying it) exceeds 8192 bytes, that copy loop overflows the
buffer. Confirmed exactly: the crash hit with the repo already at 8206
bytes. This is the exact gap probe 56's own README flagged as "not
yet done" (`archive[8192]` unaddressed) - now confirmed hit in
practice with real numbers, not hypothetical.

**Worked instead:** A guard at the top of `HgitOfferWithRelation`:
refuse cleanly (`OFFER_REFUSED archive_too_large_for_in_memory_buffer`)
once the existing repo is within 1024 bytes of the buffer's capacity,
instead of copying it and corrupting memory. Verified against a fresh
from-zero bisection (confirms the exact crossover: normal growth for
11 real corrections, then clean refusals from iteration 12 onward,
repo size frozen, no crash) and a harsher test (25 calls against a
repo already past the threshold, all cleanly refused, daemon confirmed
still alive afterward). The underlying 8192-byte ceiling itself isn't
lifted - a real repo that legitimately needs to grow past it currently
just stops accepting new offers cleanly rather than working; real
follow-up architecture work, not solved here. Full writeup:
`experiments/60-archive-buffer-guard/README.md`.

## 2026-09-13 — Fixing one fixed-buffer ceiling revealed the next one behind it

**Tried:** Implementing ADR 0007 (`experiments/61-dynamic-archive/`):
replacing `Offer.HC`'s fixed `U8 archive[8192]` with an `MAlloc`'d
buffer sized from the repo's real size, to lift the ceiling probe 60
had only guarded (not removed). Re-ran the same 30-correction
reproduction that motivated the ADR to confirm it now runs past the
old crash point.

**Happened:** Growth continued cleanly past the old ~13-offer/8192-byte
crash point, exactly as intended - and then crashed anyway, at a
larger scale (~22 offers), with a different fault
(`RIP:...&PutU64LE+0x0043`, distinct from the `CommitEncode` fault
probe 60 diagnosed).

**Why:** `Offer.HC`'s `old_idx_hashes[64*64]`/`old_idx_offsets[64]`
(built via `IndexBuild` for ADR 0004's parent-tree lookup) is a
*separate* hardcoded cap - 64 objects in the whole repo, not 64
matched files - unrelated to `archive`. At ~3 objects per offer (one
blob, one tree, one commit), that overflows at ~21 offers. The first
fix had been masking this the whole time, because the outer `archive`
ceiling was always hit first, at a smaller scale.

**Worked instead:** Fixed the same way as `archive` itself:
`old_idx_hashes`/`old_idx_offsets` are now `MAlloc`'d sized from
`rcount` (the repo's own exact object count, already read from the
`.HGS` header - no headroom guess needed, unlike `archive`'s own
heuristic margin, since this count is exact by construction), freed
right after their last use. Re-verified: all 30 corrections now
complete cleanly, repo grown to 30,808 bytes, no crash. **Real,
still-open risk, deliberately not chased further in the same
session**: the identical `idx_hashes[64*64]`/`idx_offsets[64]` pattern
exists, unfixed, in five other call sites (`History.HC`,
`HistoryDoc.HC`, `Status.HC`, `See.HC`, `ReconcileDoc.HC` twice) -
confirmed by code inspection, not yet independently hit by a crash in
any of them. Full writeup: `experiments/61-dynamic-archive/README.md`.

## 2026-09-13 — Meta.HC's own fixed rebuild buffers silently lost data, with zero error signal

**Tried:** Auditing `Meta.HC` (the shared combined-metadata-file layer
every real command runs on, ADR 0003) after probes 60-62 closed out an
identical fixed-buffer bug class in `Offer.HC`/`See.HC`/`History.HC`/
etc. Found the same `read-whole-file, rebuild-in-a-fixed-buffer,
write-whole-file` pattern in nine of `Meta.HC`'s own functions, each
with its own `U8 new_buf[16384]`. Ran a real 150-offer stress test,
logging the file's own real size every 10 offers to bisect precisely
(`experiments/66-meta-dynamic-buffer/`).

**Happened:** Growth was steady (~144 bytes/offer) and crossed 16384
bytes around offer 114 - and **every single one of the 150 offers
still reported `DISPATCH_OK`**. No crash, no error, no visible
symptom at all - the opposite of every prior fixed-buffer bug this
project found (probes 55/56/60/61, all real kernel GPFs).

**Why:** A follow-up script independently counted real operation-log
entries (`MetaOpLogCount`) and checked `HEAD` directly, rather than
trusting the all-`DISPATCH_OK` output: `OPLOG_COUNT=115` (35 of 150
real operations silently never recorded) and `HEAD` pointed at
`offer_number_113`, 36 offers behind the true latest commit. The fixed
16384-byte buffer was silently truncating/dropping writes past its own
capacity while `FileWrite` itself reported no error - a materially
worse failure mode than a crash, since a user would see every command
succeed and have no way to know a third of their real history was
gone until they happened to independently check a count or notice
`HEAD` looked stale.

**Worked instead:** Same fix as ADR 0007: all nine `new_buf[16384]`
arrays are now `MAlloc`'d from the metadata file's real size (already
known from `FileRead`) plus a small headroom, freed on every exit path.
Verified on a truly fresh boot: the same already-past-the-old-ceiling
repo (left over from the pre-fix run) grew cleanly through another 150
offers to 37,966 bytes, with full data-integrity accounting this time
(`OPLOG_COUNT=265`, exactly 115 + 150 - zero further loss; `HEAD`
correctly resolving to the real last commit, `offer_number_149`).
Full writeup: `experiments/66-meta-dynamic-buffer/README.md`.

**Standing lesson, worth repeating**: a command reporting
`DISPATCH_OK` is not, by itself, proof its effect was correctly
persisted at scale - this project's own crash-based bugs (loud, easy
to notice) had made that easy to forget. Real corpus-scale testing,
checking the actual persisted state independently rather than trusting
a success code, is the only way this class of bug surfaces.

## 2026-09-13 — Two more real buffer bugs, found by auditing the codebase directly rather than waiting for a crash

**Tried:** After probes 60-62/66 closed out every fixed-buffer bug this
project had actually reproduced, grepped the whole codebase for every
remaining fixed-size stack array (`experiments/67-historydoc-buffer-guard/`)
rather than assuming the class of bug was fully closed.

**Happened:** Two real, live risks turned up: `HistoryDoc.HC`'s
`doc[8192]` (no bound against a repo's real commit count) and
`Status.HC`'s `tagged[512]` (no bound against a matched file's real
size). Tested the first directly against the real ~300-commit repo
probe 66's own stress test left behind (no synthetic setup needed) and
got a genuine kernel GPF, `RIP:...&StrNew` - the crash surfacing
inside an unrelated kernel function is the same signature as probe
60's own `CommitEncode` crash: stack corruption from the buffer's own
overflow, manifesting wherever the corrupted stack next gets used.

**Why:** `HistoryDoc.HC`'s sibling function, `HgitReconcileOverview`
(probe 59), already had a truncation guard for the identical
`doc[8192]` risk - it was just never applied to `HistoryDoc.HC` itself
when that guard was added. `Status.HC`'s `tagged[512]` is the exact
same per-file-size bug probe 56 already fixed in `Offer.HC`'s
`blob_tagged[512]` - also never applied here.

**Worked instead:** Applied the same two already-proven fixes:
`HistoryDoc.HC` now stops cleanly with a `(truncated - too much
history for one document)` notice before overflowing; `Status.HC` now
reports `STATUS_TOO_LARGE_TO_CHECK <name>` and skips a file that
doesn't fit, instead of corrupting memory. Verified against the real
crash reproduction (now completes cleanly, confirmed by reading the
generated document's actual raw bytes, not just the dispatch code) and
a real oversized-file reproduction for `status`, plus an unaffected
normal-case regression. Full writeup:
`experiments/67-historydoc-buffer-guard/README.md`.

**Standing lesson**: fixing a bug in one function doesn't mean an
identical bug in a sibling function is also fixed - each of this
project's five fixed-buffer probes so far (56/60/61/62/66/67) found
its own bug independently; the fix pattern was known each time, but
applying it required actually finding every call site, not assuming
"the same kind of bug" implies "already fixed everywhere."

## 2026-09-13 — Fossil delta format prototype: real quirks found, one real reliability gap left unresolved

**Tried:** Prototyping Fossil's delta format in HolyC
(`experiments/68-fossil-delta-format/`, `src/hgit-core/Fossil.HC`), per
doc 04's own recommendation. Built the base-64 integer encoding, the
checksum, and delta encode/apply, sourced byte-exactly from Fossil's
own `src/delta.c`.

**Happened, in order:**
1. An early test driver crashed the VM outright via `CommPrint("%s",
   delta)` on a non-null-terminated buffer - a test-driver bug, not
   Fossil.HC's.
2. A real logic bug: the segment-parsing loop scanned for `;` to
   decide "more segments?", which is ambiguous with the trailer's own
   checksum digits (never `;` either) - misread the checksum as a
   bogus segment length and overran both buffers, causing a real VM
   reset.
3. After fixing the loop to terminate via the header's declared target
   length instead, checksums still didn't match between encode and
   decode. Isolated via careful bisection (a chain of increasingly
   minimal reproductions) to a genuine HolyC quirk: casting a raw byte
   read directly to `(I64)` gives garbage, while `(U64)` on the exact
   same read works correctly - confirmed across every index-expression
   shape (literal, variable, arithmetic, parenthesized).
4. After fixing all raw-byte casts to `(U64)`, a separate bug remained:
   the trailer-parsing order checked for `;` before reading the
   checksum digits, backwards from the real format.
5. After fixing all four of the above, a controlled minimal test
   (`P68QCheck`) passed reliably, twice in a row, with matching
   checksums. But the **original** test driver (`P68BTest`, and a
   freshly-named equivalent, `P68RFinalVerify`) still failed with the
   same call and arguments.

**Why (partially - not fully understood):** Bisected precisely: taking
the passing minimal test and adding exactly two unused local variables
(`Bool match = TRUE; I64 i = 0;`) *after* the `FossilDeltaApply` call,
with no other change, flips the result from pass to fail, reproduced
consistently. Ruled out a stale-redefinition artifact (a brand-new
function name still failed once it had more locals) and simple
non-determinism (the minimal test passed twice in a row; the larger
one failed twice in a row). The actual mechanism - a real bug in
`Fossil.HC` sensitive to stack layout, or a deeper HolyC compiler
quirk - was not established before time was called on this probe.

**Worked instead:** Nothing - this is reported as a genuinely
unresolved finding, not a dead end papered over. `Fossil.HC` is kept as
a standalone prototype (`docs/adr/0008-fossil-delta-format-prototype.md`),
verified correct only in a minimal, controlled calling context, and
deliberately **not** wired into `tools/build-package.sh` or any real
command until this reliability gap is understood. Full writeup:
`experiments/68-fossil-delta-format/README.md`.

## 2026-09-13 — Narrowing (not solving) the Fossil.HC caller-shape mystery further

**Tried:** Following up on the open caller-shape-sensitivity finding
logged just above, with more targeted bisection to narrow it past
"unrelated local variables" to something more specific.

**Happened:** Nine separate, isolated reproductions
(`experiments/68-fossil-delta-format/test_fails_*.hc`/`test_PASSES_*.hc`/
`test_ruled_out_*.hc`) systematically ruled out: local-variable count
(one extra local still fails), type (I64 and U32 both fail alone),
name collision (renaming to unique names still fails), an
unused-variable/dead-code effect (using the value still fails), and
"any extra function call fixes it" (an unrelated `StrLen` call still
fails; a `FossilChecksum` call whose result is discarded still fails).

**Why (still not fully understood):** The one specific, reliably
reproducible trigger found: calling `FossilChecksum` again later in
the same function (on the same content) **and using its result**
flips an *already-computed-and-printed* earlier `FossilDeltaApply`
call's result from failure to success - confirmed twice in separate
pushes. Since the second call is textually after the point where the
affected value was already printed, this cannot be explained by
runtime execution order - it points at the compiler generating
different code for the *earlier* call depending on what appears later
in the same function body, a genuine code-generation-level effect
rather than a logic bug.

**Worked instead:** Nothing further attempted - this is real,
additional narrowing of an already-logged open question, not a new
dead end and not a fix. Recorded so a future investigation (with
access to disassembly, which this session doesn't have) has a much
more specific starting point than "add some locals and see." Full
writeup: `experiments/68-fossil-delta-format/README.md`.

## 2026-09-13 — The test-harness's own daemon receive buffer was too small for the grown package

**Tried:** Pushing the rebuilt `packaging/HgitAll.HC` (133,804 bytes,
after adding `hgit check`'s referential-integrity pass) to the
long-running QEMU daemon session.

**Happened:** A compile error, `Missing ';' at "T:0"`, cutting off
mid-source inside `Hgit.HC`'s own path-dispatch code - code that has
been stable and repeatedly verified working all session. Reproduced
identically on a second attempt (same error, same cutoff point) - not
random corruption, which would differ between attempts.

**Why:** `experiments/01-temple-repl`'s stage-1/stage-2 daemon receive
buffer (`Db`) has always been `MAlloc(131072)` (128KB, with a matching
`Di<131071` bound), unchanged since this project's earliest probes.
The package had simply grown past that limit - 133,804 bytes exceeds
131,072 by 2,732 bytes, silently truncating every push past that
point with no error from the push mechanism itself (only the resulting
garbled compile revealed it).

**Worked instead:** Rebooted and rebootstrapped with a 512KB buffer
(`Db=MAlloc(524288)`, bound `Di<524287`, both stage-1's `D()` and
stage-2's `D2()`) - confirmed the identical package then compiles
cleanly (`COMPILE_OK`) with no other change. Also found and fixed a
real, separate bug while investigating: `Check.HC` was ordered before
`Hex.HC` in `tools/build-package.sh` (an ordering left over from probe
64, before `Check.HC` needed `HashToHex`) - moved it after `Hex.HC`,
matching real HolyC's own no-forward-declarations rule. Full writeup:
`experiments/69-check-referential-integrity/README.md`. **Standing
note for future sessions**: if a push of the full package produces a
confusing, reproducible parse error deep in otherwise-stable code,
check the package's real byte size against the daemon's own buffer
size before assuming a source-code bug.

## 2026-09-13 — Guessing TempleOS's real file-delete function name, three ways wrong

**Context:** Building `experiments/71-status-rename-surfacing/`'s test
driver, which needed to actually delete a file on disk (to test
`hgit status`'s DELETED/RENAMED classification against a real
disappearance, not just a name that was never created).

**Happened:** Four guessed names, three different failure shapes:
- `FileDelete("...")` and `FDelete("...")` - both a clean
  `Undefined identifier` error (valid call syntax, symbol just doesn't
  exist).
- `DiskDelete("...")` and `FileDel("...")` - both a stranger
  `Invalid lval` + `Compiler Parse Error` pair, pointing at the
  identifier itself rather than at the call. Not explained - possibly
  these substrings collide with something else the parser recognizes,
  but not chased further since the real name was found before it
  mattered.

**Worked instead:** `Del(filename, FALSE, FALSE, FALSE)` - the real
TempleOS kernel API. Found not by more guessing but by searching this
project's own history first: `experiments/21-status-deleted/`'s
`tested_source.hc` (written much earlier in this project, for the
exact same "delete a file to test STATUS_DELETED" need) already used
it, with its own inline comment: `// real API from Kernel/BlkDev/
DskCopy.HC, not "FileDel"` - meaning this exact wrong guess had already
been made and corrected once before, just never promoted into
`docs/research/01-templeos-holyc.md` as a standing fact. Doing so now:
**the real TempleOS file-delete call is `Del(path, FALSE, FALSE,
FALSE)`, not any `File*`/`Disk*`-prefixed name** - check prior probes'
own test drivers before guessing a kernel API name from convention.

## 2026-09-13 — Two real bugs found writing `experiments/72-check-dangling-objects/`'s test, neither in the shipped feature's own core logic

**Context:** Building `hgit check`'s new dangling/unreachable-object
detection (`CheckMarkReachable`, a real reachability walk from every
declared path's HEAD).

**Bug 1 - a real correctness bug in the new check itself, found by
testing against a long-lived, previously-used repo, not a fresh
one:** `Object.HC`'s own `ObjectPut` is a plain append with no
content-hash dedup - if the exact same content gets offered more than
once over a repo's life, the identical hash can occupy several
different archive positions. The first version of
`CheckMarkReachable`'s reachability walk (via `IndexLookupPos`, itself
a first-match-wins linear scan, matching every other lookup this
project has built) only ever marked whichever position it found
*first* as reachable - every OTHER position holding that same hash
was left unmarked and got reported as a false-positive
`CHECK_DANGLING`, even though the content was genuinely reachable
under a different stored copy. Caught by running the real check
against `P65Repo.hgs` (this project's own long-lived regression repo,
carrying real accumulated `undo`/`redo` history across many probes
with repeated "v1"/"v2" content) - reported 16 dangling objects out of
36, an implausibly high fraction that prompted a closer look rather
than being accepted at face value.

**Worked instead:** one linear coalescing pass after the main walk -
any position sharing a hash with an already-reachable position is
content-identical (same hash = same content) and therefore equally
reachable, marked in a single pass (no fixed point needed, since a
duplicate's own outgoing references are byte-identical to the
original's and already resolved by the original's own walk). Re-ran
against the same `P65Repo.hgs`: dropped to a real, sane
`CHECK_DANGLING_NONE`.

**Bug 2 - not a bug in `hgit check` at all, but in the test driver
itself:** the test's own cleanup, `Del("...P72Repo.hgs", ...)` before
each run, deleted only the object-store file - not
`Meta.HC`'s own sidecar (`<repo_path>.m`, holding HEAD/paths/oplog).
A fresh `init` over the leftover `.m` file produces a repo whose
object store is genuinely empty but whose stale `HEAD` still points at
a hash from the previous run - a real `CHECK_BROKEN_REF
commit_parent_missing` from the very first commit, immediately.
**Worked instead:** delete both files (`<repo>.hgs` and
`<repo>.hgs.m`) before re-`init`-ing the same repo path in a test.
Standing note: `hgit init` does not itself detect or refuse this
combination (a deleted `.hgs` but a surviving `.m`) - a real, minor gap
this project hasn't decided whether to close (most real usage
wouldn't reuse a path this way), left here as an honest observation,
not chased further.

## 2026-09-13 — Attempting to verify a real CD-ROM install path for TempleOS, not conclusively resolved

**Context:** Trying to verify a real, non-dev-tooling way for a user
to get `packaging/HgitAll.HC` onto a TempleOS machine (a second IDE
CD-ROM drive attached to a disposable, snapshot-mode QEMU probe VM
booted off this project's own long-lived disk, carrying a small data
ISO built with `mkisofs`). Full writeup:
`experiments/75-cd-media-attempt/README.md`.

**Happened:** Drive letters `A`/`E`/`F`/`G`/`H` all threw a real,
non-fatal TempleOS exception (invalid drive). `D:` turned out to be
the real boot drive (same contents as `C:/Home`'s own parent -
`C:` looks like an alias/redirector, not a separate physical drive).
`B:` is a real, valid drive, but reported 0 entries both before and
after hot-swapping the attached CD image's real content via the QEMU
monitor (`change ide1-cd0 <path>`, confirmed via `info block` that the
swap itself took effect).

**Why:** Not determined. Either `B:` isn't the attached CD-ROM at all
(some other always-present empty drive), or it is but TempleOS doesn't
pick up newly-changed removable media without an explicit rescan this
attempt didn't find. Two ISO variants (with/without Joliet+RockRidge)
were tried; both gave the same empty result, so the ISO's own format
wasn't the more likely variable and wasn't narrowed further.

**Worked instead / how this was actually resolved for the product
question that motivated it:** it didn't need solving - the real,
already-verified answer is **COM2 serial injection**
(`paced_push.py`), the exact mechanism this entire project has used
for all 74 prior probes, which genuinely is proven end-to-end transport
for getting a `.HC` file's content onto a real TempleOS machine. Stopped
chasing the CD-specific drive letter deliberately, not because of a
hard blocker - it's a low-value detail (a real user's own drive-letter
mapping depends on their own hardware anyway, not something worth
guessing from one QEMU configuration) relative to the time it would
keep costing. `INSTALL.md` was written around the serial-transfer
mechanism instead, which is both verified and general.

**Real, useful side-confirmation despite not solving the main
question:** `-snapshot` + `file.locking=off` on the primary drive lets
a disposable exploratory QEMU VM boot off this project's own
long-lived disk image with zero risk to it or to the main daemon
session (confirmed after the fact: `disk.qcow2`'s own mtime never
changed, and the main daemon process was untouched throughout) - a
real, reusable technique for future probes that want to try something
against real accumulated state without commitment.

## 2026-09-13 — Re-running an old probe's own test driver against the persistent session repo gave a confusing (but not wrong) result

**Context:** Verifying probe 85's fuzzy-rename addition to `hgit
status` didn't break probe 71's own exact-content rename test, by
re-running `experiments/71-status-rename-surfacing/test_driver.hc`
directly against the live daemon.

**Happened:** Instead of the original expected output
(`STATUS_RENAMED`/`STATUS_NEW`/`STATUS_DELETED` for the three test
files), it printed `STATUS_UNCHANGED` for two of them and
`STATUS_DELETED` for two *different* ones - looking, at a glance, like
a real regression.

**Why:** Not a bug. That test driver's own `P71Repo.hgs` is a real,
long-lived repo on this session's persistent QEMU disk, and that
driver has **no `Del()` cleanup** at its start (written before probe
84 established that convention) - so this re-run offered into the SAME
repo probe 71 already committed to, earlier this session. The files
it reported `STATUS_UNCHANGED` genuinely *were* unchanged relative to
that accumulated HEAD; the files it reported `STATUS_DELETED` genuinely
didn't exist on disk anymore (never recreated by this particular
script run). `hgit status` was reporting the real, correct state of a
repo whose actual history no longer matched what the test's own
comments assumed a "fresh" run would look like.

**Worked instead:** Wrote a **new** test
(`experiments/85-status-fuzzy-rename/test_driver_exact_regression.hc`)
replicating probe 71's exact scenario against a **fresh** repo (`Del()`
both the `.hgs` and its `.m` sidecar first, per probe 79's own
established convention) - confirmed exact-content rename detection
still works identically after probe 85's fuzzy-pass addition.
**Standing note**: any probe whose own test driver predates the
`Del()`-cleanup convention (roughly, anything before probe 84) will
give a misleading result if just re-run later in the same session
against the accumulated persistent disk - write a fresh-repo variant
to actually re-verify it, don't trust a bare re-run's output at face
value.

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

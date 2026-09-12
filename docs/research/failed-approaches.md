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

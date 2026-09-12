# Probe 27 — `offer` wired into the dispatcher, real TempleOS (and a corrected diagnosis of probe 26)

Status: **PASS after two missing-dependency fixes.** All five M1
commands are now dispatched through `Hgit(cmdline)`.

## Design

`offer`'s free-text message can't be extracted with `ExtractToken`
(which stops at the first space) — it's *everything after* the first
two tokens (repo path, find mask), taken verbatim via `StrLen`. Its
timestamp is `cnts.jiffies`, confirmed as a real, directly-addable
global (`Kernel/KTask.HC` uses it as `cnts.jiffies+DYING_JIFFIES`
without any accessor function) rather than assumed.

## Two missing-dependency compile errors, then a corrected diagnosis of probe 26

Two consecutive pushes hit `ERROR: ... Compiler Parse Error at
'HgitInit'` and then `'HgitStatus'` — in both cases because the test's
file concatenation didn't include every function `Hgit()`'s dispatcher
body references. **This is the key finding**: because all of
`Hgit()`'s `if`/`else if` branches are compiled as one function body,
HolyC must resolve every symbol *any* branch calls at compile time,
regardless of which branch actually runs at runtime. Testing `offer`
alone still requires `Init.HC`, `Status.HC` (+ `WorkDir.HC`),
`History.HC`, `See.HC` (+ `Hex.HC`) all present, not just `Offer.HC`.

**This corrects probe 26's diagnosis.** That probe hit an identical
silent-no-output symptom and guessed the cause was "inconsistent
redefinition across a long daemon session" — a plausible-sounding but
unconfirmed hypothesis. Rebuilding this probe's test with the complete
dependency set, on a **freshly rebooted, single-push session** (ruling
out any session-history effect entirely), still failed with the same
symptom until every dependency was actually included — strong evidence
the real cause all along was simply an incomplete file list, the same
ordinary mistake as `Init.HC` here, not anything about long sessions.
Recorded as a correction, not a new failure, in `failed-approaches.md`.

## What was tested, once the dependency set was complete

```
offer_repo=C:/Home/OfferTestRepo.hgs offer_mask=C:/Home/DispOfferFile* offer_msg_len=29 offer_ts=294755
DISPATCH_OK offer
SEE_COMMIT ts=294755 parents=1 msg=dispatcher offer test message
SEE_TREE entries=1
  entry type=1 name=DispOfferFile.txt
```

`offer_msg_len=29` matches `"dispatcher offer test message"` exactly
(29 characters) — confirming the message was taken verbatim, spaces
included, not truncated at the first word. Then reading the new commit
back via `HgitSee` shows the **full, multi-word message intact**
(`msg=dispatcher offer test message`) — the actual point of the
free-text design, round-tripped through a real commit, not just
constructed in memory and printed.

## Landed as real hgit-cli source

`src/hgit-cli/Hgit.HC` — `offer` branch added, logic identical to the
tested version (only a debug `CommPrint` line, not needed in the real
dispatcher, was dropped).

## Not yet done

- All five M1 commands are wired. No quoting/escaping still — a path
  containing a space breaks every branch equally.
- `offer`'s timestamp (`cnts.jiffies`) is a monotonic boot-relative
  counter, not wall-clock time — matches `Commit.HC`'s own
  already-documented caveat, not a new gap.

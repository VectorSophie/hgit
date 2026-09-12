# Probe 23 — `hgit`'s real entry point, real TempleOS

Status: **PASS, first try.** Resolves a question flagged since doc 01's
very first draft: how does an argv-taking `hgit` command fit a system
whose native command line is a live HolyC REPL?

## The research, done before writing any code

Read `Doc/CmdLineOverview.DD` directly from the real
`cia-foundation/TempleOS` clone (already checked out earlier this
session for the RedSea/`FilesFind` research). **The premise behind the
original open question was wrong**: TempleOS has no space-separated
shell-argument syntax at all. Every native command shown in that
document is a literal HolyC function call:

```
Dir("*.DD.Z");
Cd("B:/Tmp");
Ed("NewFile.HC.Z");
```

There is no `argc`/`argv`/`main()` convention to design an entry point
around, because the interactive cmd line already *is* the full
compiler — a "command" is just a function call typed at the prompt.
This reframes the actual design question from "how do we parse argv"
to "what function-call shape gives hgit a git-like feel without
inventing syntax TempleOS doesn't have."

## What was built and tested

One dispatcher function, `Hgit(cmdline)`, taking a single string (same
shape as every native command's one string argument) and splitting its
first space-separated word as a command name, dispatching to the
already-independently-verified `HgitInit`/etc. Verified:

1. `StrCmp("init", "init")` → `0` (equal); `StrCmp("init", "status")` →
   nonzero. Confirmed the real return-value convention from
   `Kernel/StrA.HC`'s actual assembly implementation before relying on
   "0 means equal" as an assumption.
2. `Hgit("init C:/Home/DispatchTestRepo.hgs")` → `DISPATCH_OK init
   C:/Home/DispatchTestRepo.hgs`, and the repo it created read back as
   genuinely valid (`hok=1 version=1 count=0`) — the dispatcher isn't
   just printing a message, it actually invoked `HgitInit` correctly.
3. `Hgit("bogus something")` → `DISPATCH_ERR unknown_command bogus`,
   handled cleanly.

Called exactly like any other TempleOS command at the interactive
prompt: `Hgit("init C:/Home/MyRepo.hgs");`

## Landed as real hgit-cli source

`src/hgit-cli/Hgit.HC` — byte-for-byte identical to the tested version.

## Not yet done

- **Only `init` is wired.** The other four commands
  (`status`/`offer`/`history`/`see`) each need more than one argument —
  `Offer` alone needs a repo path, a find mask, a message, and a
  timestamp — and splitting one string into that many typed fields
  (plus hex-string→64-byte-hash parsing for `see`'s target) hasn't been
  designed. Real next work, not a small addition.
- No quoting/escaping in the string splitter — a path or message
  containing a space would break it. Not exercised or handled.
- This resolves the M1 "compose behind an entry point" milestone
  partially (the *mechanism* is proven), not completely (four more
  commands to wire).

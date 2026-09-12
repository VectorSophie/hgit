# Probe 24 — wiring `status`/`history` into the dispatcher (found a real HolyC scoping quirk)

Status: **PASS after one fix.** Extends probe 23's dispatcher with
`status` and `history`, both straightforward multi-token cases (unlike
`offer`'s free-text message or `see`'s hex-hash parsing, deliberately
deferred).

## First attempt — a genuinely new HolyC quirk

First push produced no test output at all. A screendump showed a real
compile error: `ERROR: Duplicate member at ';'` on the line calling
`ExtractToken` inside the `history` branch.

**Root cause**: both the `status` branch and the `history` branch
declared a local named `repo_path` — in different `else if` blocks of
the *same function*. In C, each `if`/`else if` block is its own scope,
so this is completely legal. **HolyC's local-variable scoping for
`if`/`else if` branches inside one function does not appear to work
that way** — declaring the same name in two sibling branches collided
as a duplicate, even though they're never both live at once. Not
documented anywhere found so far; discovered directly by hitting it.

**Worked instead:** renamed the second declaration
(`repo_path` → `hist_repo_path`). Recompiled cleanly. **New standing
rule, recorded in `Hgit.HC`'s own comments**: give every branch's locals
distinctly-named variables in this dispatcher, don't reuse a name from
a sibling branch even though it "shouldn't" matter.

## What was tested, after the fix

Against the real repository from probes 18–22 (already showing A
modified, B deleted, C new per probe 21):

```
STATUS_MODIFIED OfferFileA.txt
STATUS_NEW OfferFileC.txt
STATUS_DELETED OfferFileB.txt
STATUS_END
commit ts=2000 msg=second
commit ts=1000 msg=first
HISTORY_END shown=2
DISPATCH_ERR unknown_command frobnicate
```

`status` and `history`, called through the string dispatcher exactly
the way a user would type them, produced identical results to calling
`HgitStatus`/`HgitHistory` directly (probes 20/21/19) — confirming the
dispatcher adds no behavior change, just a different calling
convention.

## Landed as real hgit-cli source

`src/hgit-cli/Hgit.HC` — now includes `ExtractToken` (the token-splitting
helper) plus `init`/`status`/`history` dispatch. Logic identical to the
tested/fixed version (only a more descriptive variable name than the
quick fix used during debugging).

## Not yet done

- `offer` (free-text message field, needs a different splitting
  strategy than fixed-token extraction) and `see` (hex-string→64-byte-hash
  parsing) are still unwired — the two genuinely harder cases, deferred
  deliberately, not overlooked.
- No quoting/escaping — a path containing a space would still break
  every branch, not just the ones added here.

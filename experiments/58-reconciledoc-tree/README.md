# Probe 58 — upgrade `hgit reconciledoc` to a real collapsible tree node

Status: **PASS** — the concrete follow-up probe 57 flagged (upgrading
`ReconcileDoc.HC` from flat `$LK$` + manual indentation to a real
`$TR$`/`$ID$` tree node), plus a genuine, previously-undiscovered JIT
redefinition gotcha found while verifying it.

## What this does

`src/hgit-cli/ReconcileDoc.HC`'s relation section now wraps the whole
relation in one real collapsible tree node
(`$TR,"relation: <TYPE>"$$CR$$ID,+2$ ... $ID,-2$`) instead of a flat
`relation: <TYPE> -> $LK$...` line with two-space-indented follow-up
text. The link, target message, and entity scope (if any) are now that
node's real nested children, collapsed by default per `$TR$`'s own
documented behavior (probe 57).

One real syntax constraint respected: `$TR$`'s label is a plain quoted
string argument, so the `$LK$` link and everything else stays *outside*
the quotes, as the node's `$ID,+2$`-indented body - not embedded inside
the label string (untested, and probe 57's own source study gave no
evidence it would even parse as nested commands there).

## Real gotcha found while verifying: redefining a function doesn't fix up already-compiled callers

Pushing the edited `ReconcileDoc.HC` alone compiled clean
(`COMPILE_OK`), but re-running the full `init`→`offer`→`correct`→
`reconciledoc` end-to-end test still produced the **old** flat output
- confirmed by reading the raw `.DD` bytes back, not assumed. The fix
only took effect after also re-pushing `Hgit.HC` (the dispatcher that
actually calls `HgitReconcileDoc`), even though `Hgit.HC`'s own source
hadn't changed at all.

**Why**: TempleOS's JIT compiles each pushed chunk into fresh machine
code and binds a new symbol, but a *caller* that was compiled earlier
already has a direct call instruction baked in pointing at the *old*
compiled address - redefining the callee under the same name doesn't
retroactively patch that already-compiled call site. Only recompiling
the caller itself (even with no source changes) re-resolves its call
to the new address. This matters for every future session working
against a long-running daemon: **after editing any function, every
already-compiled caller of it (not just the function itself) needs to
be re-pushed**, or the change will silently not take effect while
still reporting a clean compile - a real, easy-to-miss trap distinct
from every previously-documented HolyC quirk in this project (those
were all compile-time parse errors; this one compiles fine and just
silently runs stale code).

## Verified

- `serial-log-passing-run.txt` — three separate real runs (one
  against the two touched files pushed standalone, then one more
  against a freshly-rebuilt `packaging/HgitAll.HC` pushed whole from
  scratch as a from-scratch regression check) - each
  `init`→`offer`→`correct`→`reconciledoc`, all `DISPATCH_OK`,
  `PASS p58_tree_reconciledoc_e2e`.
- `raw-doc-content.txt` — the real `.DD` bytes read back:
  `$TR,"relation: CORRECTS"$$CR$$ID,+2$target: $LK,"<128-hex>"$<12-char>$LK$$CR$target message: offer_one$CR$$ID,-2$`
  - exactly the intended structure, not hand-typed.
- `evidence/rendered-collapsed-relation.png` — the same document open
  in `Ed()`: a real `[+] relation: CORRECTS` line, collapsed, matching
  `$TR$`'s own documented default state (probe 57) - now from a real
  command's actual generated output, not a standalone test string.

## Not yet done

- Following the link / expanding the node interactively still needs a
  human at the real console (`Ed()` blocks the daemon, per probe 54) -
  not tested here, same scoping as probe 55.
- Multiple relations in one document (e.g. a real multi-commit
  reconciliation overview, not just one commit's own relation) isn't
  built - `hgit reconciledoc` still takes exactly one commit hash.

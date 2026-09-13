# Probe 54 — DolDoc widget vocabulary from generated HolyC output

Status: **PARTIAL PASS** — closes one of doc 02's two flagged unresolved
risks, leaves the other open with a concrete reason why, and finds one
new real harness quirk along the way (not a dead end, a documented
constraint).

## What this probe answers

Doc 02 (`docs/research/02-doldoc-interface.md`) flagged: "Only
`$FG$`/`$CR$` were tested from real HolyC-generated output. Doc 02's
richer widget vocabulary (`$LK$` links, `$TR$` trees, `$LS$` lists —
the shapes a real history/reconciliation view actually wants) is still
untested from generated output." This probe tests `$LK$` and `$TR$`
specifically, since a reconciliation view (the product thesis's
headline DolDoc feature, still unbuilt) needs at minimum a clickable
link to jump between two conflicting offerings.

## What was done

`test_driver.hc`'s `P54Test()` writes a real `.DD` file via plain
`FileWrite` (same mechanism as probe 46/47, no new API):

```
$FG,5$hgit widget test$FG$$CR$$CR$
$LK,"reconcile_here"$Click this link$LK$$CR$
$TR$Root$CR$  Child A$CR$  Child B$CR$$TR$$CR$
```

Pushed and run through the real stage-2 daemon
(`experiments/01-temple-repl/`), then opened with `Ed()` and
screenshotted.

## Result: `$LK$` renders as a real link — confirmed

`evidence/rendered-doc-with-link.png` shows `reconcile_here` rendered
**underlined** (TempleOS's real link style), with `Click this link`
in plain text right after it — a genuine link widget, not literal
`$LK$` text. This directly de-risks the reconciliation view: a
generated DolDoc document can carry real clickable navigation between,
e.g., two conflicting commits' entries.

## Result: `$TR$` did not render as a tree widget — open, not resolved

The same screenshot shows `Root` / `  Child A` / `  Child B` as **plain
indented text**, no expand/collapse markers, no tree-drawing — i.e.
the syntax guessed above (`$TR$<content>$TR$`) is not the real tree
widget invocation. Doc 01/02's own primary sources don't give the full
argument grammar for `$TR$` (only that it exists, used for "trees" of
items) — getting it right needs either a real shipped `.DD` file that
uses `$TR$` (read directly, matching probe 46's own technique) or the
DolDoc routine source itself, neither pulled into this probe. **Left
open**: a reconciliation view can use `$LK$` links to fake a tree's
navigational value (nested indentation + real links between entries)
without needing `$TR$` specifically, so this doesn't block M4 design,
but the real widget's syntax is still unconfirmed.

## Real harness quirk found: `Ed()` blocks the daemon's command loop

Opening the doc with `Ed(...)` from a pushed command left the stage-2
daemon unresponsive to further pushes — a follow-up
`CommPrint(1,"STILL_ALIVE_CHECK\n");` push did **not** appear in
`serial.log` right away. Initially looked like a dropped push (this
project's known failure mode from probe 34), but re-checking the log
after sending `sendkey esc` via the QEMU monitor (closing `Ed()`)
showed `STILL_ALIVE_CHECK` **did** print, immediately followed by a
next push's `RESUMED_ALIVE` — see `serial-log-excerpt.txt`. So the
push was never lost: `Ed()` is a blocking/interactive call, and the
daemon's command loop genuinely stalls on it until the interactive
session ends; anything pushed meanwhile queues and runs in order once
it does. Documented here rather than assumed, since the project's own
standing rule is not to conflate "queued" with "dropped" without
checking.

**Implication for a real `hgit historydoc`-style command**: launching
`Ed()` (or presumably any other full-screen interactive TempleOS API)
directly from an automated/scripted context is fine for genuine
interactive human use, but it is *not* safe to call from anything that
expects the daemon to keep answering — a real constraint for how the
eventual reconciliation view's "open and let the user interact" step
should be built (a human at the real console, not a scripted push,
after the document is written).

## Evidence

- `evidence/rendered-doc-with-link.png` — the `.DD` file open in `Ed()`,
  showing the underlined `$LK$` link and the plain-text `$TR$` content.
- `evidence/after-esc-daemon-resumed.png` — back at the `C:/Home>`
  prompt after `sendkey esc`, daemon source visible, confirming a clean
  return (not a crash).
- `serial-log-excerpt.txt` — the exact sequence: `WROTE bytes=124` →
  `PASS doldoc_widgets_written` → (Ed() opened, daemon stalls) →
  `STILL_ALIVE_CHECK` appears only after `sendkey esc` → `RESUMED_ALIVE`
  right after.

## Not yet done

- `$TR$`'s real argument grammar (unresolved, see above).
- `$LS$` (list widget) untested.
- No real `hgit`-generated document uses `$LK$` yet — this was a
  standalone probe, not wired into `HistoryDoc.HC` or any new command.

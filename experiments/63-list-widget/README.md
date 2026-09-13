# Probe 63 — resolving `$LS$`'s real syntax and its fit for hgit

Status: **PASS** — closes doc 02's last remaining untested widget item
(`$LS$`, the list widget), with a clear conclusion on whether it's
usable for hgit's own DolDoc views.

## Method

Same technique as probe 57's own `$TR$` resolution: scanned every
`C:/Doc/*.DD.Z` shipped help file for the literal substring `$LS` (only
`DolDocOverview.DD.Z` matched, once), then followed its own glossary
entry's reference to a real demo file -
`C:/Demo/DolDoc/Form.HC` - and read it directly
(`real-form-demo-source-excerpt.txt`).

## The real syntax, confirmed from `Form.HC`

`$LS,D="<define-list-name>"$` is a single self-contained command (no
closing tag, like `$TR$`) bound to a struct field via `DocForm()`'s
`format` string mechanism:

```c
class FDStruct {
  I64 type format "$$LS,D=\"ST_PERSON_TYPE\"$$\n";
  ...
};
DefineLstLoad("ST_PERSON_TYPE","Child\0Teen\0Adult\0"); // registers the option strings
fds.type = 1; // the *selected index* into that list - "Teen"
DocForm(&fds); // the interactive form call that actually binds/renders it
```

So `$LS$`'s `D=` argument names a list of option strings registered
separately via `DefineLstLoad` (a null-separated string, not part of
the `$LS$` command itself), and the widget's real value comes from an
`I64` struct field `DocForm()` binds to it at render time - `$LS$`
alone, outside that binding, has no data to show.

## Verified: it renders as a real widget, but empty without `DocForm()`

`test_driver.hc` registers a define list (`DefineLstLoad`) and writes
a document containing bare `$LS,D="HGIT_REL_TYPES"$` via plain
`FileWrite` (this project's own established generation method, no
`DocForm()`/`DocPrint()` call). Opened in `Ed()`:
`evidence/rendered-empty-ls-widget.png` shows a real `[]` bracket
widget - genuinely rendered UI, not literal `$LS...$` text (same class
of confirmation as `$LK$`/`$TR$` in probes 54/57) - but empty, since
nothing bound an actual selected index to it. This is a real, useful
negative result: `$LS$` needs `DocForm()`'s runtime struct-binding to
be meaningfully populated, unlike `$TR$`/`$LK$`, which render complete
and correct from plain generated text alone.

## Conclusion: `$LS$` doesn't fit hgit's own DolDoc views the way `$TR$`/`$LK$` did

Every hgit document so far (`hgit historydoc`, `hgit reconciledoc`,
`hgit reconcileoverview`) is a **generated, static, read-oriented**
document - built once via `FileWrite`, no interactive form-editing
loop. `$LS$` is fundamentally a **form input** widget (a selectable
value bound to a live struct field through `DocForm()`, an interactive
API this project has never used and which - like `Ed()`, per probe
54's own finding - would very plausibly block the daemon's command
loop the same way). Building a real `$LS$`-based hgit view would need
`DocForm()` wired in as a genuine interactive feature (letting a human
pick a relation type, say), a different and larger scope than any
existing hgit DolDoc command. **Conclusion**: `$LS$` is resolved and
understood, but deliberately not adopted into any hgit command in this
probe - the read-only views built so far don't need it, and the
interactive form use case it's meant for is real, separate future
work, not attempted here.

## What this closes

Doc 02's own tracked "Unresolved risk" list is now empty of DolDoc
widget-syntax questions: `$FG$`/`$CR$` (probe 46), `$LK$` (probe 54),
`$TR$` (probe 57), and now `$LS$` (this probe) have all been read from
real generated or shipped-source evidence, not guessed.

# Probe 46 — DolDoc format resolved: literal text, generatable from HolyC, PASS

Status: **PASS**, real, on real TempleOS under QEMU (`serial-log.txt`,
`evidence-rendered.png`). Resolves both of `docs/research/02-doldoc-interface.md`'s
open questions with direct evidence rather than prose description —
the last real unknown standing between hgit and a real DolDoc history
view (M2's last tracked item).

## Question 1: are `$..$` commands stored as literal text, or some binary/escaped form?

Read a real, shipped TempleOS help document's raw bytes directly
(`::/Doc/CmdLineOverview.DD`, no special API — plain `FileRead`):

```
$WW,1$$FG,5$$TX+CX,"Command Line Overview"$$FG$

The cmd line feeds into the $LK,"HolyC",A="FI:::/Doc/HolyC.DD"$ compiler line-by-line as you type. ...
Look-up the function headers with $FG,2$AutoComplete$FG$ by hitting $FG,2$<CTRL-SHIFT-F1>$FG$ ...
$LK,"Click Here",A="MN:Dir"$ to see
```

**Confirmed: literal plain text.** No binary encoding, no escape
transformation — exactly the `$Cmd,Args$` syntax doc 02 already
described from prose, now seen directly in a real file's bytes.

## Question 2: can HolyC code *write* a new `.DD` file and have it render?

Built a small DolDoc string in HolyC (color commands `$FG,2$...$FG$`/
`$FG,4$...$FG$`, hard line breaks `$CR$`), wrote it with a plain
`FileWrite("C:/Home/HgitHistoryTest.DD", ...)` — the exact same call
every other file in this project already uses — then opened it with
`Ed("C:/Home/HgitHistoryTest.DD")`.

**Confirmed: yes, and it renders correctly.** The screenshot
(`evidence-rendered.png`) shows the `Ed` window with the title line and
`commit 1`/`commit 2` genuinely rendered in distinct colors from their
surrounding text, and each `$CR$` producing a real line break (three
separate visible lines, not one line with literal `$CR$` text showing)
— proof the renderer actively interpreted the commands, not just
displayed them verbatim. A follow-up `FileRead` of the same path
(`probe3_verify_bytes.hc`) confirmed the on-disk bytes are exactly the
literal text written, byte for byte — no transformation happens on
write, and `Ed()`'s rendering comes purely from interpreting that same
plain text at display time. This matches doc 02's own prediction: the
`<CTRL-T>` plain-text/rendered toggle model, now confirmed for real
rather than assumed from documentation.

`Ed()` blocks interactively (as any real editor would) — dismissed
cleanly with a single `sendkey esc`, after which the daemon resumed
normally (`COMPILE_OK`/`D_DONE` for the next push) — no cleanup issue,
no reboot needed.

## What this means for hgit

Both real unknowns doc 02 flagged before any DolDoc-generating code
could be built are now resolved:

- **No new writing mechanism needed** — a `hgit history`-as-DolDoc
  command is just building a string with `$..$` commands (same
  patterns already confirmed: `$FG,N$`/`$CR$`, and presumably
  `$LK$`/`$TR$`/`$LS$` per doc 02's prose, not independently tested
  yet) and calling the same `FileWrite` this project already uses
  everywhere.
- **No new reading/viewing mechanism needed** — TempleOS's own `Ed()`
  (or presumably other doc-aware viewers) already renders it live,
  reusing the OS's existing widget vocabulary exactly as doc 02
  predicted ("not inventing a new UI paradigm... reusing the exact
  widget set the directory browser and help system already use").

## Not yet done

- Only `$FG$`/`$CR$` were tested. Doc 02's richer widget vocabulary
  (`$LK$` links, `$TR$` trees, `$LS$` lists — the shapes a real
  history/reconciliation view would actually want) is still untested
  from real HolyC-generated output, only read from an existing help
  file.
- No real hgit command writes a `.DD` file yet — this probe is the
  research/feasibility step per the project's own "research before
  implementation" discipline; building `hgit history`'s actual DolDoc
  output is the next concrete step, not done here.
- Whether `Ed()` is the right viewer to launch from a real command (vs.
  some read-only doc-display API that doesn't put the user in edit
  mode) isn't decided - `Ed()` was used here only because it was known
  to render DolDoc live, not because it's necessarily the right UX for
  a history *view*.

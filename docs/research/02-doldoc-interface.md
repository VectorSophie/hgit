# DolDoc

## Verified documentation

Source: `templeos.info/Wb/Doc/DolDocOverview.DD.HTML`. DolDoc is "a
TempleOS document type supported by DolDoc Routines" — plain text extended
with inline two-letter dollar-delimited commands: `$<Cmd>[Flags][,Args]$`,
e.g. `$TX$` (text mode), `$CR$` (hard line break), `$TB$` (tab), `$RED$`
(color by name). Widgets use the same syntax: `$LK$` links, `$BT$`
buttons, `$CB$` checkboxes, `$LS$` lists, `$TR$` trees, with callback flags
(`+TC` tag, `+LC` left-click, `+RC` right-click). Also supports margins,
headers/footers, indentation, underline/inverse/blink, cursor positioning
(`$CU$`, `$SX$`/`$SY$`). Documents are edited as plain text and rendered
live — `<CTRL-l>` inserts a command interactively, `<CTRL-t>` toggles
plain-text view of the same file.

## Experimental evidence (this session)

The QEMU boot probe (`experiments/00-qemu-boot/boot2.png`) shows DolDoc
doing exactly this in practice, unprompted: the `T:/Home` directory
listing is rendered as a live DATE/TIME/SIZE **table inside a DolDoc
window**, not a plain-text `ls`. This is a real, running confirmation that
directory browsing in TempleOS already *is* a DolDoc view, not a separate
UI — directly relevant to the brief's "DolDoc is used where it offers a
genuinely native interface advantage" constraint: file/history/reconcile
views rendered as DolDoc are not a stretch, they're the existing norm.

## Ideas worth borrowing

- Using DolDoc's tree/list widgets for `hgit history` and the conflict
  reconciliation view (as the product thesis proposes) is not inventing a
  new UI paradigm for TempleOS — it's reusing the exact widget set the
  directory browser and help system already use. Low novelty risk.
- The plain-text/rendered toggle (`CTRL-t`) is a good model for how a
  DolDoc history/reconcile view should degrade: same underlying content,
  viewable as plain text for scripting/diffing, rendered for interactive use.

## Resolved (probe 46, `experiments/46-doldoc-format/`)

- ~~Format is not yet read byte-for-byte...~~ **Resolved**: read a real
  shipped help document's raw bytes directly (`FileRead`, no special
  API) — `$..$` commands are confirmed **literal plain text** in the
  file, e.g. `$WW,1$$FG,5$$TX+CX,"Command Line Overview"$$FG$`, exactly
  the prose-described syntax, not a binary/escaped form.
- ~~Whether DolDoc documents can be generated/written from HolyC code...~~
  **Resolved**: wrote a small `.DD` file from HolyC using plain
  `FileWrite` (color commands `$FG,N$`, hard breaks `$CR$`) and opened
  it with `Ed()` — it rendered correctly (distinct colors, real line
  breaks, confirmed via screenshot), and a follow-up `FileRead`
  confirmed the on-disk bytes are exactly the literal text written, no
  transformation on write. **No new writing or viewing mechanism is
  needed** — `hgit history`-as-DolDoc is just building a `$..$` string
  with the same `FileWrite` every other hgit command already uses, and
  TempleOS's own `Ed()` (or another doc-aware viewer) renders it live.

## Unresolved risk

- Only `$FG$`/`$CR$` were tested from real HolyC-generated output.
  Doc 02's richer widget vocabulary (`$LK$` links, `$TR$` trees, `$LS$`
  lists — the shapes a real history/reconciliation view actually
  wants) is still untested from generated output, only read from an
  existing help file.
- Whether `Ed()` specifically (vs. some read-only doc-display API) is
  the right viewer to launch from a real `hgit history` command isn't
  decided — `Ed()` puts the user in edit mode, which may not be the
  right UX for a read-oriented history view.

## Architectural implications so far

- The reconciliation view in the product thesis should target the
  existing DolDoc list/tree/link widget vocabulary rather than a bespoke
  rendering scheme — reuse, not reinvention.
- `hgit history`/`hgit see` as DolDoc output gets a plain-text fallback
  "for free" via the same CTRL-T toggle convention users already know.

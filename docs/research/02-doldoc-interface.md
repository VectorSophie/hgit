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

## Unresolved risk

- Format is not yet read byte-for-byte — only prose description. Before
  any `hgit`-generated DolDoc (e.g. a reconciliation doc) is built, need
  the actual widget help doc (`Widget.DD.HTML`, not yet fetched) and,
  ideally, a `.DD` file opened in a hex viewer to confirm whether `$..$`
  commands are stored as literal text in the file or as a binary escape
  form the text-mode toggle decodes.
- Whether DolDoc documents can be generated/written *from HolyC code*
  (not just typed interactively) hasn't been confirmed — needed for
  "executable DolDoc reconciliation" to be buildable at all.

## Architectural implications so far

- The reconciliation view in the product thesis should target the
  existing DolDoc list/tree/link widget vocabulary rather than a bespoke
  rendering scheme — reuse, not reinvention.
- `hgit history`/`hgit see` as DolDoc output gets a plain-text fallback
  "for free" via the same CTRL-T toggle convention users already know.

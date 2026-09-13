# Probe 47 — `hgit historydoc`: a real, rendered DolDoc history view, PASS

Status: **PASS**, real, on real TempleOS under QEMU
(`serial-log-passing-run.txt`, `evidence-rendered.png`). This is the
real M2 feature probe 46's research made possible — closes out the
last item on the M2 tracked-work list.

## Design

`src/hgit-cli/HistoryDoc.HC`'s `HgitHistoryDoc(repo_path, doc_path)`
walks the same parent chain `History.HC`'s `HgitHistory` already walks
(reimplemented rather than shared, since the two build very different
output shapes), but instead of `CommPrint`-ing plain text, builds a
`$..$`-formatted buffer — a colored 12-hex-char hash prefix
(`$FG,2$...$FG$`, green), a colored decimal timestamp (`$FG,4$...$FG$`),
and the plain commit message — one line per commit, most-recent-first,
then writes it with a plain `FileWrite`. `Hgit.HC` gained a
`historydoc <repo> <dest.DD>` dispatch branch.

## What was verified

`test_driver.hc`: two real commits, then `hgit historydoc`, checked
two ways.

**Raw content** (`FileRead` back, printed):
```
$FG,5$hgit history$FG$$CR$$CR$$FG,2$93bea8444eb5$FG$ $FG,4$5474700$FG$ second commit$CR$$FG,2$4c14b0fcda5b$FG$ $FG,4$5474280$FG$ root commit$CR$
```
- Correct most-recent-first order (the second commit's line precedes
  the root commit's).
- Real, distinct 12-character hash prefixes for each commit, and
  timestamps that increase in the order the commits were actually made
  (5474280 before 5474700) even though the *displayed* order is
  reversed — confirms the underlying data is correct, not just
  plausible-looking text.

**Rendered appearance** (`Ed()`, screenshotted): the title line and
both commit lines appear with their hash/timestamp portions in visibly
different colors from the surrounding text and from each other,
exactly matching probe 46's confirmed `$FG,N$` behavior — a real,
working, colored history view, not just a text file that happens to
contain dollar signs. `Ed()` was dismissed cleanly afterward
(`sendkey esc`), daemon resumed normally, no reboot needed.

## Not yet done

- Only two commits tested; no check of what happens with a much longer
  history (buffer sizing, readability) or a broken/missing parent
  chain (the function silently stops rather than erroring - untested
  in practice).
- Doesn't use DolDoc's richer widgets (`$LK$` links to jump to `hgit
  see` output for a given commit, `$TR$`/`$LS$` trees/lists) - plain
  colored lines only, per probe 46's own "not yet done" list.
- `Ed()` puts the user in edit mode to view this - a real product
  might want a read-only viewer instead; not decided or changed here.

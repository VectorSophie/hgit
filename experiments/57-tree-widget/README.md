# Probe 57 — resolving `$TR$`'s real syntax, definitively

Status: **PASS** — closes the one open item probe 54 left unresolved
("$TR$'s real argument grammar isn't in the primary sources pulled so
far"), with the strongest possible evidence: real, shipped TempleOS
demo source code (`C:/Demo/DolDoc/TreeDemo.HC`), not just prose.

## What this closes

Probe 54 guessed `$TR$<content>$TR$` (a paired open/close tag, by
analogy with `$LK$`) and found it rendered as plain text, not a tree.
That guess was wrong on two counts, both now confirmed directly: `$TR$`
takes exactly one string argument and has **no closing tag** at all,
and nesting is controlled by a separate command (`$ID$`), not by
`$TR$` itself.

## Method

Wrote a small HolyC scanner (not kept as a real command - throwaway
research code) that walked every `C:/Doc/*.DD.Z` file via `FilesFind`,
`FileRead`-ing each and searching its raw bytes for the literal
substring `$TR` - the same "read the real file directly" technique
probe 46 already established. 9 of 94 shipped help documents matched.
`DolDocOverview.DD.Z` (TempleOS's own DolDoc reference manual) turned
out to *document its own command list using* `$TR$` for each entry -
both a real usage example and, by the glossary's own admission, a
direct definition:

```
$TR,"TR Tree Widget"$
A tree widget is a branch in a collapsable tree. ...
See ::/Demo/DolDoc/TreeDemo.HC.
```

That pointed straight at a real, shipped, non-documentation demo file.
Read it directly (`real-treedemo-source.txt`) - genuine TempleOS system
source, not a webpage's paraphrase of it.

## The real syntax, confirmed from `TreeDemo.HC`

```c
DocPrint(doc,"$$TR,\"\"$$");                    // one tree-branch node (label can be empty - MA/LK below supplies real text)
DocPrint(doc,"$$MA,T=\"%s\",LM=\"...\"$$\n", ...); // this node's clickable label + action
if (tmpde->sub) {
  DocPrint(doc,"$$ID,+2$$");                    // indent - everything until the matching -2 is this node's children
  TreeSub(doc,tmpde->sub);                      // recurse - each child is itself another $TR$ (or a $LK$ leaf)
  DocPrint(doc,"$$ID,-2$$");                     // dedent - back to this node's own level
}
```

(The doubled `$$` is `DocPrint`'s own format-string escape for a
literal `$` - irrelevant to `FileWrite`-based generation, which this
project already uses; noted here only so a reader comparing this
source against `FileWrite`-emitted output isn't confused by it.)

So: **`$TR,"<label>"$` is a single, self-contained command - no
closing tag** - that inserts one collapsible tree-branch node. Nesting
isn't a property of `$TR$` itself; it comes entirely from bracketing
the children with `$ID,+2$ ... $ID,-2$` right after it, exactly the
same indent command this project's own `See.HC`/`HistoryDoc.HC`-style
code never needed before. A leaf (non-branch) entry uses plain `$LK$`
instead of `$TR$`.

## Verified by rendering

`test_driver.hc` builds a document with two top-level `$TR$` nodes
(`correct: commit abc123`, `revert: commit def456`), each with
`$ID,+2$...$ID,-2$`-bracketed detail lines, written via plain
`FileWrite` (no `DocPrint`, matching every other real hgit command).
Opened in `Ed()` and screenshotted:
`evidence/rendered-collapsed-tree.png` shows both nodes with a real
**`[+]` expand marker** - exactly matching `DolDocOverview.DD.Z`'s own
description ("a tree will start it collapsed") - not plain text, a
genuine interactive collapsible widget, generated from `FileWrite`
output with no special API, same as every other DolDoc finding this
project has made.

## Implication for `hgit reconciledoc`

`src/hgit-cli/ReconcileDoc.HC` (probe 55) currently formats a commit's
relation using plain `$LK$` plus two-space-indented plain text, not
`$TR$`/`$ID$`. That's still valid (probe 55's own rendering is
correct, just flatter) - upgrading it to a real collapsible tree (one
`$TR$` node per relation, expandable to show the target commit's
detail) is real, concrete follow-up work now unblocked by this
resolution, not done in this probe (scoped narrowly to resolving the
syntax question itself, per the project's own one-step-at-a-time
discipline).

## Not yet done

- `$LS$` (list widget) remains untested from generated output - a
  separate, still-open item.
- `ReconcileDoc.HC` itself is not yet upgraded to use real `$TR$`
  nodes - flagged above as the natural next step, not done here.

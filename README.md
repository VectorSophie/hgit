<p align="center">
  <img src="docs/brand/hgitlogowithtext.png" alt="hgit" width="160">
</p>

<h1 align="center">hgit</h1>

<p align="center">
  A version-control system written in HolyC, native to TempleOS —
  persistent file/symbol identity, executable DolDoc reconciliation,
  truthful non-destructive history, and a consistent modern CLI.
</p>

<p align="center">
  <a href="https://github.com/VectorSophie/hgit/releases/latest"><img src="https://img.shields.io/github/v/release/VectorSophie/hgit?label=release&color=blue" alt="latest release"></a>
  <a href="docs/research/01-templeos-holyc.md"><img src="https://img.shields.io/badge/language-HolyC-8B0000" alt="written in HolyC"></a>
  <a href="docs/research/08-qemu-testing.md"><img src="https://img.shields.io/badge/platform-TempleOS-000000" alt="native TempleOS"></a>
  <a href="docs/research/08-qemu-testing.md"><img src="https://img.shields.io/badge/tested-real%20QEMU-brightgreen" alt="tested on real QEMU"></a>
  <a href="INSTALL.md"><img src="https://img.shields.io/badge/install-single%20%23include-lightgrey" alt="install: single include"></a>
</p>

<p align="center">
  <a href="INSTALL.md">Install</a> ·
  <a href="#what-hgit-actually-does">Commands</a> ·
  <a href="#the-graph">The graph</a> ·
  <a href="#how-hgit-differs-from-git">vs. Git</a> ·
  <a href="docs/ARCHITECTURE.md">Architecture</a> ·
  <a href="docs/adr/">ADRs</a>
</p>

M0 through M4 of the milestone plan are complete and independently
verified on real TempleOS under QEMU — object storage, the full
command surface, stable entity identity across renames, and executable
DolDoc reconciliation views. See `docs/research/10-product-proposal.md`
for the live, dated, self-correcting record of what's actually built
— nothing here is claimed without a real, re-runnable test behind it.

The whole toolchain packages into one file (`packaging/HgitAll.HC`),
loadable with a single `#include` — there is no argv/shell syntax in
TempleOS to build a traditional CLI around (confirmed from primary
source), so `Hgit(cmdline)` is the idiomatic shape, not a workaround.

## Try it

Every line below is a real command, run against a real TempleOS
instance under QEMU — not a mockup:

```c
#include "C:/Home/HgitAll.HC";

Hgit("init C:/Home/P80Repo.hgs");
Hgit("offer C:/Home/P80Repo.hgs P80File.txt offer_one");
Hgit("offer C:/Home/P80Repo.hgs P80File.txt offer_two");

Hgit("path new C:/Home/P80Repo.hgs feature");
Hgit("path go C:/Home/P80Repo.hgs feature");
Hgit("offer C:/Home/P80Repo.hgs P80File.txt offer_on_feature");
Hgit("path go C:/Home/P80Repo.hgs main");

Hgit("graph C:/Home/P80Repo.hgs C:/Home/P80Graph.DD");
```

Real output from that exact sequence (`experiments/81-hgit-graph/`):

```
DISPATCH_OK init C:/Home/P80Repo.hgs
DISPATCH_OK offer
DISPATCH_OK offer
DISPATCH_OK path_new feature
DISPATCH_OK path_go feature
DISPATCH_OK offer
DISPATCH_OK path_go main
DISPATCH_OK graph
```

## What hgit actually does

Every command below is real, dispatched, and independently verified
on TempleOS under QEMU — not a design sketch. Run `hgit help` (once
loaded) for the same list straight from the live dispatcher.

| Command | What it does |
|---|---|
| `init` | Create a new, empty repository |
| `offer` | Snapshot matching files as a new commit (hgit's own name for git's "commit") |
| `status` | Compare the working directory against HEAD — new/modified/deleted, **and renamed** (exact-content match, ADR 0009) |
| `history` | Walk the current path's commit chain |
| `graph` | Render the entire commit history across every path as a real, collapsible DolDoc tree — see below |
| `see` | Show one commit's tree, message, and relation |
| `check` | Repo integrity: hash verification, referential integrity (`git fsck`-style missing-object check), **and dangling/unreachable-object detection** |
| `undo` / `redo` | Step through the operation log — reversible, not destructive |
| `operation history` / `operation restore` | Full operation-log vocabulary — jump to any past point |
| `path list` / `new` / `go` / `close` | Named, branch-like alternate histories sharing one object store |
| `correct` / `revert` / `reconcile` | Typed relations between commits (ADR 0005/0006) — a commit can *point at* another with real semantics, optionally scoped to one tracked entity |
| `historydoc` / `reconciledoc` / `reconcileoverview` | Executable DolDoc views — real rendered documents (colored, with live `$LK$` links and collapsible `$TR$` trees), not plain text logs |
| `export` / `import` | Whole-repo portability, own paths and history intact |
| `help` / `version` / `logo` | Discoverability and a bit of fun |

## The graph

`hgit graph` walks every declared path (not just the current one) and
renders the whole commit history as a real, native DolDoc tree — the
same collapsible `$TR$` widget TempleOS itself ships, not an ASCII
approximation. The trunk is whichever path came first; every other
path attaches as its own nested branch at the exact commit it forked
from. Reformatted for readability, the document produced by the
sequence above looks like this:

```
hgit history graph

468bbd6656 offer_one
  0c6b94e6ba offer_two
    [feature] b0598745e9 offer_on_feature
```

`offer_one` is the root; `offer_two` nests one level under it (its
real parent); `feature`'s own unique commit nests a further level
under `offer_two` — exactly its fork point, not guessed.

In TempleOS's own editor (`Ed()`), this renders as a real, native,
**collapsible** `$TR$` tree — collapsed by default (confirmed from
real shipped TempleOS docs, probe 57; that's DolDoc's own convention,
not an hgit limitation), one real click away from expanded. No
screenshot here: this project's headless QEMU test harness drives
everything through scripted keyboard/serial injection, and a real
mouse click on a collapsed tree node turned out to be a genuinely hard
thing to automate reliably (tried keyboard cursor positioning, and
absolute-positioning mouse clicks via a real `usb-tablet` device across
several attempts — none of them toggled the node). Rather than publish
a screenshot that only shows one collapsed line and calling it "the
graph," the reformatted structure above is the real, complete picture.

## How hgit differs from Git

Not a Git clone wearing a different hat — a few real, deliberate
departures, each backed by a decision doc:

| | Git | hgit |
|---|---|---|
| **File identity** | Path-based — a rename is a heuristic guess Git makes *after the fact*, from a similarity score | A stable **entity ID** travels with a tracked thing across renames, content changes, and generations (ADR 0004), independent of its current name |
| **History editing** | `rebase`/`reset --hard`/`git gc` can genuinely destroy commits; recovery means `reflog` archaeology before the grace period expires | Nothing is ever deleted. `undo` moves a pointer. A commit nobody points to anymore just sits there — `hgit check` will tell you it's dangling, not that it's gone |
| **Relations between commits** | A plain parent-pointer DAG — "this corrects that" lives in a commit message, if anywhere | Typed relations (`correct`/`revert`/`reconcile`, ADR 0005/0006) are real fields on the commit object, optionally scoped to one tracked entity |
| **Viewing history** | Plain text (`log`), or a third-party GUI | Executable **DolDoc** documents — real rendered files with live links and collapsible trees, generated by hgit itself |
| **Distribution** | A compiled binary + installer per platform | One `.HC` source file, `#include`d — matches TempleOS's own convention of no compiled binaries at all |
| **Renames** | Similarity-scored heuristic (`-M50%` by default) | Exact-content match (ADR 0009), plus real fuzzy detection for a rename-with-edit (`FossilSimilarityPercent`, ADR 0008, wired into `Offer.HC`) |

None of this makes hgit a *replacement* for Git — it makes it a
different answer to the same problem, built for a system (TempleOS)
where none of Git's own accumulated compatibility debt (packfile
formats, sharded object directories, POSIX permission bits) applies in
the first place.

## Why a burning bush?

Exodus 3: a bush burns and is never consumed. TempleOS's own creator,
Terry Davis, built an entire OS on the premise that God speaks in
640×480 and 16 colors, and was never shy about saying so — HolyC,
"the Third Temple," the whole thing. hgit doesn't share the theology.
It steals the one line that happens to describe what the tool
actually does: **history burns here, and it is never consumed.**

Every programmer has stood in front of a scorched `git reflog`,
whispering "please still be in there" after a bad rebase. hgit's
answer is structural, not miraculous: `undo` moves a pointer, it
doesn't delete anything; `hgit check` will happily tell you about
commits nobody points to anymore, because they're still just sitting
there, unharmed, in the fire. No revelation required — just an object
store that never actually throws anything away.

(We asked Terry for a code review. He'd probably have notes. We're
taking the fifth on test coverage.)

## Releases

Every tagged release attaches `packaging/HgitAll.HC` — verified
downloaded and byte-identical to the local build before being
announced done (matches TempleOS's own convention: no installer, a
program is `#include`d as one source file). Major versions now mark
real product milestones rather than every single change getting its
own tag (`docs/research/09-packaging-and-releases.md`). The
[current release](https://github.com/VectorSophie/hgit/releases/latest)
also attaches a real, ready-to-run TempleOS+hgit bundle
(`templeos-hgit.qcow2` + `hgit-launch.py`) for trying hgit on
Windows/Linux/macOS without your own TempleOS install — see
`packaging/bundle/README.md`. See the
[Releases page](https://github.com/VectorSophie/hgit/releases) for the
full, dated history.

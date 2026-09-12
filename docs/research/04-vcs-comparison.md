# VCS comparison (not started)

Nothing fetched yet for jj, Sapling, Pijul/Darcs, Fossil, GitButler,
Mercurial, Breezy, or the smaller alternatives listed in the brief. Doc 05
covers Git's object model only. This doc should not be written until at
least jj (change IDs, operation log, revsets) and Fossil (single-file repo,
delta encoding) have been read firsthand — those two are the closest
analogues to hgit's own stated goals (typed history relations, operation
log, small self-contained storage) and are called out that way in the
product thesis.

Source list to work through next, in priority order matched to the thesis:
1. jj operation log + conflicts + change IDs — directly informs ADR 0006
   (operation log) and ADR 0007 (conflict representation).
2. Fossil delta format + single-file repository — directly informs ADR 0005
   (compression) and ADR 0001 (repository model)'s storage half.
3. Sapling undo/absorb/visibility — informs the `hgit undo`/`redo` design.
4. Pijul/Darcs theory — read for comparison only; brief explicitly warns
   against adopting patch theory without evidence, so the goal here is
   "understand what it buys and costs," not "adopt."

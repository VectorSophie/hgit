# Probe 86 — `hgit diff`: a real per-commit tree diff

Status: **PASS** — a real, dedicated place for renames (and every
other kind of change) to be shown per commit, closing the gap ADR
0009's own risk-register entry named ("`hgit history`/`reconciledoc`
don't surface it yet") not by reworking `history`'s own per-line
format, but with a new command purpose-built for it.

## What was built

`Diff.HC`'s `HgitDiff(repo_path, commit_hash)`: shows what changed in
one commit relative to its own parent's tree (every entry counts as
new if the commit has no parent - a root offering). This is the
per-commit counterpart to `hgit status`'s working-directory-vs-HEAD-
tree diff (`Status.HC`) - the exact same classification vocabulary
(new/modified/deleted, exact-content AND fuzzy renames) and the same
two-pass rename-matching logic, just comparing two **committed** trees
instead of a live directory against one.

Simpler than `Status.HC` in one real way: both sides here are
already-stored blobs, so a fuzzy-match candidate's content is always
resolved on demand via the object index (`IndexLookup` + `rbuf`),
never a live `FileRead` - no need to buffer full file content ahead of
time the way `Status.HC`'s NEW-on-disk candidates require.

Wired in as `hgit diff <repo_path> <commit_hex>`, listed in `hgit
help`, added to `tools/build-package.sh` (right after `See.HC`, which
it parallels).

A real bug caught before ever reaching QEMU:
`tools/lint-package.sh` flagged a `?:` ternary (`HolyC has no ?:
ternary operator; rewrite using if/else`) - HolyC genuinely has none,
confirmed by the linter's own real rule, not guessed; fixed with a
plain `if`.

## Verified

`test_driver.hc` (`P86DiffTest`): offers four files as a root commit,
then a second commit that modifies one, deletes one, renames one
**with an edit** (fuzzy match required, not byte-identical), and adds
a genuinely new one - leaving a fifth file (`P86Stays.txt`) completely
untouched. `hgit diff` on the second commit against the first:

```
DIFF_MODIFIED P86ToModify.txt
DIFF_RENAMED P86Orig.txt -> P86Renamed.txt
DIFF_NEW P86GenuinelyNew.txt
DIFF_DELETED P86ToDelete.txt
```

All four correct, in one run - `P86Stays.txt` correctly produces *no*
output at all (matching every real diff tool's own default: silence
for unchanged entries).

`hgit diff` on the **root** commit (no parent) against nothing:

```
DIFF_NEW P86Orig.txt
DIFF_NEW P86Stays.txt
DIFF_NEW P86ToDelete.txt
DIFF_NEW P86ToModify.txt
```

Every entry correctly reported new, confirming the no-parent case is
handled (not a crash, not a guess).

**Regression**: `experiments/65-head-deletion/test_driver.hc` (the
project's full command-surface test) re-run clean.

`tools/lint-package.sh` clean (after the one real fix above) before
pushing. Package rebuilt to 200,370 bytes.

## Not yet done

- `hgit history`'s own per-commit line still doesn't show a summary of
  what changed - a user has to separately call `hgit diff` per commit
  they care about, not get it inline. A real, deliberate scoping
  choice for this probe (a new command is a smaller, safer change than
  reworking `history`'s established output format), not an oversight.
- No `$LK$`-linked DolDoc version of this (like `reconciledoc` has for
  relations) - plain `DIFF_*` lines only, matching `see`'s own
  plain-text convention rather than `historydoc`'s rendered one.

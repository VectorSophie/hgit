# Probe 71 — `hgit status` surfaces detected renames

Status: **PASS** — closes the last item ADR 0009's own "what this
slice does not do" section flagged: "does not surface the rename to
the user in any command's own output yet."

## What was built

`Status.HC`'s pass 1 (new/modified/unchanged, driven by what's on
disk) and pass 2 (deleted, driven by walking HEAD's tree) both used to
print `STATUS_NEW`/`STATUS_DELETED` immediately as each file was
checked. They now buffer NEW-on-disk candidates (name + content hash)
and DELETED-from-tree candidates (name + content hash) instead, then
run one more pass matching them by exact content hash - a match prints
a single `STATUS_RENAMED <old> -> <new>` line instead of two separate
`STATUS_NEW`/`STATUS_DELETED` lines. This is the same exact-content
matching ADR 0009 already uses in `Offer.HC` via `TreeFindEntryByHash`,
just applied to working-directory-vs-HEAD-tree status instead of
old-tree-vs-new-tree at offer time. It only *reports* the match - it
doesn't change what gets committed; a subsequent real `hgit offer`
still does its own independent rename detection.

MODIFIED/UNCHANGED files are unaffected (still printed immediately,
same as before) - only the NEW/DELETED classification needed
deferring, since only those two are rename candidates.

## Verified

`test_driver.hc` (`P71StatusRenameTest`): initializes a fresh repo,
offers three files (`P71Orig.txt`, `P71Stays.txt`,
`P71WillDelete.txt`), then - without another offer - simulates an
out-of-band rename (`Del()` the real TempleOS file-delete API,
confirmed correct via `experiments/21-status-deleted/`'s own prior
usage; `FileDelete`/`FDelete`/`DiskDelete`/`FileDel` are all NOT real
TempleOS identifiers, each rejected by the compiler with a different
real error - logged in `docs/research/failed-approaches.md`) of
`P71Orig.txt` to `P71Renamed.txt` (identical content), deletes
`P71WillDelete.txt` for real, and creates a genuinely new
`P71GenuinelyNew.txt`. `hgit status` then reports, in one real run:

```
STATUS_UNCHANGED P71Stays.txt
STATUS_RENAMED P71Orig.txt -> P71Renamed.txt
STATUS_NEW P71GenuinelyNew.txt
STATUS_DELETED P71WillDelete.txt
STATUS_END
```

All four classifications correct in the same run - the rename
detected without a false positive against the genuinely-new/genuinely-
deleted files also present, which is the real test (a repo with only
one NEW and one DELETED file could pass a buggy "just match whatever's
left" implementation; this one has an extra unrelated NEW and an extra
unrelated DELETED file specifically so a wrong implementation would
either miss the real rename or wrongly pair up the unrelated ones).

**Regression**: re-ran `experiments/65-head-deletion/test_driver.hc`
(the project's standing full command-surface regression) immediately
after - `init`/`offer`/`undo`/`redo`/`path new`/`path go`/`history`/
`status`/`check`/`historydoc`/`see` all still correct
(`PASS p65_head_deletion_regression`), confirming the buffering
rewrite didn't change ordinary status behavior.

`tools/lint-package.sh` clean before every push (only the 3 known
built-in-manifest gaps).

## Real quirks hit while building this

- **The no-`continue`-keyword gap bit again, in my own new code this
  time** (previously only confirmed via the parser's own bug-compat
  corpus, probe 56): `if (new_matched[ni]) continue;` compiled to a
  real, immediate lint error (`continue is not... a known TempleOS
  built-in`) before it was even pushed to QEMU - caught by
  `tools/lint-package.sh`, not by a wasted QEMU round trip. Fixed by
  restructuring to a guarded `if`.
- **The "duplicate member" sibling-block quirk hit twice more**,
  independently, in this same function: `I64 cap` declared in two
  separate (not nested) `if` branches of `HgitStatus`, and separately
  `Bool same` declared in two separate loops. Both are real, this
  project's fourth+ independent hit of this same documented HolyC
  quirk (`docs/research/01-templeos-holyc.md`) - a reminder (like
  probe 59's own repeated `pi` collision) that a documented gotcha
  doesn't reliably prevent re-triggering it while writing new code
  quickly.
- **No `FileDelete`/`FDelete`/`DiskDelete`/`FileDel` in real
  TempleOS** - all four guessed names failed, three different ways
  (`FileDelete`/`FDelete`: clean "Undefined identifier"; `DiskDelete`/
  `FileDel`: a stranger "Invalid lval"/"Compiler Parse Error" pair,
  not yet explained - logged as a genuine unresolved oddity, not
  chased further since a real name was found). The real, correct
  TempleOS API is `Del(filename, FALSE, FALSE, FALSE)`, confirmed by
  finding it already used - correctly, with a comment noting the same
  earlier "not FileDel" confusion - in `experiments/21-status-deleted/`'s
  own `tested_source.hc` from much earlier in this project.

## Not yet done

- `hgit history`/`hgit reconciledoc` don't surface a rename the same
  way `status` now does - this was scoped to `status` only, since it's
  the command that already does a working-dir-vs-tree comparison;
  extending the same idea to a commit-vs-commit history view is
  separate, real follow-up work.
- The `DiskDelete`/`FileDel` "Invalid lval" parser oddity isn't
  explained - not chased further since it wasn't blocking (a working
  delete API was found), logged as an open curiosity, not a solved
  quirk.

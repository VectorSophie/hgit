# ADR 0015 — minimal tracked attributes and file modes

## Status

**Implemented.** Per `docs/ROADMAP-v1.8.md`'s v1.8.1 scope. Written
before implementation, per the roadmap's own explicit instruction to
determine the real TempleOS filesystem semantics first, then design a
portable representation - not invent Unix behavior TempleOS cannot
observe.

## Context: what the real filesystem actually exposes

Checked directly against real TempleOS kernel source
(`Kernel/KernelA.HH`) rather than assumed. RedSea's real per-file
`attr` field (`CDirEntry.attr`, a `U16`) is a DOS/FAT-style attribute
bitmask, not a Unix permission model:

```text
RS_ATTR_READ_ONLY   0x01
RS_ATTR_HIDDEN      0x02
RS_ATTR_SYSTEM      0x04
RS_ATTR_VOL_ID      0x08
RS_ATTR_DIR         0x10  (already used throughout hgit, `attr & 16`)
RS_ATTR_ARCHIVE     0x20
RS_ATTR_DELETED     0x100
RS_ATTR_RESIDENT    0x200
RS_ATTR_COMPRESSED  0x400
RS_ATTR_CONTIGUOUS  0x800
RS_ATTR_FIXED       0x1000
```

**There is no execute bit, and no owner/group/world permission model of
any kind.** TempleOS runs code via `#include`/JIT-compilation of
HolyC source - "executable" is not a stored permission on a file at
all, it's a property of what a file's CONTENT is (real, runnable
HolyC), never something the filesystem itself flags. This directly
answers the roadmap's own question: hgit's own `executable` concept,
if tracked at all, cannot be auto-detected from the real filesystem -
it can only ever be a user-declared convention (via
`.hgitattributes`), never inferred from anything RedSea itself
exposes. Confirmed via primary source, not assumed.

## Decision

### Text-vs-binary: the NUL-byte heuristic, same as Git's own real, documented approach

Checked against real, current documentation before adopting (not
invented): Git's own `is_binary` check considers any blob binary if a
NUL byte appears anywhere in the first 8000 bytes it scans -
documented and confirmed via real sources
(`ratatoskr.run/git/2016/06/7327483/t`, Git's own mailing-list patch
discussion; `codestudy.net`'s own writeup of the same behavior). hgit
adopts the identical rule: scan up to the first 8000 bytes of a file's
real content for any `0x00` byte; if found, classify as binary,
otherwise text. A real, deterministic, already-proven convention, not
a bespoke heuristic invented for this project.

### `.hgitattributes`: same grammar and matching engine as `.hgitignore`

Do not build a second bespoke pattern-matching engine. `Attrs.HC`
reuses `Ignore.HC`'s own `IgnoreGlobMatch`/pattern-kind machinery
(NAME/DIR/DIR_CONTENTS, ADR 0014) for consistency and to avoid
duplicating logic ponytail's own "reuse before reinventing" discipline
already argues for. Grammar: `<pattern> <attr>[,<attr>...]`, one rule
per line, e.g.:

```text
*.png binary
*.hc text,executable
build/* binary
```

Supported attributes, minimal per the roadmap's own instruction not to
copy `.gitattributes` wholesale: `text` (force text classification),
`binary` (force binary classification), `executable` (a real,
declarative-only property - see above, never auto-detected). No
`merge`/`diff` DRIVER attributes - hgit has no pluggable diff/merge
driver concept to select between (a real, separate, much bigger
feature this project doesn't have and isn't building here); `binary`
already carries the real, load-bearing meaning the roadmap's own
"binary files never fed blindly into a textual merge" requirement
needs (see "What this does not do yet").

Last-matching-rule-wins, same real precedence `.hgitignore` already
uses. Unrecognized attribute names are diagnosed
(`ATTR_UNSUPPORTED <name>`) and skipped, not guessed at - naming the
supported grammar explicitly, per the roadmap's own instruction.

### Persisted representation: a commit-level side-channel, NOT a tree-entry format change

The real design decision this ADR exists to freeze. Two shapes were
considered:

**Rejected: embed a mode byte directly in each tree entry** (matching
Git's own real `100644`/`100755` mode field). Real problem found by
checking the actual blast radius before choosing: `Tree.HC`'s own
entry shape (`[name_len][name][type][64-byte hash][8-byte entity_id]`)
is manually re-parsed with hardcoded byte offsets in **eight separate
files** (`Check.HC`, `Diff.HC`, `Offer.HC`, `Merge.HC`, `See.HC`,
`Status.HC`, plus `Tree.HC`/`Index.HC` themselves) - changing the
per-entry STRIDE would require every one of those to become
version-aware (a v2 repo's entries are 74 bytes wide, unmoded; a v3
repo's would be 75), a real, serious silent-misparse risk if any one
call site is missed (reading a subsequent entry's own length byte as
if it were a mode byte, corrupting every entry after it). A real,
avoidable risk given the alternative below carries none of it.

**Adopted: a new `OBJ_ATTRS` object, referenced by an optional trailing
field on the COMMIT object.** `Commit.HC`'s own real design already
established the pattern this needs (`docs/adr/0005-typed-relation-vocabulary.md`'s
own relation fields, placed after the message, read by recomputing
their own start offset from `CommitMessageLen` rather than assuming a
fixed position) - this ADR's own attrs field follows the exact same
convention, placed AFTER the relation fields:

```text
U8   has_attrs        (0 = no non-default modes exist in this commit's
                        tree at all - the common case, costs exactly
                        one byte, same "optional field, zero cost when
                        unused" pattern relation_tag already uses)
if has_attrs != 0:
  64 bytes attrs_hash  (the real OBJ_ATTRS object for this commit)
```

This is genuinely, structurally safe in both directions with **no
version branching needed at all**: old (pre-ADR-0015) code reading a
new commit simply never reads past the relation fields, so the
trailing `has_attrs` byte (and `attrs_hash` if present) is invisible
to it - no misparse, nothing to guard. New code reading an OLD commit
correctly computes `has_attrs`'s own offset from that commit's real
`CommitMessageLen`/relation-field length, lands past the end of a
short (no-attrs-field) old record, and - because `Commit.HC`'s own
accessors already only ever read exactly as many bytes as the record
`length` field says exist (`HgsPut`'s own record framing) - needs one
explicit bounds check (`is this offset still inside the record?`)
before reading `has_attrs`; if not, treats it as `has_attrs=0` (an old
commit genuinely has no attrs, which is simply true). One `if`, not a
cascading reparse.

`OBJ_ATTRS` content: `U32 count`, then `count` times
`[U64 entity_id][U8 mode]` - a flat list, same shape convention as
`Tree.HC`'s own entry list. `mode` is a real bitmask:
`MODE_BINARY = 0x01`, `MODE_EXECUTABLE = 0x02`. Only entities whose
EFFECTIVE mode is non-default (i.e., binary and/or executable - plain
text is the default, free, never listed) get a record - the same
"pay only for what you use" economy `has_attrs` itself already
establishes for the whole feature.

**Keyed by entity ID, not name or path** - per the roadmap's own
explicit requirement ("persistent entity identity remains independent
of content hash, path, and mode"). A file's mode survives a detected
rename automatically, for free, because entity ID already does (ADR
0004/0009) - no separate carry-forward logic needed for mode itself.

**A full snapshot per commit, not a diff from the parent** - matching
this project's own object model throughout (trees are full snapshots
too, never deltas against a parent). `hgit offer` recomputes every
offered file's own effective mode fresh each time (auto-detect +
`.hgitattributes` override), the same way it already recomputes
content hashes fresh each time - mode is a real PROPERTY of current
file state, not carried-forward identity.

### `format_version` bump to 3

A real, additive format change - `FORMAT.md` updated, `Init.HC` writes
`3` for new repos. Not because it's technically required for
correctness (both directions already work, see above) but because the
format's own real vocabulary grew (`OBJ_ATTRS`, `MODE_BINARY`/
`MODE_EXECUTABLE`, the commit's own new optional field) and the
project's own standing discipline (ADR 0004/0010/0011's own real
breaking changes, and the real gap ADR 0014 found and corrected
in `format_version`'s own history) says: bump when the format's real
shape changes, don't wait to be asked twice.

## What this does not do yet

- No pluggable `merge`/`diff` driver selection (git's own real
  concept) - hgit has no such mechanism to select between; `binary`
  is the one real signal this ADR provides for "don't treat this like
  text," and the roadmap's own later item (a complete three-way merge)
  is where that signal actually gets consulted, once a real
  line-based text merge algorithm exists to need guarding from binary
  content in the first place. Not built here - there is nothing yet
  for it to guard.
- No unsupported-filesystem-type handling beyond what's already true:
  no case has been observed (TempleOS's own `FilesFind` never
  surfaces a symlink, device file, or anything else hgit's own object
  model can't represent) - honestly left as "not yet a real problem,"
  not solved speculatively.
- Does not retroactively compute mode for any object already
  committed before this ADR - a version-2 repo's commits simply have
  no attrs (real, accurate: `has_attrs=0`), not a gap to migrate.

## What would justify revisiting this

- Real evidence that `text`/`binary`/`executable` aren't enough - a
  real hgit workflow needing a fourth attribute this project hasn't
  seen yet.
- Real evidence the NUL-byte heuristic misclassifies a real file type
  hgit's own users actually track - not yet observed.

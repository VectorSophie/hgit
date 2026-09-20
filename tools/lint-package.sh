#!/usr/bin/env bash
# lint-package.sh — host-side HolyC syntax/reference check before
# paying the ~1-minute QEMU round-trip cost.
#
# Uses `holyc-parser` (experiments/templeos-devkit/holyc-parser/), a
# from-scratch HolyC lexer/parser/symbol-resolver found and read
# during doc 07's own research, never previously adopted into this
# project's actual workflow despite that doc recommending exactly this
# "host-side lint + QEMU ground truth" two-tier model.
#
# Verified (docs/research/07-portability-and-toolchains.md): linting
# packaging/HgitAll.HC directly (the already-dependency-ordered
# concatenation build-package.sh produces) against the real, full
# 23-file hgit-core+hgit-cli corpus reports exactly 8 findings, all of
# them the same three real TempleOS kernel built-ins
# (`FilesFind`/`DirTreeDel`/`cnts`) not yet in this parser's own
# built-ins manifest - a real, confirmed gap in the *tool*, not a bug
# in hgit's own source. Passing the same files in raw directory order
# instead of dependency order produces 60 false positives, because the
# parser enforces the same "no forward declarations" rule real HolyC
# has (probe-confirmed independently, docs/research/01-templeos-holyc.md) -
# so always lint the already-ordered package, not the raw directories.
#
# (v1.8.9: `argv` - the implicit variadic-args names, and StrPrintJoin, used by the CommPrint
# override in Canon.HC - and `AutoComplete` are real TempleOS names the parser
# doesn't know either; same category.)
#
# Exit code: 1 if the parser reports any errors, 0 otherwise - the
# three known built-in gaps below are filtered out of the pass/fail
# decision (but still shown) since they're a confirmed tool
# limitation, not a real problem; anything else reported is real and
# should be fixed before pushing to QEMU.

set -euo pipefail
cd "$(dirname "$0")/.."

PARSER_DIR="experiments/templeos-devkit/holyc-parser"
BIN="$PARSER_DIR/target/release/holycc"

if [ ! -x "$BIN" ]; then
  echo "Building holycc (one-time)..."
  (cd "$PARSER_DIR" && cargo build --release)
fi

KNOWN_BUILTIN_GAPS='`FilesFind`|`DirTreeDel`|`cnts`|`argv`|`argc`|`StrPrintJoin`|`AutoComplete`|`FileFind`|`PutS`'

OUTPUT=$("$BIN" lint packaging/HgitAll.HC || true)
echo "$OUTPUT"

REAL_ERRORS=$(echo "$OUTPUT" | grep ': error:' | grep -vE "$KNOWN_BUILTIN_GAPS" || true)
if [ -n "$REAL_ERRORS" ]; then
  echo ""
  echo "lint-package.sh: real error(s) found, not just known built-in gaps - fix before pushing to QEMU."
  exit 1
fi
echo ""
echo "lint-package.sh: no real errors (only the three known built-in-manifest gaps, if any) - safe to push."

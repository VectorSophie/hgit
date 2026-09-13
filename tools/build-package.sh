#!/usr/bin/env bash
# build-package.sh — concatenates hgit-core + hgit-cli into one
# self-contained HolyC file, in dependency order, that a real TempleOS
# user can load with a single #include.
#
# Verified (experiments/28-hgit-package/): a fresh TempleOS boot,
# `#include "C:/Home/HgitAll.HC";` (the file this script produces,
# transferred to the guest), then `Hgit("status ...");` worked
# correctly - one #include, the whole tool, exactly like loading any
# other native TempleOS program per Doc/CmdLineOverview.DD's own
# convention ("To run a program, you typically #include it").
#
# Order matters: each file may reference symbols defined in an earlier
# one (e.g. Object.HC's ObjectPut calls Hgs.HC's HgsPut) - this list is
# a topological order of every dependency chain in src/hgit-core and
# src/hgit-cli today. If a new file is added, add it after everything
# it depends on, not just at the end.

set -euo pipefail
cd "$(dirname "$0")/.."

OUT="packaging/HgitAll.HC"
mkdir -p packaging

cat \
  src/hgit-core/Canon.HC \
  src/hgit-core/Blake2b.HC \
  src/hgit-core/Archive.HC \
  src/hgit-core/Hgs.HC \
  src/hgit-core/Object.HC \
  src/hgit-core/Tree.HC \
  src/hgit-core/Commit.HC \
  src/hgit-core/Index.HC \
  src/hgit-core/Meta.HC \
  src/hgit-cli/Init.HC \
  src/hgit-cli/Paths.HC \
  src/hgit-cli/WorkDir.HC \
  src/hgit-cli/Status.HC \
  src/hgit-cli/History.HC \
  src/hgit-cli/Hex.HC \
  src/hgit-cli/Check.HC \
  src/hgit-cli/HistoryDoc.HC \
  src/hgit-cli/ReconcileDoc.HC \
  src/hgit-cli/See.HC \
  src/hgit-cli/OpLog.HC \
  src/hgit-cli/Portable.HC \
  src/hgit-cli/Offer.HC \
  src/hgit-cli/Logo.HC \
  src/hgit-cli/Hgit.HC \
  > "$OUT"

echo "wrote $OUT ($(wc -c < "$OUT") bytes)"

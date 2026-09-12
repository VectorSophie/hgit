# Probe 39 — `.HGS` archives are genuinely portable, PASS

Status: **PASS**, real, on real TempleOS under QEMU
(`serial-log-passing-run.txt`, `evidence-pass.png`). This is a
verification probe, not new HolyC — it confirms a property the format
was designed to have (ADR 0001/0002: content-addressed objects, no
path-based indirection) actually holds on disk, rather than assuming
it from the design alone.

## What was tested

Two real commits in `C:/Home/P39Repo.hgs`, HEAD's hash noted from the
*original* repo. Then a **raw byte copy** of only the `.hgs` file
itself (`FileRead` + `FileWrite`, no sidecars) to a brand-new filename,
`C:/Home/P39Copy.hgs`. Confirmed the copy has **no** `.head` sidecar of
its own (`copy_has_no_head_sidecar=1`) — so anything that works
against the copy can only be coming from the `.hgs` bytes themselves,
nothing else. Then `hgit see` on the **copy**, using the hash noted
from the **original** before the copy ever happened:

```
original_head2_hex=254f3f0673e0338e...15406a3
copy_size=866 original_size=866
copy_has_no_head_sidecar=1
SEE_COMMIT ts=4620427 parents=1 msg=second commit
SEE_TREE entries=1
  entry type=1 name=P39FileA.txt
SEE_END
```

- The copy is byte-for-byte the same size as the original (a plain
  `FileRead`/`FileWrite` round-trip, no format-level surprises).
- `see` on the copy, given only a hash, correctly walks commit → tree
  → entry using nothing but the copied file's own bytes: the right
  message ("second commit"), the right parent count (1), the right
  tree (1 entry, the right filename). This is real evidence the
  content-addressed design works as intended — no repo path, no
  original filename, and no sidecar bookkeeping leaked into the
  archive's own bytes.

## Scope, honestly

This confirms the **object layer** (blobs/trees/commits, `Index.HC`'s
lookup) is portable. It does **not** by itself make a whole *working
directory + tool state* portable — `HEAD`, the operation log, and
named paths are all separate sidecar files keyed off the exact repo
path string, and copying just the `.hgs` file (as done here,
deliberately, to isolate the object layer) leaves a copy with no
current offering, no history, no paths — `hgit history`/`hgit status`
on the copy would report "nothing yet," not because the format failed,
but because those sidecars weren't copied along. Making the *whole
tool experience* (not just the object bytes) portable — e.g. a
`hgit export`/`hgit import` that bundles or reconstructs sidecar state
too — is real future work, not built or tested here.

# Probe 122 - persistent conflicts (ADR 0016, v1.8.3)

Real QEMU/TempleOS results (captured from the shared daemon's serial log):

- `e2e_resolve_continue.hc`: two paths edit one file differently. `merge` printed
  `MERGE_CONFLICT conflict.txt` / `MERGE_CONFLICTS_PERSISTED`; `status` printed
  `STATUS_MERGE_IN_PROGRESS conflicts=1 unresolved=1`; `conflicts` listed
  `CONFLICT 0 UNRESOLVED kind=1`; `resolve 0 take-theirs` -> `RESOLVE_OK`;
  `merge continue` -> `MERGE_OK` (HEAD is a real 2-parent commit, confirmed via `see`);
  `check` -> `CHECK_OK format_version=3`, `CHECK_REFS_OK`, one honest
  `CHECK_DANGLING conflict` (the cleared OBJ_CONFLICT, ADR 0016's accepted tradeoff).
- `e2e_abort.hc`: `merge abort` -> `MERGE_ABORT_OK`, `conflicts` -> `CONFLICTS_NONE`,
  HEAD unchanged (`P121_HEAD_UNCHANGED=1`), `CHECK_REFS_OK`.
- Fresh `init` after the bump: `CHECK_OK objects=0 format_version=4`.
- Standing regression `PASS p65_head_deletion_regression`; `tests/full-regression.hc`
  ran to `TFULL_END` with every section clean.

Not verified: byte-level content of the resolved file (only structure/2-parent/check).

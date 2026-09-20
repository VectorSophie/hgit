# Probe 123 - rename-aware merge (ADR 0017)
Real QEMU: rename(a->c) on main + edit(a) on feat => `MERGE_OK`, merged tree
{b.txt, c.txt}, `diff` vs first parent shows `DIFF_MODIFIED c.txt` (the edit was
applied to the renamed file), `CHECK_REFS_OK`. Rename a->c vs a->d => both
`MERGE_RENAME_RENAME a.txt`, `MERGE_REFUSED`, HEAD unchanged, no conflicts persisted.
Full regression re-run afterwards: every section clean to `TFULL_END`.

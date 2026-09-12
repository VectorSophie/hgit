// WorkDir.HC — working-directory enumeration, for `hgit status`/
// `hgit witness`. First use of TempleOS's real filesystem enumeration
// API (`FilesFind`/`CDirEntry`), confirmed from primary source
// (`Kernel/BlkDev/DskFind.HC`, `Adam/Opt/Utils/DocUtils.HC` in the real
// cia-foundation/TempleOS mirror) before writing this, then verified
// running (experiments/15-dir-enumeration/): lists every file in the
// current directory with correct name and size, including the special
// `.`/`..` entries a caller must filter out.
//
// No dependencies beyond kernel built-ins (FilesFind, CDirEntry,
// DirTreeDel).

// Prints every entry FilesFind("*", 0) returns (including `.`/`..` -
// callers that care should skip names ending in exactly "." or "..").
// This is a placeholder "status"-shaped listing, not real status logic
// yet - no comparison against any recorded tree, just "what's here."
//
// Uses CommPrint (COM1), matching exactly what was tested - this was
// verified via the same host-visible-log convention every other probe
// uses, not via screen output. Switch to Print() for real interactive
// use once this is wired into an actual command, but that specific
// substitution has not itself been tested.
//
// The initial test (experiments/15-dir-enumeration/) ran this loop as a
// bare top-level statement and worked, but per the standing project
// rule (doc 01, probe 05's crash-causing quirk) bare top-level loops
// with local declarations can silently misbehave. This function-
// wrapped form was written as the safer, rule-following version and
// then independently re-verified (not just assumed equivalent) with an
// identical result - see experiments/15-dir-enumeration/README.md.
U0 WorkDirList()
{
  CDirEntry *tmpde = FilesFind("*", 0);
  CDirEntry *tmpde1 = tmpde;
  while (tmpde) {
    CommPrint(1, "%s  %d\n", tmpde->full_name, tmpde->size);
    tmpde = tmpde->next;
  }
  DirTreeDel(tmpde1);
}

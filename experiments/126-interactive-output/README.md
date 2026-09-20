# Probe 126 - what a person at the QEMU window actually sees (v1.8.9)

Found while investigating the owner's screenshot (`hgit history graph` typed with
the AutoComplete popup open): booted the refreshed bundle with NO serial port (as
`hgit-launch.py` does) and ran `Hgit("version")` - **nothing appeared**. Every hgit
report goes through `CommPrint`, which TempleOS sends only to a serial port; the
automated harness reads that, a person cannot. (Also: the AutoComplete popup binds
digit/F-keys and can rewrite a half-typed command; and a missing file made `FileRead`
print a red ERROR on screen for every new repo.)

Fix (v1.8.9): `CommPrint` override with an optional screen echo (`hgit_screen_out`),
`Hgit("interactive")` (echo on, AutoComplete off; the launcher runs it), and
`HgitFileRead` (FileFind-guarded) so probing for absent files is silent.
`screen-after-interactive.png` (tools/verify-bundle.py) shows the result on the real
image: INTERACTIVE_ON, HGIT_VERSION 1.8.9, DISPATCH_OK init, HISTORY_EMPTY, HELP list,
no red errors. Full + standing regression unchanged (serial path untouched).
Also: the shell-style `hgit history graph` in the screenshot is not valid - TempleOS has
no argv shell; the command is `Hgit("history <repo>");` (documented in the bundle README).

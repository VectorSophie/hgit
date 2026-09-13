# Probe 75 — attempting a real end-user "install media" flow (CD-ROM)

Status: **PARTIAL / open finding, not solved** — attempted to verify a
real, non-dev-tooling way for a user to get `packaging/HgitAll.HC`
onto a real TempleOS machine (closing doc 09's own "no install
instructions doc exists yet" gap the honest way, by actually testing
one, not just writing prose about it). The specific mechanism tested
(a second IDE CD-ROM drive) was **not** conclusively verified working;
logged as a real, dated dead end rather than forced into a false
"solved" claim. See `docs/research/failed-approaches.md`'s matching
2026-09-13 entry.

## What was done

A real, useful technique first: a **safe, disposable QEMU probe VM**
was booted from this project's own long-lived `disk.qcow2`, using
`-snapshot` plus `file.locking=off` on that drive, alongside a second
attached IDE drive (`ide1-cd0`) carrying a small data ISO built with
`mkisofs`/`genisoimage` containing `packaging/HgitAll.HC`. This let a
real "what if" be tried against the project's actual accumulated
TempleOS state **without any risk to the long-running dev daemon
session** other probes in this project depend on - confirmed
afterward: the main daemon (`ps aux`) was untouched throughout, and
`disk.qcow2`'s own mtime never changed. Worth keeping as a reusable
technique for future exploratory probes that want to poke at a real,
already-installed disk without risking it.

Then, at a real `C:/Home>` prompt (booted via the same monitor-sendkey
dance every prior probe uses), several drive letters were tried via
`Dir("<letter>:/")`:

- `A:`, `E:`, `F:`, `G:`, `H:` - each threw a real (non-fatal - the
  prompt returned cleanly each time) TempleOS exception
  (`DrvChk+0x02E` / `SetDrv+0x006C`), meaning none of these letters
  are valid drives in this setup.
- `D:` - a real, valid drive, showing the same file listing as
  `C:/Home`'s own parent (`0000Boot`, `Adam`, `Doc`, `Kernel`, etc.) -
  strongly suggesting `C:` is not a separate physical drive at all,
  but an alias/redirector onto the real boot drive TempleOS itself
  calls `D:` by default.
- `B:` - a real, valid drive, but reporting **0 entries** both before
  and after hot-swapping the attached CD image's real content via the
  QEMU monitor's `change ide1-cd0 <path>` command (confirmed the swap
  itself worked via `info block`, the reported backing file changed).
  This means either `B:` isn't the attached CD-ROM at all (some other
  always-present empty virtual drive), or it is the CD but TempleOS
  doesn't pick up newly-changed media without an explicit rescan this
  probe didn't find.

Two ISO variants were tried (Joliet+RockRidge via `mkisofs -J -r`, and
a second plain ISO9660-only build without either) - `B:` reported
empty for both, so the ISO's own feature set wasn't pursued further as
the variable in question, since drive identity was already the more
likely blocker.

## Why this was stopped here, not pushed further

- The real product question this was trying to answer - "does hgit's
  release artifact reach an installed TempleOS machine as more than a
  dev-tooling exercise" - already has a genuinely verified answer that
  didn't need this probe at all: **COM2 serial injection**
  (`paced_push.py`), the exact mechanism this entire project has used
  for every one of its 74 prior probes, is real, proven, end-to-end
  verified transport for getting a `.HC` file's content onto a real
  TempleOS machine. A second CD-based path would be a nice-to-have
  alternative, not a blocker for anything.
- The specific drive-letter mapping for a QEMU-attached secondary IDE
  CD is host/VM-configuration-specific, not a fact about hgit or even
  about TempleOS in general - even if fully solved here, it wouldn't
  generalize to a real user's own real hardware, whose drive letters
  depend on their own BIOS/IDE wiring. Writing hgit's own install
  documentation around a guessed drive letter this specific would risk
  being actively wrong for most real setups.
- Given both of the above, further QEMU-monitor/ISO-variant iteration
  here would be chasing a low-value detail relative to the time it
  costs - a judgment call, not a wall hit; logged honestly as "not
  solved, not worth more time" rather than continuing indefinitely.

## What this did confirm, usefully, despite not solving the main question

- `-snapshot` + `file.locking=off` is a real, verified-safe way to boot
  a disposable exploratory VM off this project's own long-lived disk
  image without risking it or the main daemon session - reusable for
  future probes that want to try something against real accumulated
  state without commitment.
- TempleOS's own `Dir()` on a nonexistent drive letter throws a real,
  non-fatal exception (prints a trace, returns to the prompt) rather
  than crashing the VM - safe to probe drive letters this way.
- `C:` is very likely an alias/redirector onto the real boot drive
  (`D:` in this setup), not a distinct physical drive of its own -
  a fact worth knowing if this project ever needs to reason about
  drive identity again.

## Not yet done

- The actual CD-ROM drive letter (if `B:` isn't it) remains unfound.
- Whether TempleOS needs an explicit remount/rescan command for
  already-attached removable media whose backing file changes was not
  determined.
- A genuinely user-facing install doc was written anyway
  (`INSTALL.md`, repo root) - built around the one mechanism this
  project has actually verified end-to-end (serial transfer), not the
  unverified CD path this probe explored.

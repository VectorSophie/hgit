# Probe 48 — `RandU32` confirmed real and usable, PASS

Status: **PASS**, real, on real TempleOS under QEMU (`serial-log.txt`).
First step of M3 (stable entity identity + typed relations, per the
brief) — before designing an ID scheme, confirms TempleOS actually has
a usable random-number source to build one from.

## Real source evidence

`cia-foundation/TempleOS` (cloned earlier this project,
`/tmp/temple-src-check`):

- `Kernel/BlkDev/FileSysFAT.HC:88`: `br->serial_num=RandU32;` — a real
  kernel API using `RandU32` for an actual filesystem serial number.
- `Demo/RandDemo.HC`: `RandU16`/`RandU32` used directly (no call
  parentheses — a bare global identifier, not a function call syntax)
  for randomized pixel plotting, alongside `Seed(0)`/`Seed(num)` to
  control determinism.

## What was verified empirically

`probe1_randu32.hc`, three successive reads:

```
a=2182622941 b=2622862472 c=1307883381
all_distinct=1
```

Confirmed: `RandU32` returns genuinely distinct 32-bit values across
successive reads, used exactly as source usage suggested (a bare
identifier, no special initialization needed).

## What this enables

`docs/adr/0004-stable-entity-identity.md`: a per-tree-entry 64-bit
entity ID (two `RandU32` reads combined), generated once per new file
name and copied forward across offers — the first concrete design step
of M3. Not yet implemented; this probe only confirms the primitive it
depends on is real.

# Probe 42 — Meta.HC's operation-log slice, PASS

Status: **PASS**, real, on real TempleOS under QEMU
(`serial-log-passing-run.txt`, `evidence-pass.png`). Completes ADR
0003's combined-metadata-file design — every concern `Paths.HC`'s and
`OpLog.HC`'s sidecar files used to hold now lives in `Meta.HC`. Still
standalone, not yet wired into any real command.

## Design

Operation-log entries are fundamentally different from HEAD/CURRENT:
those replace (one record per name, spliced-and-rewritten on every
write); an operation log **accumulates** (each real operation appends
one entry, undo pops the most recent). This needed a new primitive,
`MetaSpliceOutLast`, distinct from probe 40/41's `MetaSpliceOut`
(which strips *every* matching record) — it finds and removes only the
**last** record matching (name, tag), leaving earlier same-(name, tag)
entries alone. `MetaOpLogAppend`/`MetaOpLogPopLast` are built on top of
it, using the same 136-byte entry shape (`U64 timestamp` + 64-byte
`prev_head` + 64-byte `new_head`) `OpLog.HC`'s sidecar-file version
already verified in probe 30.

Hit the same sibling-declaration-in-one-function "Duplicate member"
quirk documented since early in this project (two branches of
`MetaSpliceOutLast` each declared their own `I64 ci;`) — caught
immediately by stage-2 on the first push, fixed by renaming one to
`zi`, no reboot needed.

## What was verified

`test_driver.hc`, calling `Meta.HC`'s functions directly: three
operations logged for `"main"` (`zero→h1`, `h1→h2`, `h2→h3`), one for
a completely different path `"feature"` (`zero→fh1`), all in the
**same** combined file:

```
pop1_ok=1 pop1_ts=3000 pop1_prev_ok=1 pop1_new_ok=1
fpop_ok=1 fpop_ts=5000 fpop_new_ok=1
fpop2_ok=0 (expect 0)
pop2_ok=1 pop2_ts=2000 pop2_prev_ok=1 pop2_new_ok=1
pop3_ok=1 pop3_prev_ok=1
pop4_ok=0 (expect 0, main now empty too)
PASS meta_oplog
```

- Popping `"main"` first returns the **most recently appended** entry
  (`h2→h3`, ts 3000) — correct LIFO order, not FIFO or arbitrary.
- `"feature"`'s single entry is popped correctly and independently,
  completely unaffected by `"main"`'s pop, despite sharing one file —
  then correctly reports empty on a second pop.
- Popping `"main"` again returns the **second** entry (`h1→h2`, ts
  2000) — proving the *first* entry (`zero→h1`) was genuinely left
  untouched by the first pop, not silently dropped or corrupted.
- A final pop empties `"main"` too (`zero→h1`), and a pop after that
  correctly reports nothing left.

## Not yet done

- Still standalone: `Head.HC`/`Paths.HC`/`OpLog.HC` and every real
  command/probe (30-39) still use today's separate-sidecar-file
  layout. Switching real commands (`offer`/`undo`/`redo`/`path *`/
  `operation *`) over to `Meta.HC` — the actual point of ADR 0003 — is
  the next concrete step, not done here.
- No redo-log equivalent added to `Meta.HC` yet (probe 32's redo stack)
  — same accumulate/pop pattern would apply, just not built.

// probe 42 — Meta.HC's operation-log slice (MetaOpLogAppend/
// MetaOpLogPopLast), standalone, same not-yet-wired-in status as
// probes 40/41. Verifies entries accumulate (not replace, unlike
// HEAD/CURRENT) and that popping only removes the LAST one, leaving
// earlier entries for the same path intact - and that two different
// paths' logs, sharing the same combined file, don't interfere.

U8 *repo = "C:/Home/P42Repo.hgs";

U8 zero[64], h1[64], h2[64], h3[64];
I64 bi;
for (bi=0;bi<64;bi++) { zero[bi]=0; h1[bi]=1; h2[bi]=2; h3[bi]=3; }

// three operations logged for "main": zero->h1, h1->h2, h2->h3.
MetaOpLogAppend(repo, "main", zero, h1, 1000);
MetaOpLogAppend(repo, "main", h1, h2, 2000);
MetaOpLogAppend(repo, "main", h2, h3, 3000);

// one operation for "feature" - a completely different path sharing
// the same file - to prove no cross-talk.
U8 fh1[64];
for (bi=0;bi<64;bi++) fh1[bi]=99;
MetaOpLogAppend(repo, "feature", zero, fh1, 5000);

// pop "main"'s last entry: should be (h2, h3, ts=3000).
U8 pop1_prev[64], pop1_new[64];
U64 pop1_ts;
Bool pop1_ok = MetaOpLogPopLast(repo, "main", pop1_prev, pop1_new, &pop1_ts);
Bool pop1_prev_ok = TRUE, pop1_new_ok = TRUE;
I64 k;
for (k=0;k<64;k++) { if (pop1_prev[k]!=h2[k]) pop1_prev_ok=FALSE; if (pop1_new[k]!=h3[k]) pop1_new_ok=FALSE; }
CommPrint(1, "pop1_ok=%d pop1_ts=%d pop1_prev_ok=%d pop1_new_ok=%d\n",
          pop1_ok, pop1_ts, pop1_prev_ok, pop1_new_ok);

// "feature"'s entry must be completely unaffected by popping "main".
U8 fpop_prev[64], fpop_new[64];
U64 fpop_ts;
Bool fpop_ok = MetaOpLogPopLast(repo, "feature", fpop_prev, fpop_new, &fpop_ts);
Bool fpop_new_ok = TRUE;
for (k=0;k<64;k++) if (fpop_new[k]!=fh1[k]) fpop_new_ok=FALSE;
CommPrint(1, "fpop_ok=%d fpop_ts=%d fpop_new_ok=%d\n", fpop_ok, fpop_ts, fpop_new_ok);

// "feature" now has nothing left to pop.
U8 fpop2_prev[64], fpop2_new[64];
U64 fpop2_ts;
Bool fpop2_ok = MetaOpLogPopLast(repo, "feature", fpop2_prev, fpop2_new, &fpop2_ts);
CommPrint(1, "fpop2_ok=%d (expect 0)\n", fpop2_ok);

// pop "main" again: should be (h1, h2, ts=2000) - the SECOND entry,
// proving the earlier zero->h1 entry is still there, untouched.
U8 pop2_prev[64], pop2_new[64];
U64 pop2_ts;
Bool pop2_ok = MetaOpLogPopLast(repo, "main", pop2_prev, pop2_new, &pop2_ts);
Bool pop2_prev_ok = TRUE, pop2_new_ok = TRUE;
for (k=0;k<64;k++) { if (pop2_prev[k]!=h1[k]) pop2_prev_ok=FALSE; if (pop2_new[k]!=h2[k]) pop2_new_ok=FALSE; }
CommPrint(1, "pop2_ok=%d pop2_ts=%d pop2_prev_ok=%d pop2_new_ok=%d\n",
          pop2_ok, pop2_ts, pop2_prev_ok, pop2_new_ok);

// one entry left for "main" (zero->h1). Pop it, then confirm empty.
U8 pop3_prev[64], pop3_new[64];
U64 pop3_ts;
Bool pop3_ok = MetaOpLogPopLast(repo, "main", pop3_prev, pop3_new, &pop3_ts);
Bool pop3_prev_ok = TRUE;
for (k=0;k<64;k++) if (pop3_prev[k]!=zero[k]) pop3_prev_ok=FALSE;
CommPrint(1, "pop3_ok=%d pop3_prev_ok=%d\n", pop3_ok, pop3_prev_ok);

Bool pop4_ok = MetaOpLogPopLast(repo, "main", pop3_prev, pop3_new, &pop3_ts);
CommPrint(1, "pop4_ok=%d (expect 0, main now empty too)\n", pop4_ok);

if (pop1_ok && pop1_ts==3000 && pop1_prev_ok && pop1_new_ok &&
    fpop_ok && fpop_ts==5000 && fpop_new_ok && !fpop2_ok &&
    pop2_ok && pop2_ts==2000 && pop2_prev_ok && pop2_new_ok &&
    pop3_ok && pop3_prev_ok && !pop4_ok)
  CommPrint(1, "PASS meta_oplog\n");
else
  CommPrint(1, "FAIL meta_oplog\n");

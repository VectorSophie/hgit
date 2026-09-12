// probe 32 — undo/redo stack. Verifies OpLogRedo re-applies an undone
// operation, and that OpLogAppend (a real new offer) clears the redo
// log so stale redo history can't resurrect after new work happens —
// all through the real Hgit(cmdline) dispatcher.

U8 zero_hash32[64];
I64 zi32;
for (zi32=0; zi32<64; zi32++) zero_hash32[zi32] = 0;

Hgit("init \"C:/Home/P32Repo.hgs\"");
U8 fa32[3]; fa32[0]='o';fa32[1]='n';fa32[2]='e';
FileWrite("C:/Home/P32FileA.txt", fa32, 3);

// offer 1
Hgit("offer \"C:/Home/P32Repo.hgs\" \"C:/Home/P32FileA*\" first offer");
U8 head1_32[64];
HeadRead("C:/Home/P32Repo.hgs", head1_32);

// offer 2
U8 fa2_32[3]; fa2_32[0]='t';fa2_32[1]='w';fa2_32[2]='o';
FileWrite("C:/Home/P32FileA.txt", fa2_32, 3);
Hgit("offer \"C:/Home/P32Repo.hgs\" \"C:/Home/P32FileA*\" second offer");
U8 head2_32[64];
HeadRead("C:/Home/P32Repo.hgs", head2_32);

// undo once: HEAD -> head1_32
Hgit("undo \"C:/Home/P32Repo.hgs\"");
U8 after_undo_32[64];
HeadRead("C:/Home/P32Repo.hgs", after_undo_32);
I64 k32;
Bool undo_matches_head1 = TRUE;
for (k32=0;k32<64;k32++) if (after_undo_32[k32]!=head1_32[k32]) undo_matches_head1=FALSE;
CommPrint(1, "undo_matches_head1=%d\n", undo_matches_head1);

// redo once: HEAD should go back to head2_32
Hgit("redo \"C:/Home/P32Repo.hgs\"");
U8 after_redo_32[64];
HeadRead("C:/Home/P32Repo.hgs", after_redo_32);
Bool redo_matches_head2 = TRUE;
for (k32=0;k32<64;k32++) if (after_redo_32[k32]!=head2_32[k32]) redo_matches_head2=FALSE;
CommPrint(1, "redo_matches_head2=%d\n", redo_matches_head2);

// a second redo should report FALSE - nothing left to redo
Hgit("redo \"C:/Home/P32Repo.hgs\"");
// no direct return value visible through Hgit(), so re-check via
// OpLogRedo directly for this one assertion (it's already been proven
// to be the real function the dispatcher calls, in probe 31's style).
Bool redo_ok2 = OpLogRedo("C:/Home/P32Repo.hgs");
CommPrint(1, "redo_ok2=%d (expect 0)\n", redo_ok2);

// undo again (back to head1_32), THEN do a real new offer - this
// should clear the redo log, so a follow-up redo must report FALSE.
Hgit("undo \"C:/Home/P32Repo.hgs\"");
U8 fa3_32[5]; fa3_32[0]='t';fa3_32[1]='h';fa3_32[2]='r';fa3_32[3]='e';fa3_32[4]='e';
FileWrite("C:/Home/P32FileA.txt", fa3_32, 5);
Hgit("offer \"C:/Home/P32Repo.hgs\" \"C:/Home/P32FileA*\" third offer");
Bool redo_ok3 = OpLogRedo("C:/Home/P32Repo.hgs");
CommPrint(1, "redo_ok3=%d (expect 0, new offer must clear redo log)\n", redo_ok3);

if (undo_matches_head1 && redo_matches_head2 && !redo_ok2 && !redo_ok3)
  CommPrint(1, "PASS oplog_redo\n");
else
  CommPrint(1, "FAIL oplog_redo\n");

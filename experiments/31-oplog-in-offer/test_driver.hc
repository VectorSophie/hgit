// probe 31 — verifies OpLogAppend is now called FROM INSIDE HgitOffer
// (not manually alongside it, as probe 30 tested), and exercises the
// new `undo` dispatch branch in Hgit.HC — all through the real
// Hgit(cmdline) entry point, not by calling hgit-core functions
// directly, so this is the closest thing to real end-user usage tested
// so far.

U8 zero_hash31[64];
I64 zi31;
for (zi31=0; zi31<64; zi31++) zero_hash31[zi31] = 0;

Hgit("init \"C:/Home/P31Repo.hgs\"");
U8 fa31[3]; fa31[0]='o';fa31[1]='n';fa31[2]='e';
FileWrite("C:/Home/P31FileA.txt", fa31, 3);

// offer 1 (root commit) via the real dispatcher — no manual OpLogAppend
// call anywhere in this test, unlike probe 30.
Hgit("offer \"C:/Home/P31Repo.hgs\" \"C:/Home/P31FileA*\" first offer");
U8 head_after_1_31[64];
HeadRead("C:/Home/P31Repo.hgs", head_after_1_31);

// oplog file should already exist and be exactly 136 bytes (one entry)
// purely as a side effect of that one `offer` call.
I64 log1_size;
U8 *log1_buf = FileRead("C:/Home/P31Repo.hgs.oplog", &log1_size);
Bool log_exists_after_1 = (log1_buf != NULL);
Bool log_size_after_1_ok = (log1_size == 136);
CommPrint(1, "log_exists_after_1=%d log_size_after_1_ok=%d (size=%d)\n",
          log_exists_after_1, log_size_after_1_ok, log1_size);

// offer 2 (child commit), also via the dispatcher.
U8 fa2_31[3]; fa2_31[0]='t';fa2_31[1]='w';fa2_31[2]='o';
FileWrite("C:/Home/P31FileA.txt", fa2_31, 3);
Hgit("offer \"C:/Home/P31Repo.hgs\" \"C:/Home/P31FileA*\" second offer");
U8 head_after_2_31[64];
HeadRead("C:/Home/P31Repo.hgs", head_after_2_31);

I64 log2_size;
U8 *log2_buf = FileRead("C:/Home/P31Repo.hgs.oplog", &log2_size);
Bool log_size_after_2_ok = (log2_size == 272); // two 136-byte entries

I64 k31;
Bool heads_differ_31 = FALSE;
for (k31=0;k31<64;k31++) if (head_after_1_31[k31]!=head_after_2_31[k31]) heads_differ_31=TRUE;
CommPrint(1, "heads_differ_31=%d log_size_after_2_ok=%d (size=%d)\n",
          heads_differ_31, log_size_after_2_ok, log2_size);

// undo once via the real dispatcher's new `undo` branch.
Hgit("undo \"C:/Home/P31Repo.hgs\"");
U8 head_after_undo_31[64];
Bool found_after_undo_31 = HeadRead("C:/Home/P31Repo.hgs", head_after_undo_31);
Bool matches_head1_31 = TRUE;
for (k31=0;k31<64;k31++) if (head_after_undo_31[k31]!=head_after_1_31[k31]) matches_head1_31=FALSE;
CommPrint(1, "found_after_undo_31=%d matches_head1_31=%d\n",
          found_after_undo_31, matches_head1_31);

// undo again — should revert to the zero-sentinel (no commit yet).
Hgit("undo \"C:/Home/P31Repo.hgs\"");
U8 head_after_undo2_31[64];
Bool found_after_undo2_31 = HeadRead("C:/Home/P31Repo.hgs", head_after_undo2_31);
Bool matches_zero_31 = TRUE;
for (k31=0;k31<64;k31++) if (head_after_undo2_31[k31]!=zero_hash31[k31]) matches_zero_31=FALSE;
CommPrint(1, "found_after_undo2_31=%d matches_zero_31=%d\n",
          found_after_undo2_31, matches_zero_31);

if (log_exists_after_1 && log_size_after_1_ok && heads_differ_31 &&
    log_size_after_2_ok && found_after_undo_31 && matches_head1_31 &&
    found_after_undo2_31 && matches_zero_31)
  CommPrint(1, "PASS oplog_wired_into_offer\n");
else
  CommPrint(1, "FAIL oplog_wired_into_offer\n");

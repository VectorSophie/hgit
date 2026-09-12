// probe 38 — `hgit operation restore <op>`: jump HEAD directly to a
// specific logged operation's recorded new_head, by index, through the
// real Hgit(cmdline) dispatcher's "operation restore <repo> <idx>"
// two-word-plus-arg parsing.

Hgit("init \"C:/Home/P38Repo.hgs\"");

U8 fa38[3]; fa38[0]='o';fa38[1]='n';fa38[2]='e';
FileWrite("C:/Home/P38FileA.txt", fa38, 3);
Hgit("offer \"C:/Home/P38Repo.hgs\" \"C:/Home/P38FileA*\" commit zero");
U8 head0_38[64];
HeadRead("C:/Home/P38Repo.hgs", head0_38);

U8 fa1_38[3]; fa1_38[0]='t';fa1_38[1]='w';fa1_38[2]='o';
FileWrite("C:/Home/P38FileA.txt", fa1_38, 3);
Hgit("offer \"C:/Home/P38Repo.hgs\" \"C:/Home/P38FileA*\" commit one");
U8 head1_38[64];
HeadRead("C:/Home/P38Repo.hgs", head1_38);

U8 fa2_38[5]; fa2_38[0]='t';fa2_38[1]='h';fa2_38[2]='r';fa2_38[3]='e';fa2_38[4]='e';
FileWrite("C:/Home/P38FileA.txt", fa2_38, 5);
Hgit("offer \"C:/Home/P38Repo.hgs\" \"C:/Home/P38FileA*\" commit two");
U8 head2_38[64];
HeadRead("C:/Home/P38Repo.hgs", head2_38);

// Now 3 operations logged: OP 0 (new=head0), OP 1 (new=head1),
// OP 2 (new=head2). Current HEAD is head2. Restore directly to OP 0 -
// a jump of two, not a single undo step.
Hgit("operation restore \"C:/Home/P38Repo.hgs\" 0");
U8 after_restore0_38[64];
HeadRead("C:/Home/P38Repo.hgs", after_restore0_38);
I64 k38;
Bool matches_head0 = TRUE;
for (k38=0;k38<64;k38++) if (after_restore0_38[k38]!=head0_38[k38]) matches_head0=FALSE;
CommPrint(1, "matches_head0_after_restore_to_0=%d\n", matches_head0);

// restore forward to OP 2 directly (skipping OP 1 entirely).
Hgit("operation restore \"C:/Home/P38Repo.hgs\" 2");
U8 after_restore2_38[64];
HeadRead("C:/Home/P38Repo.hgs", after_restore2_38);
Bool matches_head2 = TRUE;
for (k38=0;k38<64;k38++) if (after_restore2_38[k38]!=head2_38[k38]) matches_head2=FALSE;
CommPrint(1, "matches_head2_after_restore_to_2=%d\n", matches_head2);

// an out-of-range index must be refused, not silently do something.
Hgit("operation restore \"C:/Home/P38Repo.hgs\" 99");
Bool restore99_refused = !OpLogRestore("C:/Home/P38Repo.hgs", 99);
U8 after_bad_restore_38[64];
HeadRead("C:/Home/P38Repo.hgs", after_bad_restore_38);
Bool head_unchanged_after_bad_restore = TRUE;
for (k38=0;k38<64;k38++) if (after_bad_restore_38[k38]!=head2_38[k38]) head_unchanged_after_bad_restore=FALSE;
CommPrint(1, "restore99_refused=%d head_unchanged_after_bad_restore=%d\n",
          restore99_refused, head_unchanged_after_bad_restore);

if (matches_head0 && matches_head2 && restore99_refused && head_unchanged_after_bad_restore)
  CommPrint(1, "PASS operation_restore\n");
else
  CommPrint(1, "FAIL operation_restore\n");

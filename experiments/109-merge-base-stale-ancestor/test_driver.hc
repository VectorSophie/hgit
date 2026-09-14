// Probe 109 test driver: does FindMergeBase's own documented
// parent[0]-only-chain limitation produce a real, observable WRONG
// (not just ambiguous) merge base once a real merge commit already
// exists in one side's ancestry?
//
// Real scenario: main and Y both fork from a root C1={top.txt}. Y
// offers y.txt (CY1={top.txt,y.txt=y1}). main independently offers
// main2.txt (C2={top.txt,main2.txt}). main merges Y in (a real
// 2-parent merge commit M1={top.txt,main2.txt,y.txt=y1}). A third
// path Z forks from Y's OWN pre-merge head CY1 (not from M1) and
// edits y.txt (CZ1={top.txt,y.txt=y2_edited_by_z}). main advances
// again after the merge (C3={top.txt,main2.txt,main3.txt,y.txt=y1}).
//
// The TRUE lowest common ancestor of C3 and CZ1 is CY1 (a real
// ancestor of C3 via M1's own SECOND parent) - under it, y.txt is
// unchanged on ours (C3) since the merge and only changed by theirs
// (CZ1), a clean, non-conflicting resolution. But FindMergeBase only
// ever walks parent[0], so M1's own parent[0] (main's own side) is
// all it ever sees - it never reaches CY1 at all, and instead reports
// the older root C1 as the merge base. Under that STALE base, y.txt
// looks "absent in base, present differently on both sides" - a real,
// wrong MERGE_CONFLICT where a clean auto-merge should happen.
//
// hgit has no working-directory checkout - real files persist on
// disk across path switches - so every offer below explicitly
// restores/deletes files first so each offer's own find_mask matches
// EXACTLY that path's own intended tree content at that point (same
// discipline experiments/99-hgit-merge/ already established).
U0 P109MergeBaseStaleTest()
{
  Del("C:/Home/P109Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P109Repo.hgs.m", FALSE, FALSE, FALSE);
  Del("C:/Home/P109Top.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/P109Y.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/P109Main2.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/P109Main3.txt", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P109Repo.hgs");

  U8 *mask = "C:/Home/P109*.txt";
  U8 cmd[512];

  // C1 = {top.txt} on main.
  FileWrite("C:/Home/P109Top.txt", "top v1", 6);
  StrPrint(cmd, "offer C:/Home/P109Repo.hgs %s root_commit", mask);
  Hgit(cmd);

  // CY1 = {top.txt, y.txt=y1} on Y (forked from C1).
  Hgit("path new C:/Home/P109Repo.hgs Y");
  Hgit("path go C:/Home/P109Repo.hgs Y");
  FileWrite("C:/Home/P109Y.txt", "y1", 2);
  StrPrint(cmd, "offer C:/Home/P109Repo.hgs %s y_commit_1", mask);
  Hgit(cmd);

  // C2 = {top.txt, main2.txt} on main - y.txt must NOT be part of
  // this commit yet (main hasn't merged Y), so delete it from disk
  // first even though Y's own offer just wrote it.
  Hgit("path go C:/Home/P109Repo.hgs main");
  Del("C:/Home/P109Y.txt", FALSE, FALSE, FALSE);
  FileWrite("C:/Home/P109Main2.txt", "m2", 2);
  StrPrint(cmd, "offer C:/Home/P109Repo.hgs %s main_commit_2", mask);
  Hgit(cmd);

  // M1 = merge Y into main - expected clean (top.txt unchanged either
  // side, main2.txt only on ours, y.txt only on theirs).
  CommPrint(1, "P109_MERGE_ONE_BEGIN\n");
  Hgit("merge C:/Home/P109Repo.hgs Y");
  CommPrint(1, "P109_MERGE_ONE_END\n");

  // Disk is now stale relative to M1's own real tree (y.txt was
  // deleted above and never restored) - restore it before continuing,
  // so main's NEXT offer doesn't spuriously look like a deletion.
  FileWrite("C:/Home/P109Y.txt", "y1", 2);

  // Z forks from Y's OWN pre-merge head CY1 (not from M1) and edits
  // y.txt. Z's own real tree is {top.txt, y.txt=edited} only -
  // main2.txt must not leak into it even though it's on disk right
  // now (left over from the merge-state restore above).
  Hgit("path go C:/Home/P109Repo.hgs Y");
  Hgit("path new C:/Home/P109Repo.hgs Z");
  Hgit("path go C:/Home/P109Repo.hgs Z");
  Del("C:/Home/P109Main2.txt", FALSE, FALSE, FALSE);
  FileWrite("C:/Home/P109Y.txt", "y2_edited_by_z", 14);
  StrPrint(cmd, "offer C:/Home/P109Repo.hgs %s z_edits_y", mask);
  Hgit(cmd);

  // Back on main: restore its own real, unedited-since-merge state
  // (y.txt=y1, main2.txt back) plus a genuinely new file, main3.txt.
  Hgit("path go C:/Home/P109Repo.hgs main");
  FileWrite("C:/Home/P109Y.txt", "y1", 2);
  FileWrite("C:/Home/P109Main2.txt", "m2", 2);
  FileWrite("C:/Home/P109Main3.txt", "m3", 2);
  StrPrint(cmd, "offer C:/Home/P109Repo.hgs %s main_commit_3", mask);
  Hgit(cmd);

  // The real test: merge Z into main. TRUE base = CY1 (y.txt
  // unchanged on ours since the merge, changed on theirs - should
  // resolve cleanly to theirs' edit, no conflict). A stale base (C1)
  // would instead see y.txt as "absent in base, present differently
  // on both sides" - a false MERGE_CONFLICT.
  CommPrint(1, "P109_MERGE_TWO_BEGIN\n");
  Hgit("merge C:/Home/P109Repo.hgs Z");
  CommPrint(1, "P109_MERGE_TWO_END\n");

  U8 head_hash[64];
  CurrentHeadRead("C:/Home/P109Repo.hgs", head_hash);
  U8 head_hex[129];
  HashToHex(head_hash, head_hex);
  StrPrint(cmd, "see C:/Home/P109Repo.hgs %s", head_hex);
  CommPrint(1, "P109_FINAL_SEE_BEGIN\n");
  Hgit(cmd);
  CommPrint(1, "P109_FINAL_SEE_END\n");

  CommPrint(1, "PASS p109_merge_base_stale_test\n");
}
P109MergeBaseStaleTest;

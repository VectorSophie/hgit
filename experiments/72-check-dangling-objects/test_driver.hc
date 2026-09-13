// Probe 72 test driver: hgit check's new dangling-object detection.
// Positive (no dangling): a fresh repo with two ordinary offers - every
// object should be reachable from "main"'s HEAD; CHECK_DANGLING_NONE.
// Then `undo` moves HEAD back one commit WITHOUT removing the newer
// commit's objects from the store (hgit's own non-destructive-history
// design) - the newer commit (and its now-orphaned tree/blob, since
// the file's content changed) become genuinely dangling: present in
// the store, unreachable from any real path's HEAD. This is a real,
// naturally-occurring dangling case, not a hand-corrupted one.
U0 P72CheckDanglingTest()
{
  // Delete BOTH the object store and its Meta.HC sidecar (`<path>.m`,
  // holding HEAD/paths/oplog) - a real gotcha found while writing this
  // test: deleting only the `.hgs` and re-`init`-ing leaves a stale
  // HEAD pointing at a hash the fresh, now-empty store no longer has,
  // producing a broken-from-birth repo (a real CHECK_BROKEN_REF, not a
  // check bug - logged in docs/research/failed-approaches.md).
  Del("C:/Home/P72Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P72Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P72Repo.hgs");

  FileWrite("C:/Home/P72File.txt", "version one", 11);
  Hgit("offer C:/Home/P72Repo.hgs P72File.txt first_version");

  CommPrint(1, "P72_CHECK_BEFORE_SECOND_OFFER\n");
  Hgit("check C:/Home/P72Repo.hgs");

  FileWrite("C:/Home/P72File.txt", "version two, totally different", 31);
  Hgit("offer C:/Home/P72Repo.hgs P72File.txt second_version");

  CommPrint(1, "P72_CHECK_AFTER_SECOND_OFFER\n");
  Hgit("check C:/Home/P72Repo.hgs");

  Hgit("undo C:/Home/P72Repo.hgs");

  CommPrint(1, "P72_CHECK_AFTER_UNDO\n");
  Hgit("check C:/Home/P72Repo.hgs");

  CommPrint(1, "PASS p72_check_dangling_test\n");
}
P72CheckDanglingTest;

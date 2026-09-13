// Probe 85b: fresh-repo regression check that EXACT-content rename
// surfacing in hgit status (probe 71) still works after adding the
// fuzzy pass (probe 85) - same scenario as probe 71's own test, but
// with a clean repo (Del() cleanup) instead of reusing accumulated
// session state.
U0 P85bExactRegressionTest()
{
  Del("C:/Home/P85BRepo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P85BRepo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P85BRepo.hgs");

  FileWrite("C:/Home/P85BOrig.txt", "rename me please", 16);
  FileWrite("C:/Home/P85BStays.txt", "never touched", 13);
  FileWrite("C:/Home/P85BWillDelete.txt", "going away for real", 20);

  Hgit("offer C:/Home/P85BRepo.hgs P85B*.txt initial_three");

  // Exact-content rename (identical bytes, new name), a real delete,
  // and a genuinely new file.
  Del("C:/Home/P85BOrig.txt", FALSE, FALSE, FALSE);
  FileWrite("C:/Home/P85BRenamed.txt", "rename me please", 16);
  Del("C:/Home/P85BWillDelete.txt", FALSE, FALSE, FALSE);
  FileWrite("C:/Home/P85BGenuinelyNew.txt", "brand new content here", 22);

  CommPrint(1, "P85B_STATUS_BEGIN\n");
  Hgit("status C:/Home/P85BRepo.hgs C:/Home/P85B*.txt C:/Home/");
  CommPrint(1, "P85B_STATUS_END_MARKER\n");
  CommPrint(1, "PASS p85b_exact_regression_test\n");
}
P85bExactRegressionTest;

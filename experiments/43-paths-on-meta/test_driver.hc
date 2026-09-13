// probe 43 — Paths.HC's public API now backed by Meta.HC internally
// (ADR 0003's real command cutover). Reuses probe 35's exact scenario
// (one commit on main, branch to feature, one more commit on feature,
// confirm both paths independently) to prove behavior is unchanged
// from the old sidecar-file scheme - plus a new check specific to this
// cutover: a path NAME long enough that the OLD per-path-sidecar
// scheme would have exceeded the 33-char ceiling (rejected by probe
// 37's PathNameFits guard) is now accepted, since names no longer
// affect any filename.

Hgit("init \"C:/Home/P43Repo.hgs\"");

U8 fa43[3]; fa43[0]='o';fa43[1]='n';fa43[2]='e';
FileWrite("C:/Home/P43FileA.txt", fa43, 3);
Hgit("offer \"C:/Home/P43Repo.hgs\" \"C:/Home/P43FileA*\" main commit 1");

// Real commands now go through Meta.HC's MetaReadHead, not Head.HC's
// old HeadRead (which reads a `.head` sidecar real commands no longer
// write at all) - confirm the offer's result the new way.
U8 main_head1_43[64];
Bool main_head1_meta_ok = MetaReadHead("C:/Home/P43Repo.hgs", "main", main_head1_43);
I64 k43;
CommPrint(1, "main_head1_meta_ok=%d\n", main_head1_meta_ok);

Hgit("path new \"C:/Home/P43Repo.hgs\" feature");
Hgit("path go \"C:/Home/P43Repo.hgs\" feature");

U8 fa2_43[3]; fa2_43[0]='t';fa2_43[1]='w';fa2_43[2]='o';
FileWrite("C:/Home/P43FileA.txt", fa2_43, 3);
Hgit("offer \"C:/Home/P43Repo.hgs\" \"C:/Home/P43FileA*\" feature commit 1");

U8 main_head_after_43[64];
MetaReadHead("C:/Home/P43Repo.hgs", "main", main_head_after_43);
Bool main_unchanged = TRUE;
for (k43=0;k43<64;k43++) if (main_head_after_43[k43]!=main_head1_43[k43]) main_unchanged=FALSE;
CommPrint(1, "main_unchanged_after_feature_offer=%d\n", main_unchanged);

U8 feature_head_meta[64];
Bool feature_head_ok = MetaReadHead("C:/Home/P43Repo.hgs", "feature", feature_head_meta);
Bool feature_differs = TRUE;
for (k43=0;k43<64;k43++) if (feature_head_meta[k43]==main_head1_43[k43]) feature_differs=FALSE;
CommPrint(1, "feature_head_ok=%d feature_differs=%d\n", feature_head_ok, feature_differs);

// history/status still behave correctly (same probe-35-style checks).
Hgit("history \"C:/Home/P43Repo.hgs\"");     // expect 2 entries (on feature)
Hgit("path go \"C:/Home/P43Repo.hgs\" main");
Hgit("history \"C:/Home/P43Repo.hgs\"");     // expect 1 entry (on main)
Hgit("status \"C:/Home/P43Repo.hgs\" \"C:/Home/P43FileA*\" \"\"");
Hgit("path go \"C:/Home/P43Repo.hgs\" feature");
Hgit("status \"C:/Home/P43Repo.hgs\" \"C:/Home/P43FileA*\" \"\"");

// the real point of this cutover: a path name that would have exceeded
// the OLD per-path-sidecar ceiling is now accepted. Old scheme budget
// was repo_path + ".head." (6) + name <= 33; this repo path
// (C:/Home/P43Repo.hgs, 20 chars) + ".head." (6) + a 20-char name = 46
// chars - would have been REFUSED before (see probe 37). Called
// directly (not through Hgit's dispatcher, which is U0 and doesn't
// surface a return value) to check the real Bool result.
Bool long_name_now_ok = PathNew("C:/Home/P43Repo.hgs", "areallylongbranchname11");
CommPrint(1, "long_name_now_ok=%d (was rejected under the old scheme)\n", long_name_now_ok);

if (main_head1_meta_ok && main_unchanged &&
    feature_head_ok && feature_differs && long_name_now_ok)
  CommPrint(1, "PASS paths_on_meta\n");
else
  CommPrint(1, "FAIL paths_on_meta\n");

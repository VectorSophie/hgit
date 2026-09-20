CommPrint(1, "P120_BEGIN\n");
Del("C:/Home/P120A.hgs", FALSE, FALSE, FALSE);
FileWrite("C:/Home/P120Work/conflict.txt", "base\n", StrLen("base\n"));

Hgit("init C:/Home/P120A.hgs");
Hgit("offer C:/Home/P120A.hgs C:/Home/P120Work/* base_commit");

Hgit("path new C:/Home/P120A.hgs feature");
Hgit("path go C:/Home/P120A.hgs feature");
FileWrite("C:/Home/P120Work/conflict.txt", "feature_version\n", StrLen("feature_version\n"));
Hgit("offer C:/Home/P120A.hgs C:/Home/P120Work/* feature_edit");

Hgit("path go C:/Home/P120A.hgs main");
FileWrite("C:/Home/P120Work/conflict.txt", "main_version\n", StrLen("main_version\n"));
Hgit("offer C:/Home/P120A.hgs C:/Home/P120Work/* main_edit");

CommPrint(1, "P120_MERGE_ATTEMPT\n");
Hgit("merge C:/Home/P120A.hgs feature");

CommPrint(1, "P120_STATUS_CHECK\n");
Hgit("status C:/Home/P120A.hgs * C:/Home/P120Work/");

CommPrint(1, "P120_CONFLICTS_LIST\n");
Hgit("conflicts C:/Home/P120A.hgs");

CommPrint(1, "P120_RESOLVE\n");
Hgit("resolve C:/Home/P120A.hgs 0 take-theirs");

CommPrint(1, "P120_CONTINUE\n");
Hgit("merge continue C:/Home/P120A.hgs");

CommPrint(1, "P120_STATUS_AFTER\n");
Hgit("status C:/Home/P120A.hgs * C:/Home/P120Work/");

CommPrint(1, "P120_CHECK\n");
Hgit("check C:/Home/P120A.hgs");

CommPrint(1, "P120_END\n");

CommPrint(1, "P121_BEGIN\n");
Del("C:/Home/P121A.hgs", FALSE, FALSE, FALSE);
FileWrite("C:/Home/P121Work/c.txt", "base\n", StrLen("base\n"));

Hgit("init C:/Home/P121A.hgs");
Hgit("offer C:/Home/P121A.hgs C:/Home/P121Work/* base_commit");
Hgit("path new C:/Home/P121A.hgs feature");
Hgit("path go C:/Home/P121A.hgs feature");
FileWrite("C:/Home/P121Work/c.txt", "feature_v\n", StrLen("feature_v\n"));
Hgit("offer C:/Home/P121A.hgs C:/Home/P121Work/* feature_edit");
Hgit("path go C:/Home/P121A.hgs main");
FileWrite("C:/Home/P121Work/c.txt", "main_v\n", StrLen("main_v\n"));
Hgit("offer C:/Home/P121A.hgs C:/Home/P121Work/* main_edit");

U8 head_before[64];
CurrentHeadRead("C:/Home/P121A.hgs", head_before);

CommPrint(1, "P121_MERGE\n");
Hgit("merge C:/Home/P121A.hgs feature");

CommPrint(1, "P121_ABORT\n");
Hgit("merge abort C:/Home/P121A.hgs");

CommPrint(1, "P121_CONFLICTS_AFTER_ABORT\n");
Hgit("conflicts C:/Home/P121A.hgs");

U8 head_after[64];
CurrentHeadRead("C:/Home/P121A.hgs", head_after);
Bool head_unchanged = TRUE;
I64 zi;
for (zi=0; zi<64; zi++) if (head_before[zi] != head_after[zi]) head_unchanged = FALSE;
CommPrint(1, "P121_HEAD_UNCHANGED=%d\n", head_unchanged);

CommPrint(1, "P121_CHECK\n");
Hgit("check C:/Home/P121A.hgs");
CommPrint(1, "P121_END\n");

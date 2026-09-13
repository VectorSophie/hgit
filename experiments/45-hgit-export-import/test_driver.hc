// probe 45 — `hgit export`/`import`: whole-repo portability, not just
// the object layer (probe 39). Builds a repo with two paths and real
// history, exports it to a brand-new path, then confirms the COPY has
// full working state - HEAD for both paths, correct history counts,
// and a working undo - proving the copy is a genuine, usable repo, not
// just readable object bytes.

Hgit("init \"C:/Home/P45Src.hgs\"");
U8 fa45[3]; fa45[0]='o';fa45[1]='n';fa45[2]='e';
FileWrite("C:/Home/P45FileA.txt", fa45, 3);
Hgit("offer \"C:/Home/P45Src.hgs\" \"C:/Home/P45FileA*\" main commit 1");

Hgit("path new \"C:/Home/P45Src.hgs\" feature");
Hgit("path go \"C:/Home/P45Src.hgs\" feature");
U8 fa2_45[3]; fa2_45[0]='t';fa2_45[1]='w';fa2_45[2]='o';
FileWrite("C:/Home/P45FileA.txt", fa2_45, 3);
Hgit("offer \"C:/Home/P45Src.hgs\" \"C:/Home/P45FileA*\" feature commit 1");
Hgit("path go \"C:/Home/P45Src.hgs\" main");

U8 src_main_head[64], src_feature_head[64];
MetaReadHead("C:/Home/P45Src.hgs", "main", src_main_head);
MetaReadHead("C:/Home/P45Src.hgs", "feature", src_feature_head);

// export to a brand-new repo path.
Hgit("export \"C:/Home/P45Src.hgs\" \"C:/Home/P45Dst.hgs\"");

// the COPY must have both paths' correct HEADs, purely from the
// exported files - no other setup happened on P45Dst.hgs.
U8 dst_main_head[64], dst_feature_head[64];
Bool dst_main_ok = MetaReadHead("C:/Home/P45Dst.hgs", "main", dst_main_head);
Bool dst_feature_ok = MetaReadHead("C:/Home/P45Dst.hgs", "feature", dst_feature_head);
I64 k45;
Bool main_matches = TRUE, feature_matches = TRUE;
for (k45=0;k45<64;k45++) {
  if (dst_main_head[k45]!=src_main_head[k45]) main_matches=FALSE;
  if (dst_feature_head[k45]!=src_feature_head[k45]) feature_matches=FALSE;
}
CommPrint(1, "dst_main_ok=%d main_matches=%d dst_feature_ok=%d feature_matches=%d\n",
          dst_main_ok, main_matches, dst_feature_ok, feature_matches);

// the copy's own path list/current-path must work too - confirm via
// the real dispatcher, not just direct Meta.HC calls.
Hgit("path list \"C:/Home/P45Dst.hgs\"");
Hgit("path go \"C:/Home/P45Dst.hgs\" feature");
Hgit("history \"C:/Home/P45Dst.hgs\"");   // expect 2 entries
Hgit("path go \"C:/Home/P45Dst.hgs\" main");
Hgit("history \"C:/Home/P45Dst.hgs\"");   // expect 1 entry

// the copy's undo must genuinely work - not just read-only object
// access (probe 39's finding), a real, usable, mutable repo.
Hgit("undo \"C:/Home/P45Dst.hgs\"");
U8 dst_main_after_undo[64];
MetaReadHead("C:/Home/P45Dst.hgs", "main", dst_main_after_undo);
Bool undo_changed_dst = FALSE;
for (k45=0;k45<64;k45++) if (dst_main_after_undo[k45]!=dst_main_head[k45]) undo_changed_dst=TRUE;
CommPrint(1, "undo_changed_dst=%d\n", undo_changed_dst);

// the ORIGINAL repo must be completely unaffected by anything done to
// the copy - a real, independent repo, not a shared/aliased one.
U8 src_main_after[64];
MetaReadHead("C:/Home/P45Src.hgs", "main", src_main_after);
Bool src_untouched = TRUE;
for (k45=0;k45<64;k45++) if (src_main_after[k45]!=src_main_head[k45]) src_untouched=FALSE;
CommPrint(1, "src_untouched=%d\n", src_untouched);

if (dst_main_ok && main_matches && dst_feature_ok && feature_matches &&
    undo_changed_dst && src_untouched)
  CommPrint(1, "PASS hgit_export_import\n");
else
  CommPrint(1, "FAIL hgit_export_import\n");

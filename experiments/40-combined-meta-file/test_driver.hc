// probe 40 — Meta.HC's combined metadata file (ADR 0003's first
// slice): standalone verification of MetaReadHead/MetaWriteHead,
// NOT wired into Head.HC/Paths.HC/OpLog.HC yet.
//
// Deliberately uses a repo path AND path names long enough that the
// OLD per-path sidecar scheme (`<repo_path>.head.<name>`) would have
// hit probe 36's real 33-character ceiling - proving the whole point
// of this design: the combined file's own name never grows no matter
// how long the path names inside it are.

// Realistic repo path (23 chars - well under the 33-char ceiling on
// its own; the COMBINED .m file, repo+".m", is 25 chars, still fine).
U8 *long_repo = "C:/Home/FeatureRepo.hgs";
CommPrint(1, "repo_len=%d\n", StrLen(long_repo));

U8 *long_path_name = "a-fairly-long-feature-branch-name";
CommPrint(1, "name_len=%d\n", StrLen(long_path_name));

// This exact shape (repo + ".head." + name) would be 78 characters -
// wildly over the 33-char ceiling. Confirm the OLD scheme really
// would have failed here (not asserted, just shown for contrast).
U8 old_style_path[256];
I64 oi = 0, qi;
for (qi=0; long_repo[qi]; qi++) old_style_path[oi++] = long_repo[qi];
U8 *suffix = ".head.";
for (qi=0; suffix[qi]; qi++) old_style_path[oi++] = suffix[qi];
for (qi=0; long_path_name[qi]; qi++) old_style_path[oi++] = long_path_name[qi];
old_style_path[oi] = 0;
CommPrint(1, "old_style_path_len=%d (would exceed the 33-char ceiling)\n", oi);

// Write two different paths' HEADs into the SAME combined file.
U8 hash_a[64], hash_b[64];
I64 i;
for (i=0;i<64;i++) { hash_a[i] = i+1; hash_b[i] = 200-i; }

MetaWriteHead(long_repo, "main", hash_a);
MetaWriteHead(long_repo, long_path_name, hash_b);

// Confirm the combined file itself is short - just repo + ".m".
U8 meta_path_check[256];
MetaPath(long_repo, meta_path_check);
CommPrint(1, "meta_path=%s len=%d\n", meta_path_check, StrLen(meta_path_check));

U8 read_a[64], read_b[64];
Bool found_a = MetaReadHead(long_repo, "main", read_a);
Bool found_b = MetaReadHead(long_repo, long_path_name, read_b);

Bool a_matches = TRUE, b_matches = TRUE;
for (i=0;i<64;i++) {
  if (read_a[i] != hash_a[i]) a_matches = FALSE;
  if (read_b[i] != hash_b[i]) b_matches = FALSE;
}
CommPrint(1, "found_a=%d a_matches=%d found_b=%d b_matches=%d\n",
          found_a, a_matches, found_b, b_matches);

// Update "main"'s HEAD again - confirm the splice-and-rewrite keeps
// exactly one HEAD record per name, not an ever-growing history.
U8 hash_a2[64];
for (i=0;i<64;i++) hash_a2[i] = i*3;
MetaWriteHead(long_repo, "main", hash_a2);
U8 read_a2[64];
Bool found_a2 = MetaReadHead(long_repo, "main", read_a2);
Bool a2_matches = TRUE;
for (i=0;i<64;i++) if (read_a2[i] != hash_a2[i]) a2_matches = FALSE;
CommPrint(1, "found_a2=%d a2_matches=%d\n", found_a2, a2_matches);

// "b" (the long-named path) must be completely unaffected by "main"'s
// update - both share the same file, so this proves the splice logic
// really only touches the matching record.
U8 read_b2[64];
Bool found_b2 = MetaReadHead(long_repo, long_path_name, read_b2);
Bool b2_still_matches = TRUE;
for (i=0;i<64;i++) if (read_b2[i] != hash_b[i]) b2_still_matches = FALSE;
CommPrint(1, "found_b2=%d b2_still_matches=%d\n", found_b2, b2_still_matches);

// A path name never written has no HEAD.
U8 read_missing[64];
Bool found_missing = MetaReadHead(long_repo, "never-created", read_missing);
CommPrint(1, "found_missing=%d (expect 0)\n", found_missing);

if (found_a && a_matches && found_b && b_matches &&
    found_a2 && a2_matches && found_b2 && b2_still_matches && !found_missing)
  CommPrint(1, "PASS combined_meta_file\n");
else
  CommPrint(1, "FAIL combined_meta_file\n");

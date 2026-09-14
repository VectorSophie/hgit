// Probe 119 test driver: Attrs.HC + Commit.HC's own ADR 0015 extension,
// verified standalone before being (already) wired into Offer.HC -
// same "primitive first, then a real CLI decision" pattern this
// project already used for Ignore.HC (probe 117).
U0 P119AttrsPrimitiveTest()
{
  // --- IsContentBinary: the real NUL-byte heuristic ---
  U8 *text_content = "a real, ordinary text file";
  CommPrint(1, "P119_TEXT_IS_BINARY=%d\n", IsContentBinary(text_content, StrLen(text_content)));

  U8 bin_content[8];
  bin_content[0]='P'; bin_content[1]='N'; bin_content[2]='G'; bin_content[3]=0;
  bin_content[4]='X'; bin_content[5]='Y'; bin_content[6]='Z'; bin_content[7]=0;
  CommPrint(1, "P119_NUL_IS_BINARY=%d\n", IsContentBinary(bin_content, 8));

  // --- .hgitattributes rules + GetEffectiveMode ---
  Del("C:/Home/P119.hgitattributes", FALSE, FALSE, FALSE);
  U8 *rules =
    "*.png binary\n"
    "*.HC text,executable\n"
    "build/* binary\n"
    "*.weird frobnicate\n"; // unsupported attribute, real diagnostic
  FileWrite("C:/Home/P119.hgitattributes", rules, StrLen(rules));

  U8 *ap, *ak, *as, *av;
  I64 acount;
  CommPrint(1, "P119_ATTRS_LOAD_BEGIN\n");
  AttrsRulesLoad("C:/Home/P119.hgitattributes", &ap, &ak, &as, &av, &acount);
  CommPrint(1, "P119_ATTRS_LOAD_END\n");
  CommPrint(1, "P119_RULE_COUNT=%d\n", acount);

  // photo.png: no auto-detect needed (rule forces binary), not executable.
  CommPrint(1, "P119_PNG_MODE=%d\n", GetEffectiveMode(ap, ak, as, av, acount, "photo.png", "", FALSE));
  // Offer.HC: forced text+executable regardless of auto-detect.
  CommPrint(1, "P119_HC_MODE=%d\n", GetEffectiveMode(ap, ak, as, av, acount, "Offer.HC", "", TRUE));
  // build/output.o: DIR_CONTENTS-anchored binary rule (direct child of root-level build/).
  CommPrint(1, "P119_BUILD_CHILD_MODE=%d\n", GetEffectiveMode(ap, ak, as, av, acount, "output.o", "build", FALSE));
  // plain.txt: no rule matches - falls through to auto-detection.
  CommPrint(1, "P119_PLAIN_AUTO_TEXT=%d\n", GetEffectiveMode(ap, ak, as, av, acount, "plain.txt", "", FALSE));
  CommPrint(1, "P119_PLAIN_AUTO_BINARY=%d\n", GetEffectiveMode(ap, ak, as, av, acount, "plain.txt", "", TRUE));

  AttrsRulesFree(ap, ak, as, av);

  // --- OBJ_ATTRS list encode/find round trip ---
  U8 attrs_buf[64];
  I64 attrs_len = 4;
  I64 count = 0;
  AttrsListEncode(attrs_buf, &attrs_len, 0x1111111111111111, MODE_BINARY);
  count++;
  AttrsListEncode(attrs_buf, &attrs_len, 0x2222222222222222, MODE_EXECUTABLE);
  count++;
  PutU32LE(attrs_buf, 0, count);

  U8 found_mode;
  Bool found1 = AttrsListFindMode(attrs_buf, attrs_len, 0x1111111111111111, &found_mode);
  CommPrint(1, "P119_FIND1=%d MODE=%d\n", found1, found_mode);
  Bool found2 = AttrsListFindMode(attrs_buf, attrs_len, 0x2222222222222222, &found_mode);
  CommPrint(1, "P119_FIND2=%d MODE=%d\n", found2, found_mode);
  Bool found3 = AttrsListFindMode(attrs_buf, attrs_len, 0x9999999999999999, &found_mode);
  CommPrint(1, "P119_FIND3_ABSENT=%d\n", found3);

  // --- Commit.HC's own real bounds-check behavior ---
  U8 tree_hash[64], parent_hash[64];
  I64 zi; for (zi=0; zi<64; zi++) { tree_hash[zi]=zi; parent_hash[zi]=0; }
  U8 *msg = "test commit";
  I64 mlen = StrLen(msg);

  // A commit with NO attrs (has_attrs=FALSE).
  U8 commit_no_attrs[512];
  I64 clen_no_attrs = 0;
  CommitEncode(commit_no_attrs, &clen_no_attrs, tree_hash, parent_hash, 0, 12345,
               msg, mlen, REL_NONE, NULL, 0, FALSE, NULL);
  CommPrint(1, "P119_NOATTRS_HAS=%d\n", CommitHasAttrs(commit_no_attrs, clen_no_attrs));

  // A commit WITH real attrs.
  U8 real_attrs_hash[64];
  for (zi=0; zi<64; zi++) real_attrs_hash[zi] = 99;
  U8 commit_with_attrs[512];
  I64 clen_with_attrs = 0;
  CommitEncode(commit_with_attrs, &clen_with_attrs, tree_hash, parent_hash, 0, 12345,
               msg, mlen, REL_NONE, NULL, 0, TRUE, real_attrs_hash);
  Bool has = CommitHasAttrs(commit_with_attrs, clen_with_attrs);
  CommPrint(1, "P119_WITHATTRS_HAS=%d\n", has);
  if (has) {
    U8 *got_hash = CommitAttrsHash(commit_with_attrs);
    Bool matches = TRUE;
    I64 hi; for (hi=0; hi<64; hi++) if (got_hash[hi] != 99) matches = FALSE;
    CommPrint(1, "P119_WITHATTRS_HASH_MATCHES=%d\n", matches);
  }

  // Simulate a real OLD (pre-ADR-0015) commit: truncate a real,
  // otherwise-valid no-attrs commit buffer to end exactly where
  // has_attrs would start - the real "not enough room" case
  // CommitHasAttrs must handle via a bounds check, not a crash or
  // garbage read.
  I64 attrs_offset = CommitAttrsOffset(commit_no_attrs);
  CommPrint(1, "P119_TRUNCATED_HAS=%d\n", CommitHasAttrs(commit_no_attrs, attrs_offset));

  CommPrint(1, "PASS p119_attrs_primitive\n");
}
P119AttrsPrimitiveTest;

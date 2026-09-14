// Probe 117 test driver: Ignore.HC's own matching primitive, verified
// standalone (not yet wired into any real command - ADR 0014's own
// "primitive first" pattern). Exercises the roadmap's own real
// example grammar plus negation-override precedence and the
// unsupported-syntax diagnostic.
U0 P117IgnorePrimitiveTest()
{
  Del("C:/Home/P117.hgitignore", FALSE, FALSE, FALSE);

  // The roadmap's own real example set.
  U8 *ignore_content =
    "*.tmp\n"
    "*.bak\n"
    "build/\n"
    "generated/*\n"
    "!important.hc\n"
    "# a comment, skipped\n"
    "\n"
    "a/b.txt\n"; // unsupported: internal slash, no /* or trailing /
  FileWrite("C:/Home/P117.hgitignore", ignore_content, StrLen(ignore_content));

  U8 *patterns, *negate, *kind;
  I64 count;
  CommPrint(1, "P117_LOAD_BEGIN\n");
  IgnoreLoad("C:/Home/P117.hgitignore", &patterns, &negate, &kind, &count);
  CommPrint(1, "P117_LOAD_END\n");
  CommPrint(1, "P117_PATTERN_COUNT=%d\n", count);

  // NAME pattern, any depth.
  CommPrint(1, "P117_TMP_ROOT=%d\n", IsIgnored(patterns, negate, kind, count, "x.tmp", ""));
  CommPrint(1, "P117_TMP_NESTED=%d\n", IsIgnored(patterns, negate, kind, count, "x.tmp", "SubA/SubB"));
  CommPrint(1, "P117_BAK=%d\n", IsIgnored(patterns, negate, kind, count, "x.bak", ""));

  // DIR pattern, any depth (rel_dir is irrelevant to a DIR match).
  CommPrint(1, "P117_BUILD_ROOT=%d\n", IsIgnored(patterns, negate, kind, count, "build", ""));
  CommPrint(1, "P117_BUILD_NESTED=%d\n", IsIgnored(patterns, negate, kind, count, "build", "SubA"));

  // DIR_CONTENTS pattern, anchored - direct child only.
  CommPrint(1, "P117_GEN_DIRECT_CHILD=%d\n", IsIgnored(patterns, negate, kind, count, "x.txt", "generated"));
  CommPrint(1, "P117_GEN_DEEPER=%d\n", IsIgnored(patterns, negate, kind, count, "x.txt", "generated/sub"));
  CommPrint(1, "P117_GEN_DIR_ITSELF_ELSEWHERE=%d\n", IsIgnored(patterns, negate, kind, count, "generated", "SubA"));

  // Negation: important.hc never ignored, even though nothing else in
  // this rule set would have caught it anyway (real, honest case -
  // the negation still fires and correctly evaluates to "not ignored").
  CommPrint(1, "P117_IMPORTANT_HC=%d\n", IsIgnored(patterns, negate, kind, count, "important.hc", ""));

  // A name that matches nothing at all.
  CommPrint(1, "P117_UNMATCHED=%d\n", IsIgnored(patterns, negate, kind, count, "real_source.hc", ""));

  IgnoreFree(patterns, negate, kind);

  // Real negation-OVERRIDE precedence test: a real *.hc rule followed
  // by a real !important.hc negation - "other.hc" ignored, but
  // "important.hc" specifically rescued by the later negation.
  U8 *override_content = "*.hc\n!important.hc\n";
  FileWrite("C:/Home/P117.hgitignore", override_content, StrLen(override_content));
  U8 *patterns2, *negate2, *kind2;
  I64 count2;
  IgnoreLoad("C:/Home/P117.hgitignore", &patterns2, &negate2, &kind2, &count2);
  CommPrint(1, "P117_OVERRIDE_OTHER_HC=%d\n", IsIgnored(patterns2, negate2, kind2, count2, "other.hc", ""));
  CommPrint(1, "P117_OVERRIDE_IMPORTANT_HC=%d\n", IsIgnored(patterns2, negate2, kind2, count2, "important.hc", ""));
  IgnoreFree(patterns2, negate2, kind2);

  // A missing ignore file - no rules, everything passes.
  Del("C:/Home/P117NoSuchIgnore", FALSE, FALSE, FALSE);
  U8 *patterns3, *negate3, *kind3;
  I64 count3;
  IgnoreLoad("C:/Home/P117NoSuchIgnore", &patterns3, &negate3, &kind3, &count3);
  CommPrint(1, "P117_MISSING_FILE_COUNT=%d\n", count3);

  CommPrint(1, "PASS p117_ignore_primitive\n");
}
P117IgnorePrimitiveTest;

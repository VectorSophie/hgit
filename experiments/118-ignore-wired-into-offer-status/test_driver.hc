// Probe 118 test driver: `.hgitignore` wired into real commands -
// closes v1.8.0's own 3 required experiments (docs/ROADMAP-v1.8.md):
// (1) an ignored untracked file never enters an offer, (2) a
// previously-tracked file stays visible/trackable after an ignore
// rule starts matching it, (3) recursive ignore (a whole subtree via
// a DIR pattern, an anchored DIR_CONTENTS pattern) and negation, using
// the roadmap's own real example grammar.
U0 P118IgnoreWiredTest()
{
  // --- Part A: flat offer/status - items 1 and 2 ---
  Del("C:/Home/P118Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P118Repo.hgs.m", FALSE, FALSE, FALSE);
  Del("C:/Home/.hgitignore", FALSE, FALSE, FALSE);
  // Real cleanup of every plain file this probe itself creates below -
  // a stale leftover from an earlier run of this same probe (this is
  // a long-lived session; files persist across separate script
  // pushes) would silently already be tracked before any ignore rule
  // exists, corrupting exactly the "genuinely new" premise item 1
  // needs. Caught and fixed the hard way once already - see this
  // probe's own README.
  Del("C:/Home/P118AlreadyTracked.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/P118NewTracked.txt", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P118Repo.hgs");

  U8 *mask = "C:/Home/P118*.txt";
  U8 cmd[512];

  // A file that will LATER become ignore-matched, tracked FIRST while
  // no ignore rule exists yet - it must stay visible after the rule
  // is added (item 2's own safety property).
  FileWrite("C:/Home/P118AlreadyTracked.txt", "v1", 2);
  StrPrint(cmd, "offer C:/Home/P118Repo.hgs %s root_commit", mask);
  Hgit(cmd);

  // Now add a real ignore rule that WOULD match the already-tracked
  // file's own name if it were new (a real, deliberately-matching
  // pattern, not `*.tmp` this time - `*Tracked.txt` matches
  // `P118AlreadyTracked.txt` by its own real glob). Lives at
  // `C:/Home/.hgitignore` - the real, exact filename ADR 0014 names,
  // not a per-test-prefixed one.
  FileWrite("C:/Home/.hgitignore", "*Tracked.txt\n", 13);

  // A genuinely new, untracked file that the SAME rule also matches -
  // this one must be ignored (item 1).
  FileWrite("C:/Home/P118NewTracked.txt", "new file, should be ignored", 27);
  // The already-tracked file gets a real edit in this same offer too.
  FileWrite("C:/Home/P118AlreadyTracked.txt", "v2 edited", 9);

  CommPrint(1, "P118_OFFER_TWO_BEGIN\n");
  StrPrint(cmd, "offer C:/Home/P118Repo.hgs %s second_offer", mask);
  Hgit(cmd);
  CommPrint(1, "P118_OFFER_TWO_END\n");

  U8 head_hash[64];
  CurrentHeadRead("C:/Home/P118Repo.hgs", head_hash);
  U8 head_hex[129];
  HashToHex(head_hash, head_hex);
  StrPrint(cmd, "see C:/Home/P118Repo.hgs %s", head_hex);
  CommPrint(1, "P118_SEE_BEGIN\n");
  Hgit(cmd);
  CommPrint(1, "P118_SEE_END\n");

  CommPrint(1, "P118_STATUS_BEGIN\n");
  StrPrint(cmd, "status C:/Home/P118Repo.hgs %s C:/Home/", mask);
  Hgit(cmd);
  CommPrint(1, "P118_STATUS_END\n");

  // `C:/Home/.hgitignore` is a real, shared path - other probes/
  // regressions in this same long-lived session also use `C:/Home/`
  // directly. Clean it up now, before it can affect anything else.
  Del("C:/Home/.hgitignore", FALSE, FALSE, FALSE);

  // --- Part B: offertree/statustree - item 3, the roadmap's own real
  // example grammar, recursive DIR/DIR_CONTENTS patterns + negation ---
  Del("C:/Home/P118TreeRepo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P118TreeRepo.hgs.m", FALSE, FALSE, FALSE);
  // Real cleanup of every real file/directory this part creates below
  // (same reasoning as Part A's own cleanup above - a stale leftover
  // from an earlier run of this same probe must not silently persist).
  Del("C:/Home/P118Root/build/output.o", FALSE, FALSE, FALSE);
  Del("C:/Home/P118Root/build", FALSE, TRUE, FALSE);
  Del("C:/Home/P118Root/generated/direct.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/P118Root/generated", FALSE, TRUE, FALSE);
  Del("C:/Home/P118Root/SubA/generated/nested.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/P118Root/SubA/generated", FALSE, TRUE, FALSE);
  Del("C:/Home/P118Root/SubA", FALSE, TRUE, FALSE);
  Del("C:/Home/P118Root/top.txt", FALSE, FALSE, FALSE);
  Del("C:/Home/P118Root/x.tmp", FALSE, FALSE, FALSE);
  Del("C:/Home/P118Root/important.hc", FALSE, FALSE, FALSE);
  Del("C:/Home/P118Root/.hgitignore", FALSE, FALSE, FALSE);
  Del("C:/Home/P118Root", FALSE, TRUE, FALSE);
  Hgit("init C:/Home/P118TreeRepo.hgs");

  DirMk("C:/Home/P118Root");
  DirMk("C:/Home/P118Root/build");
  DirMk("C:/Home/P118Root/generated");
  DirMk("C:/Home/P118Root/SubA");
  DirMk("C:/Home/P118Root/SubA/generated");

  U8 *ign =
    "*.tmp\n"
    "*.bak\n"
    "build/\n"
    "generated/*\n"
    "!important.hc\n";
  FileWrite("C:/Home/P118Root/.hgitignore", ign, StrLen(ign));

  FileWrite("C:/Home/P118Root/top.txt", "top v1", 6);
  FileWrite("C:/Home/P118Root/x.tmp", "should be ignored", 18);
  FileWrite("C:/Home/P118Root/build/output.o", "should never be reached", 24);
  FileWrite("C:/Home/P118Root/generated/direct.txt", "direct child - ignored", 23);
  // `generated/*` is anchored to the real repository ROOT (ADR 0014) -
  // a DIFFERENT directory that merely happens to be named `generated`,
  // nested under `SubA`, is a real, separate test of that anchoring:
  // its own contents must NOT be affected by the root-level rule.
  FileWrite("C:/Home/P118Root/SubA/generated/nested.txt", "nested generated - not anchored, kept", 38);
  FileWrite("C:/Home/P118Root/important.hc", "rescued by negation", 20);

  CommPrint(1, "P118_OFFERTREE_BEGIN\n");
  Hgit("offertree C:/Home/P118TreeRepo.hgs C:/Home/P118Root/ tree_offer");
  CommPrint(1, "P118_OFFERTREE_END\n");

  U8 tree_head[64];
  CurrentHeadRead("C:/Home/P118TreeRepo.hgs", tree_head);
  U8 tree_hex[129];
  HashToHex(tree_head, tree_hex);
  StrPrint(cmd, "see C:/Home/P118TreeRepo.hgs %s", tree_hex);
  CommPrint(1, "P118_TREE_SEE_BEGIN\n");
  Hgit(cmd);
  CommPrint(1, "P118_TREE_SEE_END\n");

  CommPrint(1, "P118_STATUSTREE_BEGIN\n");
  Hgit("statustree C:/Home/P118TreeRepo.hgs C:/Home/P118Root/");
  CommPrint(1, "P118_STATUSTREE_END\n");

  CommPrint(1, "P118_CHECK_BEGIN\n");
  Hgit("check C:/Home/P118TreeRepo.hgs");
  CommPrint(1, "P118_CHECK_END\n");

  CommPrint(1, "PASS p118_ignore_wired\n");
}
P118IgnoreWiredTest;

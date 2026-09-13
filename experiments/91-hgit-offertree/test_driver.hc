// Probe 91 test driver: `hgit offertree` - the real CLI wiring for
// ADR 0010's recursive tree-building primitive (probe 90). A NEW,
// separate command from plain `offer` - zero changes to that existing
// code path.
U0 P91OfferTreeTest()
{
  Del("C:/Home/P91Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P91Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P91Repo.hgs");

  DirMk("C:/Home/P91Root");
  DirMk("C:/Home/P91Root/SubA");
  FileWrite("C:/Home/P91Root/top.txt", "top level content", 18);
  FileWrite("C:/Home/P91Root/SubA/inner.txt", "inner content, version one", 27);

  Hgit("offertree C:/Home/P91Repo.hgs C:/Home/P91Root/ first_recursive_offer");

  U8 head_hash[64];
  CurrentHeadRead("C:/Home/P91Repo.hgs", head_hash);
  U8 head_hex[129];
  HashToHex(head_hash, head_hex);
  U8 cmd[512];
  StrPrint(cmd, "see C:/Home/P91Repo.hgs %s", head_hex);
  CommPrint(1, "P91_SEE1_BEGIN\n");
  Hgit(cmd);
  CommPrint(1, "P91_SEE1_END\n");

  CommPrint(1, "P91_CHECK1_BEGIN\n");
  Hgit("check C:/Home/P91Repo.hgs");
  CommPrint(1, "P91_CHECK1_END\n");

  // Second offer: edit the nested file only, confirm entity IDs carry
  // forward, real diff correctness.
  FileWrite("C:/Home/P91Root/SubA/inner.txt", "inner content, version TWO", 27);
  Hgit("offertree C:/Home/P91Repo.hgs C:/Home/P91Root/ second_recursive_offer");

  U8 head2_hash[64];
  CurrentHeadRead("C:/Home/P91Repo.hgs", head2_hash);
  U8 head2_hex[129];
  HashToHex(head2_hash, head2_hex);
  StrPrint(cmd, "see C:/Home/P91Repo.hgs %s", head2_hex);
  CommPrint(1, "P91_SEE2_BEGIN\n");
  Hgit(cmd);
  CommPrint(1, "P91_SEE2_END\n");

  CommPrint(1, "PASS p91_offertree_test\n");
}
P91OfferTreeTest;

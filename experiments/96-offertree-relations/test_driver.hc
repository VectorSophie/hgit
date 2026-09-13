// Probe 96 test driver: `hgit correcttree`/`reverttree`/`reconciletree`
// - offertree's own relation-tag support, ADR 0010's last deferred
// item, now closed.
U0 P96OfferTreeRelationsTest()
{
  Del("C:/Home/P96Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P96Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P96Repo.hgs");

  DirMk("C:/Home/P96Root");
  DirMk("C:/Home/P96Root/SubA");
  FileWrite("C:/Home/P96Root/top.txt", "top level content", 18);
  FileWrite("C:/Home/P96Root/SubA/inner.txt", "inner content v1", 17);

  Hgit("offertree C:/Home/P96Repo.hgs C:/Home/P96Root/ first_offer");

  U8 head1_hash[64];
  CurrentHeadRead("C:/Home/P96Repo.hgs", head1_hash);
  U8 head1_hex[129];
  HashToHex(head1_hash, head1_hex);

  // A real correcttree: edit the nested file, relate it back to the
  // first commit, unscoped (entity_hex all zeros).
  FileWrite("C:/Home/P96Root/SubA/inner.txt", "inner content v2 corrected", 26);
  U8 cmd[512];
  StrPrint(cmd, "correcttree C:/Home/P96Repo.hgs %s 0000000000000000 C:/Home/P96Root/ correcting_nested_offer", head1_hex);
  Hgit(cmd);

  U8 head2_hash[64];
  CurrentHeadRead("C:/Home/P96Repo.hgs", head2_hash);
  U8 head2_hex[129];
  HashToHex(head2_hash, head2_hex);
  StrPrint(cmd, "see C:/Home/P96Repo.hgs %s", head2_hex);
  CommPrint(1, "P96_SEE_BEGIN\n");
  Hgit(cmd);
  CommPrint(1, "P96_SEE_END\n");

  CommPrint(1, "P96_CHECK_BEGIN\n");
  Hgit("check C:/Home/P96Repo.hgs");
  CommPrint(1, "P96_CHECK_END\n");

  CommPrint(1, "PASS p96_offertree_relations_test\n");
}
P96OfferTreeRelationsTest;

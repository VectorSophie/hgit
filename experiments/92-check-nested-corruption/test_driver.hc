// Probe 92 test driver: the adversarial `Check.HC` test ADR 0010 left
// as a real follow-up after probe 91's own doc-accuracy correction -
// deliberately break a reference INSIDE a nested tree (not at the
// top level) and confirm `hgit check`'s referential-integrity and
// dangling passes actually detect it there, not just resolve the
// positive "nothing's wrong" case probe 91 already captured.
//
// Corruption technique: flip one byte of `SubA`'s own tree record's
// child_hash entry for `inner.txt`, directly in the archive buffer,
// WITHOUT recomputing that record's own stored hash. IndexBuild/
// IndexLookup key off a record's *stored* hash (not recomputed - see
// Index.HC's own header comment), so every OTHER real reference to
// `SubA` (the top-level tree's own entry) still resolves exactly as
// before - this isolates exactly one real failure (SubA's own
// outgoing reference to inner.txt's blob no longer resolves) instead
// of cascading into an unrelated rewrite of the whole parent chain.
// The one honest side effect: SubA's own record now hash-mismatches
// (ArchiveVerify's hash-integrity check, a real, separate, expected
// failure - not attempted to be avoided or hidden here).
U0 P92CheckNestedCorruptionTest()
{
  Del("C:/Home/P92Repo.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/P92Repo.hgs.m", FALSE, FALSE, FALSE);
  Hgit("init C:/Home/P92Repo.hgs");

  DirMk("C:/Home/P92Root");
  DirMk("C:/Home/P92Root/SubA");
  FileWrite("C:/Home/P92Root/top.txt", "top level content", 18);
  FileWrite("C:/Home/P92Root/SubA/inner.txt", "inner content", 14);

  Hgit("offertree C:/Home/P92Repo.hgs C:/Home/P92Root/ nested_offer");

  CommPrint(1, "P92_CHECK_BEFORE_BEGIN\n");
  Hgit("check C:/Home/P92Repo.hgs");
  CommPrint(1, "P92_CHECK_BEFORE_END\n");

  // Find SubA's own tree record (the one whose own entry is named
  // "inner.txt") by a real linear scan over the archive - same
  // record-walking convention Check.HC's own referential-integrity
  // pass uses - then flip one byte of that entry's child_hash field.
  I64 rsize;
  U8 *rbuf = FileRead("C:/Home/P92Repo.hgs", &rsize);
  U8 want[9];
  want[0]='i'; want[1]='n'; want[2]='n'; want[3]='e'; want[4]='r';
  want[5]='.'; want[6]='t'; want[7]='x'; want[8]='t';

  I64 pos = 16;
  Bool found = FALSE;
  while (pos < rsize && !found) {
    U64 rec_len = GetU64LE(rbuf, pos);
    U8 obj_type = rbuf[pos+8];
    U8 *content = rbuf + pos + 9;
    if (obj_type == OBJ_TREE) {
      U32 tcount = GetU32LE(content, 0);
      I64 tpos = 4;
      U32 te;
      for (te=0; te<tcount && !found; te++) {
        U8 tname_len = content[tpos]; tpos += 1;
        U8 *name = content + tpos;
        Bool is_inner = (tname_len == 9);
        if (is_inner) {
          I64 ci;
          for (ci=0; ci<9; ci++) if (name[ci] != want[ci]) is_inner = FALSE;
        }
        tpos += tname_len;
        tpos += 1; // child_type
        I64 hash_tpos = tpos;
        tpos += 64; // child_hash
        tpos += 8;  // entity_id (ADR 0004)
        if (is_inner) {
          content[hash_tpos] ^= 0xFF; // flip one byte of child_hash in place
          found = TRUE;
        }
      }
    }
    pos += 8 + rec_len + 64;
  }

  if (!found) {
    CommPrint(1, "P92_ERROR corruption_target_not_found\n");
  } else {
    FileWrite("C:/Home/P92Repo.hgs", rbuf, rsize);
    CommPrint(1, "P92_CORRUPTED_ONE_BYTE\n");
  }
  Free(rbuf);

  CommPrint(1, "P92_CHECK_AFTER_BEGIN\n");
  Hgit("check C:/Home/P92Repo.hgs");
  CommPrint(1, "P92_CHECK_AFTER_END\n");

  CommPrint(1, "PASS p92_check_nested_corruption_test\n");
}
P92CheckNestedCorruptionTest;

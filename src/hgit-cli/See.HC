// See.HC — `hgit see <offering>`: show one commit's full detail -
// message, timestamp, parent count, and its tree's entries.
//
// Takes the target commit as a raw 64-byte hash (same convention as
// every other hgit-core/hgit-cli function so far) rather than a hex
// string - hex parsing is a real, separate question for the eventual
// argv-driven entry point, not yet needed or built.
//
// Verified (experiments/22-hgit-see/) against the real two-commit
// repository from probes 18-21: shown HEAD (the "second" commit, 1
// parent, its tree's 2 entries), walked to and shown its parent (the
// root "first" commit, 0 parents), and confirmed a hash absent from the
// repo reports SEE_ERR cleanly rather than crashing or guessing.
//
// Depends on Canon.HC, Blake2b.HC, Hgs.HC, Object.HC, Commit.HC,
// Index.HC, Hex.HC (HashToHex for a relation target; U64ToHex for
// entity IDs, printed in hex rather than plain %d since a U64 with the
// high bit set otherwise prints as a negative number).
//
// Tree-entry parsing updated for ADR 0004's 8-byte entity ID field
// (experiments/49-entity-id/) - this file walks tree entries manually
// (not via Tree.HC's TreeFindEntry) so it needed its own offset fix.
//
// Also prints ADR 0005/0006's relation tag/target/entity, if the
// commit has one (experiments/51-relation-commands/,
// experiments/53-entity-scoped-relations/).

U0 HgitSee(U8 *repo_path, U8 *target_hash)
{
  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  if (rbuf == NULL) { CommPrint(1, "SEE_ERR not_a_repository\n"); return; }
  U16 rver;
  U64 rcount;
  Bool hok = HgsReadHeader(rbuf, &rver, &rcount);
  if (!hok) { CommPrint(1, "SEE_ERR bad_header\n"); return; }

  U8 idx_hashes[64*64];
  I64 idx_offsets[64];
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  I64 off_rel;
  Bool found = IndexLookup(idx_hashes, idx_offsets, idx_count, target_hash, &off_rel);
  if (!found) { CommPrint(1, "SEE_ERR not_found\n"); return; }
  I64 off = 16 + off_rel; // Index offsets are relative to the object
                           // section (rbuf+16) - see probe 12/19/20's
                           // recurring lesson.
  U8 obj_type = rbuf[off+8];
  if (obj_type != OBJ_COMMIT) { CommPrint(1, "SEE_ERR not_a_commit type=%d\n", obj_type); return; }
  U8 *content = rbuf + off + 9;

  U8 pcount = CommitParentCount(content);
  U64 ts = CommitTimestamp(content);
  U32 mlen = CommitMessageLen(content);
  U8 *msg = CommitMessage(content);
  U8 *tree_hash = CommitTreeHash(content);

  I64 i;
  CommPrint(1, "SEE_COMMIT ts=%d parents=%d msg=", ts, pcount);
  for (i=0; i<mlen; i++) CommPrint(1, "%c", msg[i]);
  CommPrint(1, "\n");

  U8 rel_tag = CommitRelationTag(content);
  if (rel_tag != REL_NONE) {
    U8 *rel_target = CommitRelationTarget(content);
    U8 rel_hex[129];
    HashToHex(rel_target, rel_hex);
    U64 rel_entity_id = CommitRelationEntityId(content); // ADR 0006
    U8 rel_entity_hex[17];
    U64ToHex(rel_entity_id, rel_entity_hex);
    CommPrint(1, "SEE_RELATION tag=%d target=%s entity=%s\n",
              rel_tag, rel_hex, rel_entity_hex);
  }

  I64 tree_off_rel;
  Bool tree_found = IndexLookup(idx_hashes, idx_offsets, idx_count, tree_hash, &tree_off_rel);
  if (!tree_found) { CommPrint(1, "SEE_ERR tree_not_found\n"); return; }
  I64 tree_off = 16 + tree_off_rel;
  U64 tree_len = GetU64LE(rbuf, tree_off);
  U8 *tree_content = rbuf + tree_off + 9;

  U32 tcount = GetU32LE(tree_content, 0);
  I64 tpos = 4;
  U32 te;
  CommPrint(1, "SEE_TREE entries=%d\n", tcount);
  for (te=0; te<tcount; te++) {
    U8 nlen = tree_content[tpos]; tpos += 1;
    U8 *name = tree_content + tpos; tpos += nlen;
    U8 ttype = tree_content[tpos]; tpos += 1;
    tpos += 64;
    U64 entity_id = GetU64LE(tree_content, tpos); tpos += 8; // ADR 0004
    U8 entity_hex[17];
    U64ToHex(entity_id, entity_hex); // hex, not %d - a U64 with the high
                                     // bit set prints as negative under
                                     // plain %d (hit in practice, see
                                     // experiments/49-entity-id/); hex
                                     // round-trips cleanly and is what
                                     // a user copies into `correct`/etc.
    CommPrint(1, "  entry type=%d id=%s name=", ttype, entity_hex);
    for (i=0; i<nlen; i++) CommPrint(1, "%c", name[i]);
    CommPrint(1, "\n");
  }
  CommPrint(1, "SEE_END\n");
}

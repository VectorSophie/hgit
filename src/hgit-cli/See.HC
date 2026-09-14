// See.HC — `hgit see <offering>`: show one commit's full detail -
// message, timestamp, parent count and hashes (probe 112 - a real
// merge commit's own SECOND parent was previously invisible here,
// only the count was shown), and its tree's entries.
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
//
// Recurses into nested trees (ADR 0010, experiments/93-see-nested-
// trees/) - a real, user-visible gap `hgit offertree` left open:
// before this, `see` only ever printed one flat level of entries, so
// a subdirectory's own contents were invisible short of a separate
// command. `SeePrintTreeEntries` is generic per-object-type (same
// pattern `CheckMarkReachable` in Check.HC already established for
// this project) - an `OBJ_TREE` child is looked up and recursed into,
// indented one level deeper, with no depth limit.

// Recursively prints one tree's own entries, then recurses into any
// `OBJ_TREE` child at `depth+1` indentation. A missing child object
// prints a real, honest marker instead of silently stopping or
// crashing - the same "don't hide a broken reference" stance
// Check.HC's own referential-integrity pass takes.
U0 SeePrintTreeEntries(U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                       U8 *tree_content, I64 depth)
{
  U32 tcount = GetU32LE(tree_content, 0);
  I64 tpos = 4;
  U32 te;
  I64 i, d;
  for (te=0; te<tcount; te++) {
    U8 nlen = tree_content[tpos]; tpos += 1;
    U8 *name = tree_content + tpos; tpos += nlen;
    U8 ttype = tree_content[tpos]; tpos += 1;
    U8 *child_hash = tree_content + tpos; tpos += 64;
    U64 entity_id = GetU64LE(tree_content, tpos); tpos += 8; // ADR 0004
    U8 entity_hex[17];
    U64ToHex(entity_id, entity_hex);

    for (d=0; d<depth; d++) CommPrint(1, "  ");
    CommPrint(1, "  entry type=%d id=%s name=", ttype, entity_hex);
    for (i=0; i<nlen; i++) CommPrint(1, "%c", name[i]);
    CommPrint(1, "\n");

    if (ttype == OBJ_TREE) {
      I64 child_off_rel;
      Bool child_found = IndexLookup(idx_hashes, idx_offsets, idx_count,
                                      child_hash, &child_off_rel);
      if (child_found) {
        I64 child_off = 16 + child_off_rel;
        U8 *child_content = rbuf + child_off + 9;
        SeePrintTreeEntries(rbuf, idx_hashes, idx_offsets, idx_count,
                            child_content, depth+1);
      } else {
        for (d=0; d<depth+1; d++) CommPrint(1, "  ");
        CommPrint(1, "  (missing nested tree object)\n");
      }
    }
  }
}

U0 HgitSee(U8 *repo_path, U8 *target_hash)
{
  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  if (rbuf == NULL) { CommPrint(1, "SEE_ERR not_a_repository\n"); return; }
  U16 rver;
  U64 rcount;
  Bool hok = HgsReadHeader(rbuf, &rver, &rcount);
  if (!hok) { CommPrint(1, "SEE_ERR bad_header\n"); return; }

  // ADR 0007's same fix, applied here (experiments/62-index-buffer-sweep/):
  // idx_hashes/idx_offsets used to be fixed [64*64]/[64] stack arrays, a
  // hardcoded 64-object-in-the-whole-repo cap - MAlloc'd from `rcount`
  // (exact, from the .HGS header) instead, freed on every return path.
  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  I64 off_rel;
  Bool found = IndexLookup(idx_hashes, idx_offsets, idx_count, target_hash, &off_rel);
  if (!found) { CommPrint(1, "SEE_ERR not_found\n"); Free(idx_hashes); Free(idx_offsets); return; }
  I64 off = 16 + off_rel; // Index offsets are relative to the object
                           // section (rbuf+16) - see probe 12/19/20's
                           // recurring lesson.
  U8 obj_type = rbuf[off+8];
  if (obj_type != OBJ_COMMIT) { CommPrint(1, "SEE_ERR not_a_commit type=%d\n", obj_type); Free(idx_hashes); Free(idx_offsets); return; }
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

  // Probe 112 (experiments/112-see-parent-hashes/): `parents=%d` only
  // ever showed the COUNT, never which commits they actually were -
  // a real gap for a merge commit specifically (the only real case
  // with more than one), where "how many parents" alone doesn't tell
  // a user which two histories were joined. One SEE_PARENT line per
  // parent, in the same real order Commit.HC's own encoding stores
  // them (ours first, theirs second, for a real merge commit -
  // Merge.HC's own convention).
  for (i=0; i<pcount; i++) {
    U8 *ph = CommitParentHash(content, i);
    U8 ph_hex[129];
    HashToHex(ph, ph_hex);
    CommPrint(1, "SEE_PARENT %s\n", ph_hex);
  }

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
  if (!tree_found) { CommPrint(1, "SEE_ERR tree_not_found\n"); Free(idx_hashes); Free(idx_offsets); return; }
  I64 tree_off = 16 + tree_off_rel;
  U64 tree_len = GetU64LE(rbuf, tree_off);
  U8 *tree_content = rbuf + tree_off + 9;

  U32 tcount = GetU32LE(tree_content, 0);
  CommPrint(1, "SEE_TREE entries=%d\n", tcount);
  SeePrintTreeEntries(rbuf, idx_hashes, idx_offsets, idx_count, tree_content, 0);
  CommPrint(1, "SEE_END\n");
  Free(idx_hashes);
  Free(idx_offsets);
}

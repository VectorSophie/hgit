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
// Index.HC.

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
    CommPrint(1, "  entry type=%d name=", ttype);
    for (i=0; i<nlen; i++) CommPrint(1, "%c", name[i]);
    CommPrint(1, "\n");
  }
  CommPrint(1, "SEE_END\n");
}

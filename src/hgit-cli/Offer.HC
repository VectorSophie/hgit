// Offer.HC — `hgit offer`: the actual recording command. This is the
// integration point for the whole object model built so far - the
// first command that creates real objects from real files rather than
// only reading/checking what already exists.
//
// What it does: enumerates files matching `find_mask`, stores each as
// an OBJ_BLOB, builds an OBJ_TREE entry list over them, creates an
// OBJ_COMMIT referencing that tree and the repo's current HEAD (if any)
// as parent, appends all of it to the repo's .HGS file, and points
// HEAD at the new commit. Verified end-to-end, twice in a row - a root
// offering (no parent) and a second offering (parent = the first) with
// a changed file - in experiments/18-hgit-offer/.
//
// Deliberately minimal / not yet done, see that probe's README for the
// full list: no working-copy diffing (every matching file is re-blobbed
// on every offer, not just changed ones - no deduplication awareness at
// this layer, though identical content does still hash-dedupe for free
// since objects are content-addressed), fixed-size local buffers
// (archive[8192], tree_content[2048], per-file blob_tagged[512] - real
// limits, not yet hit by anything tested), and `find_mask` has to be
// passed in rather than "the whole repo directory minus the repo's own
// files" (no self-exclusion logic yet).
//
// Depends on Canon.HC, Blake2b.HC, Archive.HC, Hgs.HC, Object.HC,
// Tree.HC, Commit.HC (the whole hgit-core object layer),
// Index.HC, and OpLog.HC. Every offer now logs its own HEAD
// before/after transition via OpLogAppend before moving HEAD, so
// `hgit undo` (OpLogUndo) can revert it - wired in and verified in
// experiments/31-oplog-in-offer/ (probe 30 had only called OpLogAppend
// manually, alongside offer, not from within it).
//
// Per ADR 0004 (experiments/49-entity-id/): each tree entry now
// carries a stable entity ID. If there's a parent commit, its tree is
// looked up first so each currently-offered file's ID can be copied
// forward from the OLD entry of the same name (TreeFindEntry) -
// otherwise (new name, or root offering) a fresh ID is generated
// (Tree.HC's GenerateEntityId).
//
// Per ADR 0009 (experiments/70-rename-detection/): if the name isn't
// found, the file's CONTENT hash is also checked against the parent
// tree (TreeFindEntryByHash) before falling back to a fresh ID - exact
// -content rename detection, closing the gap ADR 0004 itself deferred.
// A rename with an edit in the same offer still isn't detected (looks
// new either way) - see ADR 0009's own "what this slice does not do".
//
// Per ADR 0005 (experiments/51-relation-commands/): HgitOffer itself
// is now a thin wrapper over HgitOfferWithRelation (REL_NONE/NULL),
// defined first since HolyC has no forward declarations - a call to a
// not-yet-defined function later in the same push fails to compile -
// `hgit correct`/`hgit revert`/`hgit reconcile` call the same
// underlying logic with a real relation attached, rather than
// duplicating the whole offer process.

// ADR 0007 (experiments/61-dynamic-archive/): headroom reserved above
// the existing repo's own size for this call's new objects, and a
// purely pathological-input sanity ceiling.
//
// ARCHIVE_HEADROOM is a real computed worst case, not a guess, given
// probe 56's own still-in-place guards: tree_content[2048] caps at
// ~27 entries (2048 / a 75-byte minimal single-char-name entry), each
// of which can carry up to a 511-byte blob (blob_tagged[512]'s own
// cap) - 27*511 ~ 13800 bytes of blob content, plus the tree object's
// own up-to-2048 bytes, plus a commit up to 512, plus ~9 bytes of HGS
// record overhead per object (~29 objects worst case ~ 260 bytes).
// That worst case totals ~16600 bytes; 20000 leaves real margin and
// matches the exact size independently confirmed safe via MAlloc in
// experiments/61-dynamic-archive/.
#define ARCHIVE_HEADROOM 20000
#define ARCHIVE_SANITY_MAX 1000000000

U0 HgitOfferWithRelation(U8 *repo_path, U8 *find_mask, U8 *message, I64 message_len,
                          U64 timestamp, U8 relation_tag, U8 *relation_target,
                          U64 relation_entity_id)
{
  // Load the existing repo's object section into a working buffer.
  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  U16 rver;
  U64 rcount;
  HgsReadHeader(rbuf, &rver, &rcount);

  // ADR 0007 (experiments/61-dynamic-archive/): `archive` used to be a
  // fixed `U8[8192]` stack buffer - probe 60 found and bisected a real
  // kernel GPF once a repo's own growth alone (no wildcards, no large
  // files - each offer/correct grows a real repo by ~600 bytes) crossed
  // that ceiling, and probe 60's own fix was a clean refusal rather
  // than lifting the ceiling. This does that: `archive` is now
  // `MAlloc`'d at exactly the size this call needs (the existing repo
  // plus a generous, still-bounded headroom for this call's own new
  // objects - probe 56's own per-file/tree caps already bound that
  // upper end), freed on every exit path. `ARCHIVE_SANITY_MAX` is a
  // much higher, purely pathological-input ceiling (guards against a
  // corrupted/absurd `rsize`, not real growth) - confirmed via
  // `experiments/61-dynamic-archive/` that a 20,000-byte `MAlloc`
  // writes/reads back correctly with no corruption; `MAlloc`/`Free` are
  // real TempleOS kernel primitives, already relied on implicitly by
  // this project's own daemon bootstrap.
  if (rsize > ARCHIVE_SANITY_MAX) {
    CommPrint(1, "OFFER_REFUSED archive_absurdly_large size=%d\n", rsize);
    return;
  }

  I64 archive_cap = rsize + ARCHIVE_HEADROOM;
  U8 *archive = MAlloc(archive_cap);
  I64 alen = 16; // header goes here at the end, once we know the count
  I64 i;
  for (i = 0; i < rsize-16; i++) archive[16+i] = rbuf[16+i];
  alen = rsize;

  // Parent lookup happens BEFORE building the new tree, so each file's
  // entity ID can be carried forward from the parent's own tree.
  U8 parent_hash[64];
  Bool has_parent = CurrentHeadRead(repo_path, parent_hash);

  // Same class of fixed-buffer bug ADR 0007 fixed for `archive` -
  // `idx_hashes`/`idx_offsets` used to be `[64*64]`/`[64]` stack arrays,
  // a hardcoded cap of 64 *objects total in the whole repo* (not 64
  // matched files). Confirmed hit in practice while re-verifying ADR
  // 0007's own fix (experiments/61-dynamic-archive/): once
  // `archive`'s ceiling was lifted, real growth continued until this
  // *next* fixed buffer overflowed instead, at ~22 offers (66+ objects
  // - 3 objects/offer). Same fix, same pattern: MAlloc'd from `rcount`
  // (already known exactly from the .HGS header - no headroom guess
  // needed, this one is an exact count by construction), freed right
  // after this block's last use of it.
  U8 *old_idx_hashes = MAlloc(rcount*64 + 64);
  I64 *old_idx_offsets = MAlloc((rcount+1)*8);
  I64 old_idx_count = 0;
  U8 *old_tree_content = NULL;
  I64 old_tree_content_len = 0;
  if (has_parent) {
    IndexBuild(rbuf+16, rsize-16, old_idx_hashes, old_idx_offsets, &old_idx_count);
    I64 pc_off_rel;
    Bool pc_found = IndexLookup(old_idx_hashes, old_idx_offsets, old_idx_count,
                                 parent_hash, &pc_off_rel);
    if (pc_found) {
      I64 pc_off = 16 + pc_off_rel;
      U8 *pc_content = rbuf + pc_off + 9;
      U8 *old_tree_hash = CommitTreeHash(pc_content);
      I64 ot_off_rel;
      Bool ot_found = IndexLookup(old_idx_hashes, old_idx_offsets, old_idx_count,
                                   old_tree_hash, &ot_off_rel);
      if (ot_found) {
        I64 ot_off = 16 + ot_off_rel;
        U64 ot_record_len = GetU64LE(rbuf, ot_off);
        old_tree_content = rbuf + ot_off + 9;
        old_tree_content_len = ot_record_len - 1; // minus the OBJ_TREE tag byte
      }
    }
  }
  Free(old_idx_hashes);
  Free(old_idx_offsets);

  // Build blobs + tree from every file matching find_mask.
  //
  // Real bug found and fixed (experiments/56-offer-buffer-guard/,
  // after experiments/55-reconciledoc/'s own GPF and a follow-up hang
  // reproduced both failure modes from the same root cause): these
  // three buffers are fixed-size stack arrays with no bounds check
  // against `find_mask` matching more/bigger files than they can hold
  // - as few as ~25-40 small matched files overflows `tree_content`
  // (each entry costs 1+name_len+1+64+8 bytes), and any single file
  // over 511 bytes overflows `blob_tagged`. The overflow corrupts
  // whatever's adjacent on the stack, which manifested as either a
  // silent infinite loop or a real kernel GPF depending on exactly
  // what got clobbered - not a single deterministic failure. Guarded
  // below: a file that doesn't fit is skipped with a clear
  // host-visible message instead of silently overflowing anything.
  U8 tree_content[2048];
  I64 tlen = 4; // leave room for the U32 entry_count, filled in below
  I64 entry_count = 0;

  CDirEntry *tmpde = FilesFind(find_mask, 0);
  CDirEntry *tmpde1 = tmpde;
  while (tmpde) {
    I64 fsize;
    U8 *fbuf = FileRead(tmpde->full_name, &fsize);

    // name = just the filename portion, after the last '/'
    I64 name_start = 0, j;
    for (j=0; tmpde->full_name[j]; j++) if (tmpde->full_name[j]=='/') name_start=j+1;
    I64 name_len = j - name_start;
    I64 entry_needed = 1 + name_len + 1 + 64 + 8;

    // No `continue` here - confirmed absent from HolyC (matches
    // experiments/templeos-devkit's own documented bug-compat corpus,
    // `holyc-parser/tests/corpus/failing/007-bug-compat-bug52-continue-keyword.hc`
    // - `if (cond) continue;` isn't a keyword there, it parses as an
    // undefined identifier). Nest the rest of the loop body inside an
    // `else` instead of early-`continue`-ing past the guards.
    if (fsize+1 > 512) {
      CommPrint(1, "OFFER_SKIP file_too_large %s\n", tmpde->full_name);
    } else if (tlen + entry_needed > 2048) {
      CommPrint(1, "OFFER_SKIP tree_full %s\n", tmpde->full_name);
    } else {
      U8 blob_tagged[512];
      blob_tagged[0] = OBJ_BLOB;
      for (i=0; i<fsize; i++) blob_tagged[1+i] = fbuf[i];
      U8 blob_hash[64];
      B2Hash512Any(blob_tagged, fsize+1, blob_hash);
      ObjectPut(archive, &alen, OBJ_BLOB, fbuf, fsize);

      // ADR 0009 (experiments/70-rename-detection/): if this name
      // doesn't match anything in the parent's own tree, check
      // whether its CONTENT does before generating a fresh identity -
      // exact-content rename detection, the same scope as ADR 0004's
      // own by-name carry-forward, just keyed on the blob hash instead
      // of the name when the name lookup fails.
      U64 entity_id;
      Bool found_old = FALSE;
      if (old_tree_content != NULL) {
        U8 old_type;
        U8 old_hash[64];
        found_old = TreeFindEntry(old_tree_content, old_tree_content_len,
                                   tmpde->full_name+name_start, name_len,
                                   &old_type, old_hash, &entity_id);
        if (!found_old) {
          found_old = TreeFindEntryByHash(old_tree_content, old_tree_content_len,
                                           blob_hash, &entity_id);
        }
      }
      if (!found_old) entity_id = GenerateEntityId();

      TreeEncodeEntry(tree_content, &tlen, tmpde->full_name+name_start, name_len,
                       OBJ_BLOB, blob_hash, entity_id);
      entry_count++;
    }
    tmpde = tmpde->next;
  }
  DirTreeDel(tmpde1);
  PutU32LE(tree_content, 0, entry_count);

  I64 tree_content_len = tlen;
  U8 tree_tagged[2048];
  tree_tagged[0] = OBJ_TREE;
  for (i=0; i<tree_content_len; i++) tree_tagged[1+i] = tree_content[i];
  U8 tree_hash[64];
  B2Hash512Any(tree_tagged, tree_content_len+1, tree_hash);
  ObjectPut(archive, &alen, OBJ_TREE, tree_content, tree_content_len);

  // Commit content itself (has_parent/parent_hash already computed above).
  U8 commit_content[512];
  I64 clen = 0;
  CommitEncode(commit_content, &clen, tree_hash, parent_hash,
               has_parent, timestamp, message, message_len,
               relation_tag, relation_target, relation_entity_id);
  U8 commit_tagged[512];
  commit_tagged[0] = OBJ_COMMIT;
  for (i=0; i<clen; i++) commit_tagged[1+i] = commit_content[i];
  U8 commit_hash[64];
  B2Hash512Any(commit_tagged, clen+1, commit_hash);
  ObjectPut(archive, &alen, OBJ_COMMIT, commit_content, clen);

  // Rewrite the repo with the updated header (new total object count:
  // rcount existing + entry_count blobs + 1 tree + 1 commit).
  HgsWriteHeader(archive, rver, rcount + entry_count + 2);
  FileWrite(repo_path, archive, alen);

  // Log this offer's HEAD transition before moving HEAD, so `undo` can
  // revert it. No-parent case logs an all-zero prev_head sentinel
  // (parent_hash is uninitialized stack garbage when has_parent is
  // FALSE - never read it in that case).
  U8 log_prev_head[64];
  if (has_parent) {
    for (i=0; i<64; i++) log_prev_head[i] = parent_hash[i];
  } else {
    for (i=0; i<64; i++) log_prev_head[i] = 0;
  }
  OpLogAppend(repo_path, log_prev_head, commit_hash, timestamp);

  CurrentHeadWrite(repo_path, commit_hash);
  Free(archive);
}

U0 HgitOffer(U8 *repo_path, U8 *find_mask, U8 *message, I64 message_len,
             U64 timestamp)
{
  HgitOfferWithRelation(repo_path, find_mask, message, message_len,
                         timestamp, REL_NONE, NULL, 0);
}

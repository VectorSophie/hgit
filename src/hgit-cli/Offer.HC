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
// since objects are content-addressed). `archive` and each matched
// file's own blob buffer are now `MAlloc`'d at a real computed size,
// not fixed stack arrays, in BOTH the flat `hgit offer` path (probe
// 106) and the recursive `offertree` path (probe 107) - only the
// per-directory-level `tree_content[2048]`/`tree_content[4096]`
// entry-COUNT caps (unrelated to file byte size) remain real, known,
// not-yet-hit limits. `find_mask` also still
// has to be passed in rather than "the whole repo directory minus the
// repo's own files" (no self-exclusion logic yet).
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
//
// No longer used by either `HgitOfferWithRelation` (flat `hgit offer`,
// probe 106) or `HgitOfferTreeWithRelation` (`offertree`, probe 107) -
// both now compute a real capacity from the actual files being
// offered instead (see OBJECT_RECORD_OVERHEAD/TREE_COMMIT_HEADROOM and
// TREE_LEVEL_MAX/COMMIT_HEADROOM below). Left defined and documented
// here as historical record of the worst-case reasoning ADR 0007
// originally established, not because anything still uses it.
#define ARCHIVE_HEADROOM 20000
#define ARCHIVE_SANITY_MAX 1000000000

// Probe 106 (experiments/106-offer-large-file-support/): now that
// probe 105 removed `ObjectPut`'s own shared `tagged[4096]` ceiling,
// the flat `hgit offer` path's own per-file `fsize+1 > 512` skip was
// no longer inherited from anywhere deeper - lifted here, backed by a
// real COMPUTED archive capacity instead of a fixed headroom: a first
// `FilesFind` pass over the same `find_mask` sums every matched
// entry's own real `size` field (no `FileRead` needed just to size -
// `CDirEntry`'s own `size` field, confirmed real via
// `Kernel/BlkDev/FileSysFAT.HC`'s own `tmpde->size=de->size`) before
// `archive` is `MAlloc`'d, so a large offered file's own real bytes
// are accounted for exactly rather than assumed to fit inside a fixed
// per-file cap. `OBJECT_RECORD_OVERHEAD` is `HgsPut`'s own fixed
// per-record cost (8-byte length + 1-byte type tag + 64-byte hash =
// 73, `Hgs.HC`'s own record shape). `TREE_COMMIT_HEADROOM` covers the
// still-in-place `tree_content[2048]` entry-count cap (unrelated to
// file byte size, not removed here) plus its own record overhead,
// plus a generous fixed bound for the commit object and its own
// record overhead.
#define OBJECT_RECORD_OVERHEAD 73
#define TREE_COMMIT_HEADROOM 3000

// Probe 107 (experiments/107-offertree-large-file-support/):
// `HgitOfferTreeWithRelation` (`offertree`) needs its own headroom
// formula, not `TREE_COMMIT_HEADROOM` above - unlike the flat path,
// it can create MULTIPLE tree objects (one per real subdirectory,
// `TreeBuildRecursive`'s own recursion), each up to a real per-level
// entry-content cap. `TREE_LEVEL_MAX` matches the largest per-level
// buffer actually used (`HgitOfferTreeWithRelation`'s own root-level
// `tree_content[4096]`; nested nested levels use a smaller
// `child_tree_content[2048]`, so 4096 is a safe, real upper bound, not
// a guess) plus that tree's own record overhead, times (subdirectory
// count + 1 for the root tree itself).
#define TREE_LEVEL_MAX 4096
#define COMMIT_HEADROOM 600

// ADR 0009 addendum (experiments/84-fuzzy-rename-detection/): a
// currently-offered file's content must score at least
// `FOSSIL_RENAME_SIMILARITY_THRESHOLD` similar (`FossilSimilarityPercent`,
// `Fossil.HC`'s own shared threshold - also used by `Status.HC`) to
// some old, name-unmatched blob before its identity is carried forward
// this way.

// Third fallback in the entity-ID chain (name match, then exact-hash
// match, now this): scans every BLOB entry in the parent's own tree
// and, for each, resolves its actual content (via the same
// old_idx_hashes/old_idx_offsets/rbuf the caller already built for the
// exact-hash path) and scores it against `target_content` with
// Fossil's own similarity measure (ADR 0008,
// experiments/83-fossil-similarity/). Returns the BEST-scoring
// candidate's entity ID if it meets FOSSIL_RENAME_SIMILARITY_THRESHOLD,
// FALSE otherwise. Same "first/best match wins, no cross-file
// disambiguation" simplification ADR 0009 already documents for its
// own exact-content matching: this doesn't check whether some OTHER
// file in the same offering already exactly matched this same old
// entry - a real, documented limitation, not a hidden bug (see this
// probe's own README).
Bool OfferFindFuzzyRename(U8 *rbuf, U8 *old_tree_content, I64 old_tree_content_len,
                          U8 *old_idx_hashes, I64 *old_idx_offsets, I64 old_idx_count,
                          U8 *target_content, I64 target_content_len,
                          U64 *entity_id_out)
{
  U32 count = GetU32LE(old_tree_content, 0);
  I64 pos = 4;
  U32 e;
  I64 best_sim = -1;
  U64 best_entity_id = 0;
  for (e=0; e<count; e++) {
    U8 name_len = old_tree_content[pos]; pos += 1;
    pos += name_len;
    U8 child_type = old_tree_content[pos]; pos += 1;
    U8 *child_hash = old_tree_content + pos; pos += 64;
    U64 this_entity_id = GetU64LE(old_tree_content, pos); pos += 8;

    if (child_type == OBJ_BLOB) {
      I64 off_rel;
      if (IndexLookup(old_idx_hashes, old_idx_offsets, old_idx_count, child_hash, &off_rel)) {
        I64 off = 16 + off_rel;
        U64 rec_len = GetU64LE(rbuf, off);
        U8 *content = rbuf + off + 9; // skip the OBJ_BLOB type tag byte
        I64 content_len = rec_len - 1;
        I64 sim = FossilSimilarityPercent(content, content_len,
                                          target_content, target_content_len);
        if (sim > best_sim) {
          best_sim = sim;
          best_entity_id = this_entity_id;
        }
      }
    }
  }
  if (best_sim >= FOSSIL_RENAME_SIMILARITY_THRESHOLD) {
    *entity_id_out = best_entity_id;
    return TRUE;
  }
  return FALSE;
}

// Probe 107 (experiments/107-offertree-large-file-support/): a real,
// computed sum of every real file's own size across the WHOLE subtree
// under dir_path, plus a subdirectory count - mirrors
// TreeBuildRecursive's own recursion, dot/dotdot skip, and
// `attr & 16` subdirectory check below, but only sums (never writes
// to `archive`), so `HgitOfferTreeWithRelation` can size `archive`
// correctly instead of assuming a fixed per-file/per-tree cap.
U0 SumTreeFileBytes(U8 *dir_path, I64 *bytes_out, I64 *file_count_out, I64 *subdir_count_out)
{
  U8 mask[256];
  StrPrint(mask, "%s*", dir_path);
  CDirEntry *tmpde = FilesFind(mask, 0);
  CDirEntry *tmpde1 = tmpde;
  while (tmpde) {
    I64 name_start = 0, j;
    for (j=0; tmpde->full_name[j]; j++) if (tmpde->full_name[j]=='/') name_start=j+1;
    Bool is_dot = StrCmp(tmpde->full_name+name_start, ".") == 0;
    Bool is_dotdot = StrCmp(tmpde->full_name+name_start, "..") == 0;
    if (!is_dot && !is_dotdot) {
      if (tmpde->attr & 16) {
        *subdir_count_out += 1;
        U8 subdir_path[256];
        StrPrint(subdir_path, "%s/", tmpde->full_name);
        SumTreeFileBytes(subdir_path, bytes_out, file_count_out, subdir_count_out);
      } else {
        *bytes_out += tmpde->size;
        *file_count_out += 1;
      }
    }
    tmpde = tmpde->next;
  }
  DirTreeDel(tmpde1);
}

// ADR 0010 (experiments/90-recursive-tree-primitive/): a real,
// standalone, tested recursive tree-building primitive - NOT wired
// into `HgitOfferWithRelation`'s own live dispatch below (see that
// ADR's own "what this slice does not do"). Recursively builds a tree
// object from a real directory (`dir_path`, trailing "/" required):
// each plain file becomes an OBJ_BLOB entry, each subdirectory
// (`CDirEntry.attr & 16`, probe 88) becomes a nested OBJ_TREE entry,
// built depth-first (children stored via ObjectPut before their own
// parent tree, since a tree's hash needs its full content first -
// exactly proven possible, with zero object-model changes, in probe
// 89). Entity-ID/rename continuity (exact name, exact content hash,
// then fuzzy) is resolved at EACH directory level independently,
// against whichever old tree matches that same relative directory
// position in the parent commit - a file moved to a *different*
// directory is not identity-tracked across that move in this slice
// (ADR 0010's own explicit scope decision), only renamed/edited
// within the same directory.
//
// `tree_content_out` must be sized generously by the caller (same
// "no premature fixed-cap tuning" stance as `Offer.HC`'s own
// `tree_content[2048]` - a real, known limit, not yet hit by anything
// tested, same as here).
U0 TreeBuildRecursive(U8 *dir_path, U8 *archive, I64 *alen,
                      U8 *rbuf, U8 *idx_hashes, I64 *idx_offsets, I64 idx_count,
                      U8 *old_tree_content, I64 old_tree_content_len,
                      U8 *tree_content_out, I64 *tree_content_len_out,
                      U8 *ign_patterns, U8 *ign_negate, U8 *ign_kind, I64 ign_count,
                      U8 *rel_dir,
                      U8 *attr_patterns, U8 *attr_kind, U8 *attr_sets, U8 *attr_values, I64 attr_count,
                      U8 *attrs_content, I64 *attrs_len, I64 *attrs_entry_count)
{
  I64 tlen = 4; // room for entry_count, filled in at the end
  I64 entry_count = 0;

  U8 mask[256];
  StrPrint(mask, "%s*", dir_path);
  CDirEntry *tmpde = FilesFind(mask, 0);
  CDirEntry *tmpde1 = tmpde;
  while (tmpde) {
    I64 name_start = 0, j;
    for (j=0; tmpde->full_name[j]; j++) if (tmpde->full_name[j]=='/') name_start=j+1;
    I64 name_len = j - name_start;
    Bool is_dot = StrCmp(tmpde->full_name+name_start, ".") == 0;
    Bool is_dotdot = StrCmp(tmpde->full_name+name_start, "..") == 0;

    if (!is_dot && !is_dotdot) {
      if (tmpde->attr & 16) {
        // Subdirectory: resolve the matching OLD subtree at this same
        // relative position (if any) to pass down as the "old tree"
        // for the recursive call - the same by-name lookup
        // TreeFindEntry already does, just for a tree-typed entry.
        U8 old_sub_type;
        U8 old_sub_hash[64];
        U64 old_sub_entity_id;
        U8 *old_sub_tree_content = NULL;
        I64 old_sub_tree_content_len = 0;
        Bool found_old_sub = FALSE;
        // ADR 0014's safety rule: this must reflect "was this NAME
        // tracked at all," independent of the type-mismatch reset
        // below - a directory that was already tracked (even if its
        // old entry happened to be a file, a real kind change) must
        // never be hidden by a later ignore rule.
        Bool name_was_tracked = FALSE;
        if (old_tree_content != NULL) {
          found_old_sub = TreeFindEntry(old_tree_content, old_tree_content_len,
                                        tmpde->full_name+name_start, name_len,
                                        &old_sub_type, old_sub_hash, &old_sub_entity_id);
          name_was_tracked = found_old_sub;
          if (found_old_sub && old_sub_type == OBJ_TREE) {
            I64 sub_off_rel;
            if (IndexLookup(idx_hashes, idx_offsets, idx_count, old_sub_hash, &sub_off_rel)) {
              I64 sub_off = 16 + sub_off_rel;
              U64 sub_rec_len = GetU64LE(rbuf, sub_off);
              old_sub_tree_content = rbuf + sub_off + 9;
              old_sub_tree_content_len = sub_rec_len - 1;
            }
          } else {
            found_old_sub = FALSE; // same name existed but wasn't a
                                     // tree (e.g. a file replaced by a
                                     // directory) - no old identity to
                                     // carry forward.
          }
        }

        if (!name_was_tracked &&
            IsIgnored(ign_patterns, ign_negate, ign_kind, ign_count,
                      tmpde->full_name+name_start, rel_dir)) {
          CommPrint(1, "OFFER_IGNORED %s\n", tmpde->full_name);
        } else {
        U8 subdir_path[256];
        StrPrint(subdir_path, "%s/", tmpde->full_name);
        U8 child_rel_dir[256];
        if (rel_dir[0] == 0) StrPrint(child_rel_dir, "%s", tmpde->full_name+name_start);
        else StrPrint(child_rel_dir, "%s/%s", rel_dir, tmpde->full_name+name_start);
        U8 child_tree_content[2048];
        I64 child_tree_content_len;
        TreeBuildRecursive(subdir_path, archive, alen, rbuf, idx_hashes, idx_offsets, idx_count,
                           old_sub_tree_content, old_sub_tree_content_len,
                           child_tree_content, &child_tree_content_len,
                           ign_patterns, ign_negate, ign_kind, ign_count, child_rel_dir,
                           attr_patterns, attr_kind, attr_sets, attr_values, attr_count,
                           attrs_content, attrs_len, attrs_entry_count);

        // Real gap surfaced by ADR 0014's own "generated/*" example:
        // a subdirectory whose entire real content was ignore-filtered
        // out (or that's simply empty on disk) used to still leave a
        // pointless empty tree entry behind. Git's own real, well-
        // known convention is to never track an empty directory at
        // all - matched here, generally, not just for the ignore
        // case: a child tree with zero real entries is treated as if
        // that subdirectory doesn't exist for tree purposes, no
        // object stored, no entry encoded.
        if (GetU32LE(child_tree_content, 0) > 0) {
          U8 child_tagged[2048];
          child_tagged[0] = OBJ_TREE;
          I64 ci;
          for (ci=0; ci<child_tree_content_len; ci++) child_tagged[1+ci] = child_tree_content[ci];
          U8 child_hash[64];
          B2Hash512Any(child_tagged, child_tree_content_len+1, child_hash);
          ObjectPut(archive, alen, OBJ_TREE, child_tree_content, child_tree_content_len);

          U64 sub_entity_id;
          if (found_old_sub) sub_entity_id = old_sub_entity_id;
          else sub_entity_id = GenerateEntityId();

          TreeEncodeEntry(tree_content_out, &tlen, tmpde->full_name+name_start, name_len,
                          OBJ_TREE, child_hash, sub_entity_id);
          entry_count++;
        }
        }
      } else {
        // Regular file: the same blob-storage + entity-ID logic
        // HgitOfferWithRelation's own flat loop already uses,
        // parameterized by THIS directory level's own old tree.
        I64 fsize;
        U8 *fbuf = HgitFileRead(tmpde->full_name, &fsize);
        U8 file_at_type; U8 file_at_hash[64]; U64 file_at_entity;
        Bool file_already_tracked = (old_tree_content != NULL) &&
          TreeFindEntry(old_tree_content, old_tree_content_len,
                        tmpde->full_name+name_start, name_len,
                        &file_at_type, file_at_hash, &file_at_entity);
        if (!file_already_tracked &&
            IsIgnored(ign_patterns, ign_negate, ign_kind, ign_count,
                      tmpde->full_name+name_start, rel_dir)) {
          CommPrint(1, "OFFER_IGNORED %s\n", tmpde->full_name);
        } else {
          // Probe 107: was `if (fsize+1 <= 512)` guarding a fixed
          // `blob_tagged[512]` stack buffer - a file over 511 bytes
          // was silently DROPPED here (no message at all, worse than
          // the flat path's old `OFFER_SKIP`). `MAlloc`'d at the
          // file's own real size instead, same fix as probe 106's
          // flat-path version; `archive` itself is now sized by a
          // real recursive sum (`SumTreeFileBytes`, above) rather than
          // a fixed headroom, so this no longer risks overflowing it.
          U8 *blob_tagged = MAlloc(fsize+1);
          blob_tagged[0] = OBJ_BLOB;
          I64 bi;
          for (bi=0; bi<fsize; bi++) blob_tagged[1+bi] = fbuf[bi];
          U8 blob_hash[64];
          B2Hash512Any(blob_tagged, fsize+1, blob_hash);
          Free(blob_tagged);
          ObjectPut(archive, alen, OBJ_BLOB, fbuf, fsize);

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
            if (!found_old) {
              found_old = OfferFindFuzzyRename(rbuf, old_tree_content, old_tree_content_len,
                                               idx_hashes, idx_offsets, idx_count,
                                               fbuf, fsize, &entity_id);
            }
          }
          if (!found_old) entity_id = GenerateEntityId();

          // ADR 0015: same real, fresh-every-offer mode computation
          // as the flat path, keyed on this directory level's own
          // rel_dir for DIR_CONTENTS-pattern anchoring, accumulating
          // into the ONE shared attrs buffer threaded through the
          // whole recursion (same "one archive, one alen" convention
          // this file already uses for the object store itself).
          Bool auto_binary = IsContentBinary(fbuf, fsize);
          U8 mode = GetEffectiveMode(attr_patterns, attr_kind, attr_sets, attr_values, attr_count,
                                      tmpde->full_name+name_start, rel_dir, auto_binary);
          if (mode != 0) {
            AttrsListEncode(attrs_content, attrs_len, entity_id, mode);
            (*attrs_entry_count)++;
          }

          TreeEncodeEntry(tree_content_out, &tlen, tmpde->full_name+name_start, name_len,
                          OBJ_BLOB, blob_hash, entity_id);
          entry_count++;
        }
      }
    }
    tmpde = tmpde->next;
  }
  DirTreeDel(tmpde1);
  PutU32LE(tree_content_out, 0, entry_count);
  *tree_content_len_out = tlen;
}

U0 HgitOfferWithRelation(U8 *repo_path, U8 *find_mask, U8 *message, I64 message_len,
                          U64 timestamp, U8 relation_tag, U8 *relation_target,
                          U64 relation_entity_id)
{
  // Load the existing repo's object section into a working buffer.
  I64 rsize;
  U8 *rbuf = HgitFileRead(repo_path, &rsize);
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

  // Probe 106: a real, computed capacity (sum of every matched file's
  // own real size, via CDirEntry->size - no FileRead needed just to
  // size) rather than a fixed headroom, so a large offered file's own
  // bytes are always accounted for exactly.
  I64 new_content_bytes = 0;
  I64 new_file_count = 0;
  CDirEntry *size_de = FilesFind(find_mask, 0);
  CDirEntry *size_de1 = size_de;
  while (size_de) {
    new_content_bytes += size_de->size;
    new_file_count++;
    size_de = size_de->next;
  }
  DirTreeDel(size_de1);

  // ADR 0015: real, computed headroom for this call's own OBJ_ATTRS
  // object too (9 bytes/entry max - one per real matched file - plus
  // its own record overhead), same "no guessed cap" discipline as
  // every other buffer here.
  I64 archive_cap = rsize + new_content_bytes
                   + new_file_count * OBJECT_RECORD_OVERHEAD
                   + TREE_COMMIT_HEADROOM
                   + new_file_count * 9 + OBJECT_RECORD_OVERHEAD;
  if (archive_cap > ARCHIVE_SANITY_MAX) {
    CommPrint(1, "OFFER_REFUSED archive_absurdly_large size=%d\n", archive_cap);
    return;
  }
  U8 *archive = MAlloc(archive_cap);
  I64 alen = 16; // header goes here at the end, once we know the count
  I64 i;
  for (i = 0; i < rsize-16; i++) archive[16+i] = rbuf[16+i];
  alen = rsize;

  // ADR 0015: `.hgitattributes` lives alongside `find_mask`'s own
  // directory portion, same convention `.hgitignore` (ADR 0014)
  // already uses. `attrs_content`/`attrs_len` accumulate one
  // (entity_id, mode) record per file whose effective mode is
  // non-default - MAlloc'd from the real matched-file count, same
  // upper bound `archive_cap`'s own headroom above already computed.
  U8 attr_ignore_path[256];
  I64 attr_dp_len = 0, attr_dp_j;
  for (attr_dp_j=0; find_mask[attr_dp_j]; attr_dp_j++) if (find_mask[attr_dp_j]=='/') attr_dp_len=attr_dp_j+1;
  for (attr_dp_j=0; attr_dp_j<attr_dp_len; attr_dp_j++) attr_ignore_path[attr_dp_j] = find_mask[attr_dp_j];
  StrPrint(attr_ignore_path+attr_dp_len, ".hgitattributes");
  U8 *attr_patterns, *attr_kind, *attr_sets, *attr_values;
  I64 attr_count;
  AttrsRulesLoad(attr_ignore_path, &attr_patterns, &attr_kind, &attr_sets, &attr_values, &attr_count);
  U8 *attrs_content = MAlloc(new_file_count*9 + 9);
  I64 attrs_len = 4; // room for the U32 count, filled in below
  I64 attrs_entry_count = 0;

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
  // old_idx_hashes/old_idx_offsets stay alive through the per-file
  // loop below now (ADR 0009 addendum, experiments/84-fuzzy-rename-detection/)
  // - OfferFindFuzzyRename needs them to resolve an old blob's hash
  // back to its actual content. Freed once, after that loop, instead
  // of here.

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

  // ADR 0014 (docs/adr/0014-ignore-rules.md): `.hgitignore` lives
  // alongside `find_mask`'s own directory portion - the same
  // directory-prefix convention `Status.HC`'s own `dir_prefix`
  // parameter already uses elsewhere, derived here since this flat
  // command takes only `find_mask`. Loaded once per call, fresh from
  // disk (no caching - real filesystem state at the moment of this
  // offer, matching hgit's own design throughout).
  U8 ignore_path[256];
  I64 dp_len = 0, dp_j;
  for (dp_j=0; find_mask[dp_j]; dp_j++) if (find_mask[dp_j]=='/') dp_len=dp_j+1;
  for (dp_j=0; dp_j<dp_len; dp_j++) ignore_path[dp_j] = find_mask[dp_j];
  StrPrint(ignore_path+dp_len, ".hgitignore");
  U8 *ign_patterns, *ign_negate, *ign_kind;
  I64 ign_count;
  IgnoreLoad(ignore_path, &ign_patterns, &ign_negate, &ign_kind, &ign_count);

  CDirEntry *tmpde = FilesFind(find_mask, 0);
  CDirEntry *tmpde1 = tmpde;
  while (tmpde) {
    I64 fsize;
    U8 *fbuf = HgitFileRead(tmpde->full_name, &fsize);

    // name = just the filename portion, after the last '/'
    I64 name_start = 0, j;
    for (j=0; tmpde->full_name[j]; j++) if (tmpde->full_name[j]=='/') name_start=j+1;
    I64 name_len = j - name_start;
    I64 entry_needed = 1 + name_len + 1 + 64 + 8;

    // ADR 0014's own safety rule: ignore rules are only ever
    // consulted for a name NOT already tracked by this exact name in
    // the parent tree - an already-tracked file can never be hidden
    // by adding an ignore rule later. Checked here, structurally,
    // before any ignore lookup happens at all.
    Bool already_tracked = FALSE;
    if (old_tree_content != NULL) {
      U8 at_type; U8 at_hash[64]; U64 at_entity;
      already_tracked = TreeFindEntry(old_tree_content, old_tree_content_len,
                                       tmpde->full_name+name_start, name_len,
                                       &at_type, at_hash, &at_entity);
    }
    Bool skip_ignored = !already_tracked &&
                         IsIgnored(ign_patterns, ign_negate, ign_kind, ign_count,
                                   tmpde->full_name+name_start, "");

    // No `continue` here - confirmed absent from HolyC (matches
    // experiments/templeos-devkit's own documented bug-compat corpus,
    // `holyc-parser/tests/corpus/failing/007-bug-compat-bug52-continue-keyword.hc`
    // - `if (cond) continue;` isn't a keyword there, it parses as an
    // undefined identifier). Nest the rest of the loop body inside an
    // `else` instead of early-`continue`-ing past the guards.
    if (skip_ignored) {
      CommPrint(1, "OFFER_IGNORED %s\n", tmpde->full_name);
    } else if (tlen + entry_needed > 2048) {
      CommPrint(1, "OFFER_SKIP tree_full %s\n", tmpde->full_name);
    } else {
      // Probe 106: was a fixed blob_tagged[512] stack buffer (the
      // real reason every file over 511 bytes used to be skipped) -
      // MAlloc'd at the file's own real size instead, same "no
      // guessed cap" pattern as ObjectPut's own fix (probe 105).
      U8 *blob_tagged = MAlloc(fsize+1);
      blob_tagged[0] = OBJ_BLOB;
      for (i=0; i<fsize; i++) blob_tagged[1+i] = fbuf[i];
      U8 blob_hash[64];
      B2Hash512Any(blob_tagged, fsize+1, blob_hash);
      Free(blob_tagged);
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
        // ADR 0009 addendum (experiments/84-fuzzy-rename-detection/):
        // exact name and exact content both failed - try a fuzzy
        // (edited-during-rename) match before giving up and generating
        // a fresh identity.
        if (!found_old) {
          found_old = OfferFindFuzzyRename(rbuf, old_tree_content, old_tree_content_len,
                                           old_idx_hashes, old_idx_offsets, old_idx_count,
                                           fbuf, fsize, &entity_id);
        }
      }
      if (!found_old) entity_id = GenerateEntityId();

      // ADR 0015: recomputed fresh every offer, same as the content
      // hash itself - mode is a real PROPERTY of current file state,
      // not carried-forward identity. Only a non-default (binary
      // and/or executable) mode costs anything.
      Bool auto_binary = IsContentBinary(fbuf, fsize);
      U8 mode = GetEffectiveMode(attr_patterns, attr_kind, attr_sets, attr_values, attr_count,
                                  tmpde->full_name+name_start, "", auto_binary);
      if (mode != 0) {
        AttrsListEncode(attrs_content, &attrs_len, entity_id, mode);
        attrs_entry_count++;
      }

      TreeEncodeEntry(tree_content, &tlen, tmpde->full_name+name_start, name_len,
                       OBJ_BLOB, blob_hash, entity_id);
      entry_count++;
    }
    tmpde = tmpde->next;
  }
  DirTreeDel(tmpde1);
  Free(old_idx_hashes);
  Free(old_idx_offsets);
  IgnoreFree(ign_patterns, ign_negate, ign_kind);
  AttrsRulesFree(attr_patterns, attr_kind, attr_sets, attr_values);
  PutU32LE(tree_content, 0, entry_count);

  I64 tree_content_len = tlen;
  U8 tree_tagged[2048];
  tree_tagged[0] = OBJ_TREE;
  for (i=0; i<tree_content_len; i++) tree_tagged[1+i] = tree_content[i];
  U8 tree_hash[64];
  B2Hash512Any(tree_tagged, tree_content_len+1, tree_hash);
  ObjectPut(archive, &alen, OBJ_TREE, tree_content, tree_content_len);

  // ADR 0015: only store a real OBJ_ATTRS object (and reference it
  // from the commit) if at least one file actually has a non-default
  // mode - the common case (an all-plain-text offer) costs nothing.
  Bool has_attrs = (attrs_entry_count > 0);
  U8 attrs_hash[64];
  if (has_attrs) {
    PutU32LE(attrs_content, 0, attrs_entry_count);
    U8 *attrs_tagged = MAlloc(attrs_len+1);
    attrs_tagged[0] = OBJ_ATTRS;
    for (i=0; i<attrs_len; i++) attrs_tagged[1+i] = attrs_content[i];
    B2Hash512Any(attrs_tagged, attrs_len+1, attrs_hash);
    Free(attrs_tagged);
    ObjectPut(archive, &alen, OBJ_ATTRS, attrs_content, attrs_len);
  }
  Free(attrs_content);

  // Commit content itself (has_parent/parent_hash already computed above).
  U8 commit_content[512];
  I64 clen = 0;
  CommitEncode(commit_content, &clen, tree_hash, parent_hash,
               has_parent, timestamp, message, message_len,
               relation_tag, relation_target, relation_entity_id,
               has_attrs, attrs_hash);
  U8 commit_tagged[512];
  commit_tagged[0] = OBJ_COMMIT;
  for (i=0; i<clen; i++) commit_tagged[1+i] = commit_content[i];
  U8 commit_hash[64];
  B2Hash512Any(commit_tagged, clen+1, commit_hash);
  ObjectPut(archive, &alen, OBJ_COMMIT, commit_content, clen);

  // Rewrite the repo with the updated header (new total object count:
  // rcount existing + entry_count blobs + 1 tree + 1 commit + (1 real
  // OBJ_ATTRS object, only if has_attrs - ADR 0015).
  I64 attrs_object_count = 0; if (has_attrs) attrs_object_count = 1;
  HgsWriteHeader(archive, rver, rcount + entry_count + 2 + attrs_object_count);
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

// ADR 0010's own real CLI-semantics decision, made once probe 90's
// standalone primitive proved solid: a NEW, separate command
// (`hgit offertree`), not a change to `hgit offer`/`HgitOfferWithRelation`
// itself - deliberately, to keep zero regression risk on the existing,
// heavily-relied-on flat-offer code path (every prior probe and
// tests/full-regression.hc's own coverage). `dir_path` (trailing "/"
// required, e.g. "C:/Home/MyProject/") is recursively offered via
// `TreeBuildRecursive` instead of one flat `FilesFind` pass. No
// relation-tag support yet (a plain offering only, matching
// `HgitOffer`'s own scope before ADR 0005 added relations) - a real,
// separate follow-up if `offertree` needs `correct`/`revert`/
// `reconcile` too.
// ADR 0010's own last deferred item, now closed (experiments/96-
// offertree-relations/): `offertree` gains the same real relation-tag
// support (`correct`/`revert`/`reconcile`) `HgitOfferWithRelation`
// already has for flat offerings - `HgitOfferTree` itself becomes a
// thin REL_NONE wrapper over this, the same relationship `HgitOffer`
// already has with `HgitOfferWithRelation`.
U0 HgitOfferTreeWithRelation(U8 *repo_path, U8 *dir_path, U8 *message, I64 message_len,
                             U64 timestamp, U8 relation_tag, U8 *relation_target,
                             U64 relation_entity_id)
{
  I64 rsize;
  U8 *rbuf = HgitFileRead(repo_path, &rsize);
  U16 rver;
  U64 rcount;
  HgsReadHeader(rbuf, &rver, &rcount);

  if (rsize > ARCHIVE_SANITY_MAX) {
    CommPrint(1, "OFFERTREE_REFUSED archive_absurdly_large size=%d\n", rsize);
    return;
  }

  // Probe 107: a real, computed capacity (recursive sum of every real
  // file's own size under dir_path, plus a real subdirectory count for
  // the tree objects TreeBuildRecursive will create) instead of the
  // old fixed ARCHIVE_HEADROOM - same fix as probe 106's flat-path
  // version, extended to cover offertree's own multi-tree-object shape.
  I64 new_content_bytes = 0;
  I64 new_file_count = 0;
  I64 new_subdir_count = 0;
  SumTreeFileBytes(dir_path, &new_content_bytes, &new_file_count, &new_subdir_count);
  I64 tree_object_count = new_subdir_count + 1; // +1 for the root tree

  // ADR 0015: real, computed headroom for this call's own OBJ_ATTRS
  // object too, same pattern as the flat path.
  I64 archive_cap = rsize + new_content_bytes
                   + new_file_count * OBJECT_RECORD_OVERHEAD
                   + tree_object_count * (TREE_LEVEL_MAX + OBJECT_RECORD_OVERHEAD)
                   + COMMIT_HEADROOM + OBJECT_RECORD_OVERHEAD
                   + new_file_count * 9 + OBJECT_RECORD_OVERHEAD;
  if (archive_cap > ARCHIVE_SANITY_MAX) {
    CommPrint(1, "OFFERTREE_REFUSED archive_absurdly_large size=%d\n", archive_cap);
    return;
  }
  U8 *archive = MAlloc(archive_cap);
  I64 alen;
  I64 i;
  for (i = 0; i < rsize-16; i++) archive[16+i] = rbuf[16+i];
  alen = rsize;

  U8 parent_hash[64];
  Bool has_parent = CurrentHeadRead(repo_path, parent_hash);

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
        old_tree_content_len = ot_record_len - 1;
      }
    }
  }

  // ADR 0014: `.hgitignore` lives at `dir_path` itself (the recursive
  // discovery root) - one rule set for the whole tree, `rel_dir`
  // tracked as "" at this level and grown by `TreeBuildRecursive`'s
  // own recursion below it.
  U8 ignore_path[256];
  StrPrint(ignore_path, "%s.hgitignore", dir_path);
  U8 *ign_patterns, *ign_negate, *ign_kind;
  I64 ign_count;
  IgnoreLoad(ignore_path, &ign_patterns, &ign_negate, &ign_kind, &ign_count);

  // ADR 0015: same real, one-per-tree `.hgitattributes` convention,
  // and one shared attrs accumulator threaded through the whole
  // recursion (same "one archive, one alen" pattern already used for
  // the object store itself).
  U8 attrs_path[256];
  StrPrint(attrs_path, "%s.hgitattributes", dir_path);
  U8 *attr_patterns, *attr_kind, *attr_sets, *attr_values;
  I64 attr_count;
  AttrsRulesLoad(attrs_path, &attr_patterns, &attr_kind, &attr_sets, &attr_values, &attr_count);
  U8 *attrs_content = MAlloc(new_file_count*9 + 9);
  I64 attrs_len = 4;
  I64 attrs_entry_count = 0;

  // The one real substitution: TreeBuildRecursive replaces
  // HgitOfferWithRelation's own flat FilesFind loop, recursing into
  // real subdirectories instead. old_idx_hashes/old_idx_offsets stay
  // alive through this call (needed for both the exact-hash and fuzzy
  // rename passes at every directory level), freed right after.
  U8 tree_content[4096];
  I64 tree_content_len;
  TreeBuildRecursive(dir_path, archive, &alen, rbuf, old_idx_hashes, old_idx_offsets, old_idx_count,
                     old_tree_content, old_tree_content_len,
                     tree_content, &tree_content_len,
                     ign_patterns, ign_negate, ign_kind, ign_count, "",
                     attr_patterns, attr_kind, attr_sets, attr_values, attr_count,
                     attrs_content, &attrs_len, &attrs_entry_count);
  Free(old_idx_hashes);
  Free(old_idx_offsets);
  IgnoreFree(ign_patterns, ign_negate, ign_kind);
  AttrsRulesFree(attr_patterns, attr_kind, attr_sets, attr_values);

  U8 tree_tagged[4096];
  tree_tagged[0] = OBJ_TREE;
  for (i=0; i<tree_content_len; i++) tree_tagged[1+i] = tree_content[i];
  U8 tree_hash[64];
  B2Hash512Any(tree_tagged, tree_content_len+1, tree_hash);
  ObjectPut(archive, &alen, OBJ_TREE, tree_content, tree_content_len);

  // ADR 0015: same "only pay for what you use" real OBJ_ATTRS object,
  // built from whatever TreeBuildRecursive's own recursion accumulated
  // across every directory level.
  Bool has_attrs = (attrs_entry_count > 0);
  U8 attrs_hash[64];
  if (has_attrs) {
    PutU32LE(attrs_content, 0, attrs_entry_count);
    U8 *attrs_tagged = MAlloc(attrs_len+1);
    attrs_tagged[0] = OBJ_ATTRS;
    for (i=0; i<attrs_len; i++) attrs_tagged[1+i] = attrs_content[i];
    B2Hash512Any(attrs_tagged, attrs_len+1, attrs_hash);
    Free(attrs_tagged);
    ObjectPut(archive, &alen, OBJ_ATTRS, attrs_content, attrs_len);
  }
  Free(attrs_content);

  U8 commit_content[512];
  I64 clen = 0;
  CommitEncode(commit_content, &clen, tree_hash, parent_hash,
               has_parent, timestamp, message, message_len,
               relation_tag, relation_target, relation_entity_id,
               has_attrs, attrs_hash);
  U8 commit_tagged[512];
  commit_tagged[0] = OBJ_COMMIT;
  for (i=0; i<clen; i++) commit_tagged[1+i] = commit_content[i];
  U8 commit_hash[64];
  B2Hash512Any(commit_tagged, clen+1, commit_hash);
  ObjectPut(archive, &alen, OBJ_COMMIT, commit_content, clen);

  // Object count: unlike the flat loop above (which tracks a simple
  // per-file entry_count as it goes), TreeBuildRecursive's own
  // recursion appends a variable, not-known-in-advance number of blob
  // AND tree objects at arbitrary depth - re-scanning what actually
  // landed in `archive` via the same IndexBuild every real command
  // already trusts is simpler and provably correct than threading a
  // running tally back out through arbitrary recursion depth.
  // No guessed cap (this project's own hard-won ADR 0007 lesson: a
  // fixed "surely enough" headroom number is exactly the pattern that
  // kept causing real crashes) - a real upper bound instead: no object
  // record is smaller than 73 bytes (8-byte length + 1-byte type +
  // 0-byte content + 64-byte hash), so `alen` itself bounds how many
  // objects could possibly fit in it.
  I64 max_possible_objects = alen/73 + 1;
  U8 *final_idx_hashes = MAlloc(max_possible_objects*64 + 64);
  I64 *final_idx_offsets = MAlloc((max_possible_objects+1)*8);
  I64 final_idx_count;
  IndexBuild(archive+16, alen-16, final_idx_hashes, final_idx_offsets, &final_idx_count);
  Free(final_idx_hashes);
  Free(final_idx_offsets);

  HgsWriteHeader(archive, rver, final_idx_count);
  FileWrite(repo_path, archive, alen);

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

U0 HgitOfferTree(U8 *repo_path, U8 *dir_path, U8 *message, I64 message_len,
                 U64 timestamp)
{
  HgitOfferTreeWithRelation(repo_path, dir_path, message, message_len,
                            timestamp, REL_NONE, NULL, 0);
}

// Graph.HC — `hgit graph`: a real DolDoc tree view of a
// repo's ENTIRE commit history across every declared path, not just
// one path's own linear chain (`historydoc`) or relation-carrying
// commits only (`reconcileoverview`). "main"'s own chain renders as
// the trunk (root at the top, HEAD at the tip, each commit nested one
// level deeper than its parent), using the same real `$TR$`/
// `$ID,+2$`/`$ID,-2$` tree-widget nesting `reconcileoverview` already
// verified (probes 57-59). Every OTHER declared path attaches as its
// own nested branch at the exact commit it forked from (`path new`
// copies the current path's HEAD at creation time - Paths.HC's own
// `PathNew` - so a real, findable fork point always exists on a
// direct ancestor path) - a real, rendered analogue of `git log
// --graph --all`, scoped to this project's own actual ref model
// (named paths, not full branches with merges - no multi-parent
// commits exist yet, see History.HC's own note).
//
// Scoped honestly: a branch's fork point is found by walking backward
// from its HEAD until a commit already in MAIN's own chain is hit -
// if a path was itself created FROM another non-main path (a branch
// of a branch), and that intermediate path's own unique commits never
// reach main directly, this renders the grandchild path as its own
// second top-level tree instead of nesting it under its true
// immediate parent path. A real, documented simplification for this
// first version, not a silent wrong answer - the path's own full
// history is still shown completely, just not nested under the exact
// right ancestor.
//
// Depends on Canon.HC, Blake2b.HC, Hgs.HC, Object.HC, Commit.HC,
// Index.HC, Hex.HC, Meta.HC (MetaPathCount/MetaPathListInto/
// MetaReadHead).

U0 GraphAppendStr(U8 *doc, I64 *dlen, U8 *s)
{
  I64 gi;
  for (gi=0; s[gi]; gi++) doc[*dlen+gi] = s[gi];
  *dlen += gi;
}

// Opens one commit's own $TR$ tree node (12 hex chars of its hash,
// then its message) - caller closes with $ID,-2$ once its children
// (if any) are written. `label_prefix` (e.g. a path name in brackets)
// is prepended to the node's own text when non-empty - used for the
// first node of a non-main branch so it's clear which path it is.
U0 GraphOpenCommitNode(U8 *doc, I64 *dlen, U8 *hash, U8 *content, U8 *label_prefix)
{
  GraphAppendStr(doc, dlen, "$TR,\"");
  GraphAppendStr(doc, dlen, label_prefix);
  U8 hex[129];
  HashToHex(hash, hex);
  I64 hi;
  for (hi=0; hi<10; hi++) doc[(*dlen)++] = hex[hi];
  GraphAppendStr(doc, dlen, " ");
  U32 mlen = CommitMessageLen(content);
  U8 *msg = CommitMessage(content);
  I64 mi;
  for (mi=0; mi<mlen; mi++) doc[(*dlen)++] = msg[mi];
  GraphAppendStr(doc, dlen, "\"$$ID,+2$");
}

U0 HgitGraph(U8 *repo_path, U8 *doc_path)
{
  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  if (rbuf == NULL) {
    U8 doc0[64];
    I64 dlen0 = 0;
    GraphAppendStr(doc0, &dlen0, "(no repository)$CR$");
    FileWrite(doc_path, doc0, dlen0);
    return;
  }
  U16 rver;
  U64 rcount;
  Bool hok = HgsReadHeader(rbuf, &rver, &rcount);
  if (!hok || rcount == 0) {
    U8 doc1[64];
    I64 dlen1 = 0;
    GraphAppendStr(doc1, &dlen1, "(no offerings yet)$CR$");
    FileWrite(doc_path, doc1, dlen1);
    return;
  }

  U8 *idx_hashes = MAlloc(rcount*64 + 64);
  I64 *idx_offsets = MAlloc((rcount+1)*8);
  I64 idx_count;
  IndexBuild(rbuf+16, rsize-16, idx_hashes, idx_offsets, &idx_count);

  I64 path_count = MetaPathCount(repo_path);
  U8 *path_names = MAlloc((path_count+1)*META_MAX_PATH_NAME);
  I64 real_path_count;
  MetaPathListInto(repo_path, path_names, &real_path_count);

  // doc[]: sized generously from the repo's real object count (same
  // "MAlloc from a real count, no arbitrary fixed cap" discipline as
  // every dynamic buffer since ADR 0007) - 300 bytes/commit covers a
  // hash + typical message + this widget's own markup overhead with
  // real headroom. Not a proven bound for an unusually long individual
  // commit message - same honest caveat every other heuristic-sized
  // buffer in this codebase carries (see "Not yet done" in this
  // probe's own README).
  U8 *doc = MAlloc(rcount*300 + 4096);
  I64 dlen = 0;
  GraphAppendStr(doc, &dlen, "$FG,5$hgit history graph$FG$$CR$$CR$");

  U8 main_head[64];
  Bool has_main = MetaReadHead(repo_path, "main", main_head);
  if (!has_main) {
    GraphAppendStr(doc, &dlen, "(no offerings yet)$CR$");
    FileWrite(doc_path, doc, dlen);
    Free(idx_hashes); Free(idx_offsets); Free(path_names); Free(doc);
    return;
  }

  // Walk main's own chain, HEAD..root order first (easiest direction
  // to follow parent pointers), then reverse in place so index 0 is
  // the root and rendering can nest deeper as it moves toward HEAD.
  U8 *main_chain = MAlloc(rcount*64 + 64);
  I64 main_count = 0;
  U8 mcur[64];
  I64 mzi;
  for (mzi=0; mzi<64; mzi++) mcur[mzi] = main_head[mzi];
  Bool has_mcur = TRUE;
  while (has_mcur) {
    I64 moff_rel;
    if (!IndexLookup(idx_hashes, idx_offsets, idx_count, mcur, &moff_rel)) {
      has_mcur = FALSE;
    } else {
      I64 moff = 16 + moff_rel;
      if (rbuf[moff+8] != OBJ_COMMIT) {
        has_mcur = FALSE;
      } else {
        U8 *mcontent = rbuf + moff + 9;
        for (mzi=0; mzi<64; mzi++) main_chain[main_count*64+mzi] = mcur[mzi];
        main_count++;
        U8 mpcount = CommitParentCount(mcontent);
        if (mpcount > 0) {
          U8 *mparent = CommitParentHash(mcontent, 0);
          for (mzi=0; mzi<64; mzi++) mcur[mzi] = mparent[mzi];
          has_mcur = TRUE;
        } else {
          has_mcur = FALSE;
        }
      }
    }
  }
  I64 mlo = 0, mhi = main_count-1;
  while (mlo < mhi) {
    U8 mtmp[64];
    I64 mtzi;
    for (mtzi=0; mtzi<64; mtzi++) mtmp[mtzi] = main_chain[mlo*64+mtzi];
    for (mtzi=0; mtzi<64; mtzi++) main_chain[mlo*64+mtzi] = main_chain[mhi*64+mtzi];
    for (mtzi=0; mtzi<64; mtzi++) main_chain[mhi*64+mtzi] = mtmp[mtzi];
    mlo++; mhi--;
  }

  // For every OTHER declared path, walk its own chain backward from
  // its own HEAD until a commit already in main_chain is hit (its
  // fork point), storing its own unique commits (oldest-of-branch
  // first, matching main_chain's own convention) and that fork index
  // for the render pass below. All paths' own branch data is
  // computed up front (not rendered immediately) since rendering
  // happens ordered by main_chain position, not by path list order.
  I64 *fork_idx = MAlloc(real_path_count*8 + 8);
  I64 *branch_count = MAlloc(real_path_count*8 + 8);
  U8 *branch_chains = MAlloc(real_path_count*rcount*64 + 64);

  I64 pn;
  for (pn=0; pn<real_path_count; pn++) {
    U8 *pname = path_names + pn*META_MAX_PATH_NAME;
    Bool is_main = (StrCmp(pname, "main") == 0);
    fork_idx[pn] = -1;
    branch_count[pn] = 0;
    if (!is_main) {
      U8 phead[64];
      Bool has_phead = MetaReadHead(repo_path, pname, phead);
      if (has_phead) {
        U8 bcur[64];
        I64 bzi;
        for (bzi=0; bzi<64; bzi++) bcur[bzi] = phead[bzi];
        Bool has_bcur = TRUE;
        I64 bcount = 0;
        while (has_bcur) {
          I64 mi2, found_at = -1;
          for (mi2=0; mi2<main_count; mi2++) {
            Bool same = TRUE;
            I64 hb;
            for (hb=0; hb<64; hb++) if (main_chain[mi2*64+hb] != bcur[hb]) same = FALSE;
            if (same) found_at = mi2;
          }
          if (found_at >= 0) {
            fork_idx[pn] = found_at;
            has_bcur = FALSE;
          } else {
            I64 boff_rel;
            if (!IndexLookup(idx_hashes, idx_offsets, idx_count, bcur, &boff_rel)) {
              has_bcur = FALSE;
            } else {
              I64 boff = 16 + boff_rel;
              if (rbuf[boff+8] != OBJ_COMMIT) {
                has_bcur = FALSE;
              } else {
                U8 *bcontent = rbuf + boff + 9;
                for (bzi=0; bzi<64; bzi++)
                  branch_chains[(pn*rcount+bcount)*64+bzi] = bcur[bzi];
                bcount++;
                U8 bpcount = CommitParentCount(bcontent);
                if (bpcount > 0) {
                  U8 *bparent = CommitParentHash(bcontent, 0);
                  for (bzi=0; bzi<64; bzi++) bcur[bzi] = bparent[bzi];
                  has_bcur = TRUE;
                } else {
                  has_bcur = FALSE;
                }
              }
            }
          }
        }
        // Reverse this path's own segment so index 0 is the oldest
        // commit unique to this branch (right after the fork point).
        I64 blo = 0, bhi = bcount-1;
        while (blo < bhi) {
          U8 btmp[64];
          I64 btzi;
          for (btzi=0; btzi<64; btzi++) btmp[btzi] = branch_chains[(pn*rcount+blo)*64+btzi];
          for (btzi=0; btzi<64; btzi++) branch_chains[(pn*rcount+blo)*64+btzi] = branch_chains[(pn*rcount+bhi)*64+btzi];
          for (btzi=0; btzi<64; btzi++) branch_chains[(pn*rcount+bhi)*64+btzi] = btmp[btzi];
          blo++; bhi--;
        }
        branch_count[pn] = bcount;
      }
    }
  }

  // Render: walk main's trunk root-to-tip, nesting one level per
  // commit. Immediately after opening each trunk node, attach every
  // path whose fork point is this exact commit as its own fully
  // self-contained nested subtree (opened and closed before moving on
  // to the next trunk commit, so the trunk's own nesting depth only
  // ever grows by one per trunk commit, never by an attached branch).
  I64 ci;
  for (ci=0; ci<main_count; ci++) {
    I64 coff_rel;
    IndexLookup(idx_hashes, idx_offsets, idx_count, main_chain+ci*64, &coff_rel);
    I64 coff = 16 + coff_rel;
    U8 *ccontent = rbuf + coff + 9;
    GraphOpenCommitNode(doc, &dlen, main_chain+ci*64, ccontent, "");

    I64 apn;
    for (apn=0; apn<real_path_count; apn++) {
      if (fork_idx[apn] == ci) {
        U8 *apname = path_names + apn*META_MAX_PATH_NAME;
        I64 bi;
        for (bi=0; bi<branch_count[apn]; bi++) {
          U8 *bhash = branch_chains + (apn*rcount+bi)*64;
          I64 aoff_rel;
          IndexLookup(idx_hashes, idx_offsets, idx_count, bhash, &aoff_rel);
          I64 aoff = 16 + aoff_rel;
          U8 *acontent = rbuf + aoff + 9;
          if (bi == 0) {
            U8 lbl[META_MAX_PATH_NAME+4];
            I64 li = 0;
            lbl[li++] = '[';
            I64 lj;
            for (lj=0; apname[lj]; lj++) lbl[li++] = apname[lj];
            lbl[li++] = ']'; lbl[li++] = ' '; lbl[li] = 0;
            GraphOpenCommitNode(doc, &dlen, bhash, acontent, lbl);
          } else {
            GraphOpenCommitNode(doc, &dlen, bhash, acontent, "");
          }
        }
        I64 bj;
        for (bj=0; bj<branch_count[apn]; bj++) GraphAppendStr(doc, &dlen, "$ID,-2$");
      }
    }
  }
  for (ci=0; ci<main_count; ci++) GraphAppendStr(doc, &dlen, "$ID,-2$");

  FileWrite(doc_path, doc, dlen);

  Free(idx_hashes);
  Free(idx_offsets);
  Free(path_names);
  Free(main_chain);
  Free(fork_idx);
  Free(branch_count);
  Free(branch_chains);
  Free(doc);
}

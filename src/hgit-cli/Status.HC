// Status.HC — `hgit status`, scoped honestly to what's actually
// well-defined right now.
//
// hgit has no ref/HEAD concept yet (no way to name "the current
// offering" a repo is at) - so "what changed since the last offering"
// isn't answerable in general yet. What IS well-defined: a repository
// with zero objects has no prior offering to compare against by
// definition, so every working-directory file is untracked. That case
// is implemented and verified (experiments/16-hgit-status/); the
// general case prints an honest "not implemented yet" rather than
// guessing or silently producing wrong output.
//
// Depends on Canon.HC, Blake2b.HC, Hgs.HC (HgsReadHeader) and
// WorkDir.HC (WorkDirList).

U0 HgitStatus(U8 *repo_path)
{
  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  if (rbuf == NULL) {
    CommPrint(1, "STATUS_ERR not_a_repository %s\n", repo_path);
    return;
  }
  U16 rver;
  U64 rcount;
  Bool hok = HgsReadHeader(rbuf, &rver, &rcount);
  if (!hok) {
    CommPrint(1, "STATUS_ERR bad_header %s\n", repo_path);
    return;
  }
  if (rcount == 0) {
    CommPrint(1, "STATUS_NO_OFFERINGS_YET\n");
    WorkDirList();
  } else {
    CommPrint(1, "STATUS_UNIMPLEMENTED objects=%d\n", rcount);
  }
}

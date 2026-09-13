// Check.HC — `hgit check`: verify every object in a repo's own
// archive really hashes to what it claims to.
//
// The original brief's command list included a "shrine check" - a
// repo-integrity verification command - that was never wired in as
// M1's command surface grew (`init`/`status`/`offer`/`history`/`see`,
// then M2/M3/M4's own additions). `Archive.HC`'s `ArchiveVerify`
// (built and verified in M0, `experiments/05-tiny-archive/`) already
// does exactly this work - recompute each stored record's hash and
// compare - and its record shape (`[U64 length][data][64-byte hash]`)
// is identical to what `Hgs.HC`'s `HgsPut`/`Object.HC`'s `ObjectPut`
// actually write for every real object in a real `.hgs` file (the
// type tag is just the first byte of `data`, transparent to
// `ArchiveVerify`'s own hash recomputation). So this is a thin wrapper
// over already-tested M0 code, not new hashing/verification logic.
//
// Depends on Canon.HC, Blake2b.HC, Archive.HC, Hgs.HC.

U0 HgitCheck(U8 *repo_path)
{
  I64 rsize;
  U8 *rbuf = FileRead(repo_path, &rsize);
  if (rbuf == NULL) { CommPrint(1, "CHECK_ERR not_a_repository\n"); return; }
  U16 rver;
  U64 rcount;
  Bool hok = HgsReadHeader(rbuf, &rver, &rcount);
  if (!hok) { CommPrint(1, "CHECK_ERR bad_header\n"); return; }

  I64 total, ok;
  ArchiveVerify(rbuf+16, rsize-16, &total, &ok);

  if (total != rcount) {
    CommPrint(1, "CHECK_WARN object_count_mismatch header=%d scanned=%d\n",
              rcount, total);
  }
  if (ok == total) {
    CommPrint(1, "CHECK_OK objects=%d\n", total);
  } else {
    CommPrint(1, "CHECK_FAIL objects=%d ok=%d corrupt=%d\n", total, ok, total-ok);
  }
}

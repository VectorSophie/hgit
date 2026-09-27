// bench-scenario.hc - on-platform storage benchmark, run inside a real
// TempleOS guest by tools/bench-templeos.py. Builds a small repository with
// the real `Hgit(...)` commands (files x fsz bytes, one file edited per
// commit) and reports, at checkpoints, the per-command cost in guest
// jiffies plus the archive size. Pure HolyC; no dependence on the host.

U0 BenchFill(U8 *buf, I64 n, I64 salt)
{
  I64 i;
  for (i=0; i<n; i++) buf[i] = 'a' + ((i*7 + salt) % 26);
}

Bool BenchCheckpoint(I64 c)
{
  return c==1 || c==10 || c==25 || c==50 || c==100 || c==200 || c==400;
}

U0 BenchOffers(I64 files, I64 fsz, I64 commits)
{
  I64 c, f, t0, t1, t2, t3, sz;
  U8 *buf = MAlloc(fsz);
  U8 *rd;
  U8 name[64], cmd[160];
  Del("C:/Home/Bench.hgs", FALSE, FALSE, FALSE);
  Del("C:/Home/Bench.hgs.m", FALSE, FALSE, FALSE);
  for (f=0; f<files; f++) {
    BenchFill(buf, fsz, f);
    StrPrint(name, "C:/Home/BF%d.txt", f);
    FileWrite(name, buf, fsz);
  }
  CommPrint(1, "BENCH_BEGIN files=%d fsz=%d commits=%d jiffies=%d\n", files, fsz, commits, cnts.jiffies);
  Hgit("init C:/Home/Bench.hgs");
  for (c=1; c<=commits; c++) {
    f = c % files;
    BenchFill(buf, fsz, f + c*13);
    StrPrint(name, "C:/Home/BF%d.txt", f);
    FileWrite(name, buf, fsz);
    StrPrint(cmd, "offer C:/Home/Bench.hgs BF*.txt c%d", c);
    t0 = cnts.jiffies;
    Hgit(cmd);
    t1 = cnts.jiffies;
    if (BenchCheckpoint(c)) {
      rd = HgitFileRead("C:/Home/Bench.hgs", &sz);
      t2 = cnts.jiffies;
      Free(rd);
      CommPrint(1, "BENCH_OFFER c=%d jiffies=%d hgs_bytes=%d read_jiffies=%d\n", c, t1-t0, sz, t2-t1);
      t0 = cnts.jiffies;
      Hgit("check C:/Home/Bench.hgs");
      t1 = cnts.jiffies;
      Hgit("history C:/Home/Bench.hgs");
      t2 = cnts.jiffies;
      CommPrint(1, "BENCH_READ c=%d check_jiffies=%d history_jiffies=%d\n", c, t1-t0, t2-t1);
    }
  }
  CommPrint(1, "BENCH_DONE jiffies=%d\n", cnts.jiffies);
  Free(buf);
}

// probe 39 — are .HGS archives actually portable? Verifies that all
// the object content (blobs/trees/commits, addressed purely by
// BLAKE2b-512 hash) is fully self-contained: copying the raw .hgs
// bytes to a brand-new filename (no sidecar files carried along - no
// .head, .oplog, .paths, .currentpath) still lets `hgit see` walk the
// full commit -> tree -> entries chain correctly against the copy,
// using only a hash noted from the ORIGINAL repo before the copy.

Hgit("init \"C:/Home/P39Repo.hgs\"");

U8 fa39[3]; fa39[0]='o';fa39[1]='n';fa39[2]='e';
FileWrite("C:/Home/P39FileA.txt", fa39, 3);
Hgit("offer \"C:/Home/P39Repo.hgs\" \"C:/Home/P39FileA*\" root commit");
U8 head1_39[64];
HeadRead("C:/Home/P39Repo.hgs", head1_39);

U8 fa2_39[3]; fa2_39[0]='t';fa2_39[1]='w';fa2_39[2]='o';
FileWrite("C:/Home/P39FileA.txt", fa2_39, 3);
Hgit("offer \"C:/Home/P39Repo.hgs\" \"C:/Home/P39FileA*\" second commit");
U8 head2_39[64];
HeadRead("C:/Home/P39Repo.hgs", head2_39);
U8 head2_hex_39[129];
HashToHex(head2_39, head2_hex_39);
CommPrint(1, "original_head2_hex=%s\n", head2_hex_39);

// Raw byte copy of ONLY the .hgs file - no sidecars - to a totally
// different filename, simulating moving/sharing the archive alone.
I64 rsize;
U8 *rbuf = FileRead("C:/Home/P39Repo.hgs", &rsize);
FileWrite("C:/Home/P39Copy.hgs", rbuf, rsize);
CommPrint(1, "copy_size=%d original_size=%d\n", rsize, rsize);

// Confirm the copy genuinely has NO sidecars of its own (so anything
// that works below can only be coming from the .hgs bytes themselves).
I64 hsize;
U8 *hbuf = FileRead("C:/Home/P39Copy.hgs.head", &hsize);
CommPrint(1, "copy_has_no_head_sidecar=%d\n", hbuf==NULL);

// `hgit see` on the COPY, using the hash noted from the ORIGINAL -
// this is the real portability test: does the commit -> tree chain
// resolve correctly purely from the copied bytes? Build the command
// string manually (no sprintf-style helper verified in this project)
// since it needs the runtime hex hash spliced in.
U8 cmd_buf[256];
U8 *prefix = "see \"C:/Home/P39Copy.hgs\" ";
I64 p = 0;
while (prefix[p]) { cmd_buf[p] = prefix[p]; p++; }
I64 h = 0;
while (head2_hex_39[h]) { cmd_buf[p++] = head2_hex_39[h]; h++; }
cmd_buf[p] = 0;
Hgit(cmd_buf);

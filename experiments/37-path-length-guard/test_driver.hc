// probe 37 — PathNew now proactively refuses a path name whose own
// sidecar files would cross probe 36's real 33-char full-path ceiling,
// instead of silently "succeeding" while creating something that can
// never actually be read back. Uses a short repo path (this test's
// own name padding is what pushes the total over/under the limit) so
// the boundary is exercised deliberately, not by accident.

// "C:/Home/P37.hgs" is 15 chars. + ".head." (6 chars) + name must be
// <= 33 total (probe 36's real ceiling) to be accepted: 15+6+name<=33
// means name<=12 fits, name=13 must be refused (total would be 34).

Hgit("init \"C:/Home/P37.hgs\"");

// exactly at the boundary (12 chars, total 33): must be accepted.
Bool fits_ok = PathNew("C:/Home/P37.hgs", "aaaaaaaaaaaa");
CommPrint(1, "fits_ok=%d (expect 1)\n", fits_ok);

// one character too many (13 chars, total 34): must be refused, not
// silently "succeed" into an unreadable file.
Bool overflow_refused = !PathNew("C:/Home/P37.hgs", "bbbbbbbbbbbbb");
CommPrint(1, "overflow_refused=%d (expect 1)\n", overflow_refused);

// double-check the refused one didn't actually get into the path list
// or leave a real (but unreadable) head file behind.
Bool overflow_not_listed = !PathExists("C:/Home/P37.hgs", "bbbbbbbbbbbbb");
CommPrint(1, "overflow_not_listed=%d (expect 1)\n", overflow_not_listed);

if (fits_ok && overflow_refused && overflow_not_listed)
  CommPrint(1, "PASS path_length_guard\n");
else
  CommPrint(1, "FAIL path_length_guard\n");

// probe 33 — `hgit operation history`, through the real Hgit(cmdline)
// dispatcher, including its two-word command parsing ("operation
// history <repo>").

Hgit("init \"C:/Home/P33Repo.hgs\"");

// history on a repo with zero operations logged yet.
Hgit("operation history \"C:/Home/P33Repo.hgs\"");

U8 fa33[3]; fa33[0]='o';fa33[1]='n';fa33[2]='e';
FileWrite("C:/Home/P33FileA.txt", fa33, 3);
Hgit("offer \"C:/Home/P33Repo.hgs\" \"C:/Home/P33FileA*\" first offer");
U8 head1_33[64];
HeadRead("C:/Home/P33Repo.hgs", head1_33);
U8 head1_hex_33[129];
HashToHex(head1_33, head1_hex_33);

U8 fa2_33[3]; fa2_33[0]='t';fa2_33[1]='w';fa2_33[2]='o';
FileWrite("C:/Home/P33FileA.txt", fa2_33, 3);
Hgit("offer \"C:/Home/P33Repo.hgs\" \"C:/Home/P33FileA*\" second offer");
U8 head2_33[64];
HeadRead("C:/Home/P33Repo.hgs", head2_33);
U8 head2_hex_33[129];
HashToHex(head2_33, head2_hex_33);

CommPrint(1, "expected_new1=%s\n", head1_hex_33);
CommPrint(1, "expected_new2=%s\n", head2_hex_33);

// history after two real offers, via the dispatcher's two-word parsing.
Hgit("operation history \"C:/Home/P33Repo.hgs\"");

// also an unknown sub-command should report an error, not silently
// do nothing or crash.
Hgit("operation bogus \"C:/Home/P33Repo.hgs\"");

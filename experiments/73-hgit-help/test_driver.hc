// Probe 73 test driver: hgit help / bare hgit / unknown command.
U0 P73HelpTest()
{
  CommPrint(1, "P73_HELP_EXPLICIT_BEGIN\n");
  Hgit("help");
  CommPrint(1, "P73_HELP_EXPLICIT_END\n");

  CommPrint(1, "P73_HELP_BARE_BEGIN\n");
  Hgit("");
  CommPrint(1, "P73_HELP_BARE_END\n");

  CommPrint(1, "P73_UNKNOWN_BEGIN\n");
  Hgit("notarealcommand C:/Home/Whatever");
  CommPrint(1, "P73_UNKNOWN_END\n");

  CommPrint(1, "PASS p73_help_test\n");
}
P73HelpTest;

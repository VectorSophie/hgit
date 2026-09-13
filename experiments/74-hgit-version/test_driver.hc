// Probe 74 test driver: hgit version + version line in hgit help.
U0 P74VersionTest()
{
  CommPrint(1, "P74_VERSION_BEGIN\n");
  Hgit("version");
  CommPrint(1, "P74_VERSION_END\n");

  CommPrint(1, "P74_HELP_VERSION_LINE_BEGIN\n");
  Hgit("help");
  CommPrint(1, "P74_HELP_VERSION_LINE_END\n");

  CommPrint(1, "PASS p74_version_test\n");
}
P74VersionTest;

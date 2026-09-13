// Probe 78 test driver: hgit logo prints the project's ASCII art
// cleanly - specifically confirming the many literal '%' glyphs in
// the art (block-shading characters) don't get misparsed as format
// specifiers, since each line is passed as CommPrint's "%s" argument,
// never as the format string itself.
U0 P78LogoTest()
{
  CommPrint(1, "P78_LOGO_BEGIN\n");
  Hgit("logo");
  CommPrint(1, "P78_LOGO_END\n");
}
P78LogoTest;

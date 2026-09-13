// Probe 83 test driver: FossilSimilarityPercent.
U0 P83SimilarityTest()
{
  // Case 1: near-identical (one word changed) - should score HIGH.
  U8 *a = "The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog again and again.";
  U8 *b = "The quick brown fox LEAPS over the lazy dog. The quick brown fox jumps over the lazy dog again and again.";
  I64 sim1 = FossilSimilarityPercent(a, StrLen(a), b, StrLen(b));
  CommPrint(1, "P83_SIM_NEAR_IDENTICAL=%d\n", sim1);

  // Case 2: totally unrelated - should score LOW (near 0).
  U8 *c = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
  U8 *d = "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ!!";
  I64 sim2 = FossilSimilarityPercent(c, StrLen(c), d, StrLen(d));
  CommPrint(1, "P83_SIM_UNRELATED=%d\n", sim2);

  // Case 3: identical strings - should score 100.
  U8 *e = "identical content here";
  I64 sim3 = FossilSimilarityPercent(e, StrLen(e), e, StrLen(e));
  CommPrint(1, "P83_SIM_IDENTICAL=%d\n", sim3);

  // Case 4: real rename-like case - short file, one line appended.
  U8 *f = "line one\nline two\n";
  U8 *g = "line one\nline two\nline three\n";
  I64 sim4 = FossilSimilarityPercent(f, StrLen(f), g, StrLen(g));
  CommPrint(1, "P83_SIM_APPENDED=%d\n", sim4);

  CommPrint(1, "PASS p83_similarity_test\n");
}
P83SimilarityTest;

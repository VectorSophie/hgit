U0 P68LIdxTest()
{
  U8 *s4 = "ABCD";
  I64 zero = 0;
  U64 a = s4[zero](U64);        // index via variable
  CommPrint(1, "via_variable_index=%d (expect 65)\n", a);

  U64 b = s4[0+0](U64);         // index via expression
  CommPrint(1, "via_expr_index=%d (expect 65)\n", b);

  U64 c = (s4[0])(U64);         // explicit parens around index
  CommPrint(1, "via_explicit_parens=%d (expect 65)\n", c);

  U64 d = s4[0](U64);           // bare literal index (the failing case)
  CommPrint(1, "via_bare_literal=%d (expect 65)\n", d);

  CommPrint(1,"PASS p68l_idxtest\n");
}
P68LIdxTest;

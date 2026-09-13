// probe 48 step 1 — is RandU32 a real, usable source of distinct
// random values on real TempleOS? Confirmed from primary source
// (cia-foundation/TempleOS: Kernel/BlkDev/FileSysFAT.HC uses
// `br->serial_num=RandU32;` for a real filesystem serial number,
// Demo/RandDemo.HC uses it for random pixel plotting) - this verifies
// it empirically, matching this project's "verify then trust" rule.

U0 RandProbe()
{
  U32 a = RandU32;
  U32 b = RandU32;
  U32 c = RandU32;
  CommPrint(1, "a=%u b=%u c=%u\n", a, b, c);
  Bool all_distinct = (a!=b) && (b!=c) && (a!=c);
  CommPrint(1, "all_distinct=%d\n", all_distinct);
}
RandProbe();

// Probe 105 test driver: ObjectPut's own scratch buffer, MAlloc'd
// instead of a fixed tagged[4096] stack array, verified past the old
// 4095-byte ceiling with a real 10,000-byte object.
U0 P105ObjectPutDynamicTagTest()
{
  I64 content_len = 10000;
  U8 *content = MAlloc(content_len);
  I64 i;
  // Not a uniform fill - a real varying pattern, so a truncated or
  // corrupted copy would actually change the hash, not accidentally
  // still match.
  for (i=0; i<content_len; i++) content[i] = (i*7 + 3) & 0xFF;

  U8 *archive = MAlloc(content_len + 200);
  I64 alen = 0;
  I64 obj_start = alen;
  ObjectPut(archive, &alen, OBJ_BLOB, content, content_len);

  CommPrint(1, "P105_TYPE=%d\n", ObjectPeekType(archive, obj_start));

  I64 total, ok;
  ArchiveVerify(archive, alen, &total, &ok);
  CommPrint(1, "P105_TOTAL=%d OK=%d\n", total, ok);

  if (ObjectPeekType(archive, obj_start) == OBJ_BLOB && total == 1 && ok == 1) {
    CommPrint(1, "PASS p105_objectput_dynamic_tag\n");
  } else {
    CommPrint(1, "FAIL p105_objectput_dynamic_tag\n");
  }
}
P105ObjectPutDynamicTagTest;

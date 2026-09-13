U0 P69BCorruptRef()
{
  // Corrupt the P69Repo.hgs file directly: find the second commit's
  // own tree_hash bytes (right after the offset the previous test
  // recorded) and zero them out to point at a hash no object has.
  I64 sz;
  U8 *buf = FileRead("C:/Home/P69Repo.hgs", &sz);

  // Walk the archive manually to find the LAST commit record and
  // corrupt its tree_hash (first 8 bytes of its content are enough
  // to guarantee it no longer resolves).
  I64 pos = 16;
  I64 last_commit_off = -1;
  while (pos < sz) {
    U64 rec_len = GetU64LE(buf, pos);
    U8 obj_type = buf[pos+8];
    if (obj_type == 3) last_commit_off = pos; // OBJ_COMMIT
    pos += 8 + rec_len + 64;
  }
  CommPrint(1, "last_commit_off=%d\n", last_commit_off);

  U8 *tree_hash_bytes = buf + last_commit_off + 9;
  I64 i;
  for (i=0; i<8; i++) tree_hash_bytes[i] = tree_hash_bytes[i] ^ 0xFF;
  FileWrite("C:/Home/P69Repo.hgs", buf, sz);

  CommPrint(1, "PASS p69b_corruption_injected\n");
}
P69BCorruptRef;

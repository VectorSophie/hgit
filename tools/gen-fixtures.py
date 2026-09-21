#!/usr/bin/env python3
"""gen-fixtures.py <bundle.qcow2> [out_dir] - run tests/full-regression.hc on real
TempleOS (a COPY of the bundle, headless) and write golden fixtures: every repo
the regression leaves behind (.hgs + .hgs.m, hex-dumped over COM1) plus the
regression's own serial output (expected.log). The native port's conformance
tests read these. Reuses build-bundle.py's COM2 push receiver."""
import os, re, shutil, socket, subprocess, sys, time

base = sys.argv[1]
out = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else "fixtures")
here = os.path.dirname(os.path.abspath(__file__))
work = "/tmp/hgit-fixtures-work"
os.makedirs(work, exist_ok=True); os.makedirs(out, exist_ok=True)
disk, serial = work + "/disk.qcow2", work + "/serial.log"
mon_sock, com2_sock = work + "/qemu.sock", work + "/com2.sock"
for f in (serial, mon_sock, com2_sock):
    if os.path.exists(f): os.remove(f)
shutil.copy(base, disk)

REPOS = ["TFullRepo", "TFullExported", "TFullImported", "TFullTreeRepo", "TFullMergeRepo",
         "TFIgnoreRepo", "TFAttrsRepo", "TFMergeModeRepo", "TFConfRepo", "TFConfRepoB", "TFConfNewer"]
paths = [f"C:/Home/{r}.hgs{s}" for r in REPOS for s in ("", ".m")]
dump = '''U0 FixDump(U8 *path)
{
  I64 sz,i;
  U8 *b;
  U8 line[130];
  if (!FileFind(path)) { CommPrint(1,"FIXMISSING %s\\n",path); return; }
  b=FileRead(path,&sz);
  CommPrint(1,"FIXFILE %s %d\\n",path,sz);
  for (i=0;i<sz;i++) {
    StrPrint(line+(i%64)*2,"%02X",b[i]);
    if (i%64==63) CommPrint(1,"%s\\n",line);
  }
  if (sz%64) { line[(sz%64)*2]=0; CommPrint(1,"%s",line); }
  CommPrint(1,"\\nFIXEND %s\\n",path);
  Free(b);
}
''' + "".join(f'FixDump("{p}");\n' for p in paths) + 'CommPrint(1,"FIX_ALL_DONE\\n");\n'
payload = (open(os.path.join(here, "..", "tests", "full-regression.hc")).read() + "\n" + dump).encode()

KEYMAP = {" ": "spc", "\n": "ret", "`": "grave_accent", "-": "minus", "=": "equal", "[": "bracket_left", "]": "bracket_right", "\\": "backslash", ";": "semicolon", "'": "apostrophe", ",": "comma", ".": "dot", "/": "slash"}
SHIFTED = {"!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7", "*": "8", "(": "9", ")": "0", "_": "minus", "+": "equal", "{": "bracket_left", "}": "bracket_right", "|": "backslash", ":": "semicolon", '"': "apostrophe", "<": "comma", ">": "dot", "?": "slash", "~": "grave_accent"}
def mon():
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.connect(mon_sock); time.sleep(0.2); s.recv(4096); return s
def sendkey(s, k): s.send(("sendkey " + k + "\n").encode()); time.sleep(0.05); s.recv(4096)
def type_line(text, wait=1.5):
    s = mon()
    for ch in text:
        k = KEYMAP.get(ch) or ("shift-" + SHIFTED[ch] if ch in SHIFTED else ("shift-" + ch.lower() if ch.isupper() else ch))
        sendkey(s, k)
    sendkey(s, "ret"); time.sleep(wait); s.close()
def log(): return open(serial, "rb").read().decode("latin1")
def wait_for(marker, timeout):
    t = time.time()
    while time.time() - t < timeout:
        if marker in log(): return True
        time.sleep(2)
    return False

q = subprocess.Popen(["qemu-system-x86_64", "-machine", "pc", "-m", "512", "-display", "none",
    "-serial", "file:" + serial, "-monitor", "unix:%s,server,nowait" % mon_sock,
    "-chardev", "socket,id=com2,path=%s,server=on,wait=off" % com2_sock, "-serial", "chardev:com2",
    "-boot", "c", "-drive", "file=%s,if=ide,format=qcow2" % disk])
try:
    for _ in range(50):
        if os.path.exists(mon_sock): break
        time.sleep(0.2)
    time.sleep(4); s = mon(); sendkey(s, "1"); s.close()
    time.sleep(20); s = mon(); sendkey(s, "n"); s.close()
    print("settling 240s ..."); time.sleep(240)
    type_line('#include "::/Doc/Comm";')
    type_line('U8 *Db=MAlloc(524288);I64 Di=0;U8 Dc;Bool _D_exit=FALSE;')
    type_line('CommInit8n1(2,115200);CommInit8n1(1,115200);FifoU8Del(comm_ports[2].RX_fifo);comm_ports[2].RX_fifo=FifoU8New(524288);')
    type_line('I64 sz;U8 *hb=FileRead("C:/Home/HgitAll.HC",&sz);ExePutS(hb);', wait=45)
    type_line('U0 D(){CommPrint(1,"D_OK\\n");while(!_D_exit){if(FifoU8Rem(comm_ports[2].RX_fifo,&Dc)){'
              'if(Dc==4){Db[Di]=0;ExePutS(Db);CommPrint(1,"D_DONE\\n");Di=0;}else if(Di<524287){Db[Di++]=Dc;}}else Sleep(10);}}')
    type_line('D();')
    if not wait_for("D_OK", 60): sys.exit("receiver never came up")
    print("pushing %d bytes ..." % len(payload))
    c = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); c.connect(com2_sock); time.sleep(0.3)
    for i in range(0, len(payload), 2048):
        c.sendall(payload[i:i+2048]); time.sleep(0.15)
    time.sleep(0.3); c.sendall(b"\x04"); time.sleep(0.5); c.close()
    if not wait_for("FIX_ALL_DONE", 2400): sys.exit("dump never finished; serial tail:\n" + log()[-800:])
    time.sleep(3)
    s = mon(); s.send(b"quit\n"); time.sleep(1)
finally:
    try: q.wait(timeout=20)
    except Exception: q.kill()

L = log()
b, e = L.find("TFULL_BEGIN"), L.find("TFULL_END")
open(out + "/expected.log", "w").write(L[b:e + len("TFULL_END")] + "\n")
n = 0
for m in re.finditer(r"FIXFILE (\S+) (\d+)\n(.*?)\nFIXEND \1", L, re.S):
    name = os.path.basename(m.group(1)); data = bytes.fromhex(re.sub(r"\s", "", m.group(3)))
    assert len(data) == int(m.group(2)), (name, len(data), m.group(2))
    open(out + "/" + name, "wb").write(data); n += 1
print("wrote %d fixture files + expected.log to %s; missing: %s" % (n, out, re.findall(r"FIXMISSING (\S+)", L)))

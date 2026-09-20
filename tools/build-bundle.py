#!/usr/bin/env python3
"""build-bundle.py - refresh packaging/bundle/templeos-hgit.qcow2 with the
current packaging/HgitAll.HC saved at C:/Home/HgitAll.HC.

Boots a COPY of a clean TempleOS disk under QEMU (headless), types the small
COM2 receiver over the monitor, pushes the package over COM2, saves it in the
guest, and verifies size + checksum against the host copy before compressing.

Why not the old bootstrap (docs/research/failed-approaches.md, 2026-09-15):
its receiver buffer/FIFO was 128KB and silently DROPPED bytes past that, so a
~400KB package arrived truncated. Here both are 512KB, the session gets a long
settle wait first (TempleOS is CPU-busy for its first minutes), and the save is
checked with a checksum instead of assumed.

Usage: build-bundle.py <base.qcow2> <out.qcow2> [work_dir]
"""
import os, shutil, socket, subprocess, sys, time

base, out = sys.argv[1], sys.argv[2]
work = sys.argv[3] if len(sys.argv) > 3 else "/tmp/hgit-bundle-work"
pkg = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "packaging", "HgitAll.HC")
os.makedirs(work, exist_ok=True)
disk = os.path.join(work, "disk.qcow2")
serial = os.path.join(work, "serial.log")
mon_sock = os.path.join(work, "qemu.sock")
com2_sock = os.path.join(work, "com2.sock")
for f in (serial, mon_sock, com2_sock):
    if os.path.exists(f): os.remove(f)
shutil.copy(base, disk)

data = open(pkg, "rb").read()
N = len(data)
ck = 0
for b in data: ck = (ck * 31 + b) & 0xFFFFFFFF

KEYMAP = {" ": "spc", "\n": "ret", "`": "grave_accent", "-": "minus", "=": "equal",
          "[": "bracket_left", "]": "bracket_right", "\\": "backslash", ";": "semicolon",
          "'": "apostrophe", ",": "comma", ".": "dot", "/": "slash"}
SHIFTED = {"!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7", "*": "8",
           "(": "9", ")": "0", "_": "minus", "+": "equal", "{": "bracket_left",
           "}": "bracket_right", "|": "backslash", ":": "semicolon", '"': "apostrophe",
           "<": "comma", ">": "dot", "?": "slash", "~": "grave_accent"}

def mon():
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.connect(mon_sock)
    time.sleep(0.2); s.recv(4096); return s

def sendkey(s, key):
    s.send(("sendkey " + key + "\n").encode()); time.sleep(0.05); s.recv(4096)

def type_line(text):
    s = mon()
    for ch in text:
        if ch in KEYMAP: k = KEYMAP[ch]
        elif ch in SHIFTED: k = "shift-" + SHIFTED[ch]
        elif ch.isupper(): k = "shift-" + ch.lower()
        else: k = ch
        sendkey(s, k)
    sendkey(s, "ret"); time.sleep(1.5); s.close()

def log(): return open(serial, "rb").read().decode("latin1")

def wait_for(marker, timeout):
    t = time.time()
    while time.time() - t < timeout:
        if marker in log(): return True
        time.sleep(1)
    return False

q = subprocess.Popen(["qemu-system-x86_64", "-machine", "pc", "-m", "512", "-display", "none",
    "-serial", "file:" + serial, "-monitor", "unix:%s,server,nowait" % mon_sock,
    "-chardev", "socket,id=com2,path=%s,server=on,wait=off" % com2_sock, "-serial", "chardev:com2",
    "-boot", "c", "-drive", "file=%s,if=ide,format=qcow2" % disk])
try:
    for _ in range(50):
        if os.path.exists(mon_sock): break
        time.sleep(0.2)
    time.sleep(4); s = mon(); sendkey(s, "1"); s.close()      # boot drive C
    time.sleep(20); s = mon(); sendkey(s, "n"); s.close()     # decline the tour
    print("settling 240s (TempleOS is CPU-busy after boot) ..."); time.sleep(240)

    boot = [
        '#include "::/Doc/Comm";',
        'U8 *Db=MAlloc(524288);I64 Di=0;U8 Dc;Bool _D_exit=FALSE;',
        'CommInit8n1(2,115200);CommInit8n1(1,115200);FifoU8Del(comm_ports[2].RX_fifo);comm_ports[2].RX_fifo=FifoU8New(524288);',
        'U0 D(){CommPrint(1,"D_OK\\n");while(!_D_exit){if(FifoU8Rem(comm_ports[2].RX_fifo,&Dc)){'
        'if(Dc==4){Db[Di]=0;ExePutS(Db);CommPrint(1,"D_DONE\\n");Di=0;}else if(Di<524287){Db[Di++]=Dc;}}else Sleep(10);}CommPrint(1,"D_EXIT\\n");}',
        'D();',
    ]
    for line in boot:
        type_line(line)
    if not wait_for("D_OK", 30):
        sys.exit("receiver never reported D_OK - check the guest screen (monitor: screendump)")
    print("receiver up; pushing %d bytes ..." % N)

    trailer = ('\nFileWrite("C:/Home/HgitAll.HC",Db,%d);\n'
               'I64 sz2;U8 *b2=FileRead("C:/Home/HgitAll.HC",&sz2);I64 ck=0,ci;'
               'for(ci=0;ci<sz2;ci++)ck=(ck*31+b2[ci])&0xFFFFFFFF;'
               'CommPrint(1,"SAVED %%d CK %%d\\n",sz2,ck);\n') % N
    payload = data + trailer.encode()
    c = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); c.connect(com2_sock); time.sleep(0.3)
    for i in range(0, len(payload), 2048):
        c.sendall(payload[i:i+2048]); time.sleep(0.15)
    time.sleep(0.3); c.sendall(b"\x04"); time.sleep(0.5); c.close()

    want = "SAVED %d CK %d" % (N, ck)
    if not wait_for(want, 240):
        print("verification FAILED, guest said:", [l for l in log().splitlines() if "SAVED" in l or "ERR" in l][-3:])
        sys.exit(1)
    print("verified in guest:", want)
    time.sleep(3)
    s = mon(); s.send(b"quit\n"); time.sleep(1)
finally:
    try: q.wait(timeout=20)
    except Exception: q.kill()

subprocess.check_call(["qemu-img", "convert", "-c", "-O", "qcow2", disk, out])
print("wrote", out, os.path.getsize(out), "bytes")

#!/usr/bin/env python3
"""verify-bundle.py <bundle.qcow2> [extra HolyC lines...] - boot a COPY of the
bundle headless exactly the way hgit-launch.py does (no serial port attached,
so only what is drawn on the TempleOS screen counts), run Hgit("interactive")
and Hgit("version"), then any extra lines, and screendump to /tmp/hgv/*.png.
Used to confirm a person at the console really sees hgit's output."""
import os, shutil, socket, subprocess, sys, time
sys.path.insert(0, "/home/vectorsophie/Desktop/Workspace/hgit/tools")
disk_src, work = sys.argv[1], "/tmp/hgv"
os.makedirs(work, exist_ok=True)
disk = work + "/d.qcow2"; shutil.copy(disk_src, disk)
mon_sock = work + "/m.sock"
if os.path.exists(mon_sock): os.remove(mon_sock)
KEYMAP = {" ": "spc", "\n": "ret", "`": "grave_accent", "-": "minus", "=": "equal", "[": "bracket_left", "]": "bracket_right", "\\": "backslash", ";": "semicolon", "'": "apostrophe", ",": "comma", ".": "dot", "/": "slash"}
SHIFTED = {"!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7", "*": "8", "(": "9", ")": "0", "_": "minus", "+": "equal", "{": "bracket_left", "}": "bracket_right", "|": "backslash", ":": "semicolon", '"': "apostrophe", "<": "comma", ">": "dot", "?": "slash", "~": "grave_accent"}
def mon():
    s = socket.socket(socket.AF_UNIX); s.connect(mon_sock); time.sleep(0.2); s.recv(4096); return s
def key(s, k): s.send(("sendkey " + k + "\n").encode()); time.sleep(0.04); s.recv(4096)
def typ(text, enter=True):
    s = mon()
    for ch in text:
        k = KEYMAP.get(ch) or ("shift-" + SHIFTED[ch] if ch in SHIFTED else ("shift-" + ch.lower() if ch.isupper() else ch))
        key(s, k)
    if enter: key(s, "ret")
    time.sleep(2); s.close()
def shot(name):
    s = mon(); s.send(("screendump %s/%s.ppm\n" % (work, name)).encode()); time.sleep(1.5); s.recv(4096); s.close()
    subprocess.call(["python3", "-c", "from PIL import Image; Image.open('%s/%s.ppm').save('%s/%s.png')" % (work, name, work, name)])
q = subprocess.Popen(["qemu-system-x86_64", "-machine", "pc", "-m", "512", "-display", "none", "-serial", "null", "-monitor", "unix:" + mon_sock + ",server,nowait", "-boot", "c", "-drive", "file=%s,if=ide,format=qcow2" % disk])
time.sleep(4); s = mon(); key(s, "1"); s.close(); time.sleep(15); s = mon(); key(s, "n"); s.close(); time.sleep(2)
typ('#include "::/Doc/Comm";'); typ("CommInit8n1(1,115200);")
typ('I64 sz;U8 *b=FileRead("C:/Home/HgitAll.HC",&sz);ExePutS(b);'); time.sleep(30)
typ('Hgit("interactive");'); time.sleep(2); typ('Hgit("version");'); time.sleep(3); shot("after_version")
for extra in sys.argv[2:]:
    typ(extra); time.sleep(4)
shot("final")
s = mon(); s.send(b"quit\n"); time.sleep(1); q.wait(timeout=20)

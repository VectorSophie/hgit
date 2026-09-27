#!/usr/bin/env python3
"""bench-templeos.py <bundle.qcow2> <label> [--hgitall FILE] [--files N] [--fsz N]
[--commits N] - on-platform storage benchmark in a real TempleOS guest.

Boots a COPY of the bundle headless under QEMU, then either loads the
HgitAll.HC saved on the disk (the baseline) or pushes a candidate HgitAll.HC
over COM2 and executes it (a build under test), then pushes and runs
tools/bench-scenario.hc. Every BENCH line the guest prints on COM1 is stamped
with the host's arrival time so guest jiffies can be calibrated to wall
seconds. Results: docs/benchmarks/results/templeos-<label>.jsonl

The guest builds the repository itself with the real Hgit(...) commands, so the
numbers include the real linear index scan, the whole-file FileRead/FileWrite
on RedSea, and BLAKE2b in HolyC, under QEMU's CPU emulation. Absolute times
therefore depend on the host; compare runs made on the same machine.
"""
import argparse, json, os, re, shutil, socket, subprocess, sys, time

ap = argparse.ArgumentParser()
ap.add_argument("bundle"); ap.add_argument("label")
ap.add_argument("--hgitall"); ap.add_argument("--files", type=int, default=5)
ap.add_argument("--fsz", type=int, default=4096); ap.add_argument("--commits", type=int, default=100)
ap.add_argument("--timeout", type=int, default=5400)
a = ap.parse_args()

here = os.path.dirname(os.path.abspath(__file__))
work = "/tmp/hgit-bench-templeos-" + a.label
os.makedirs(work, exist_ok=True)
disk, serial = work + "/disk.qcow2", work + "/serial.log"
mon_sock, com2_sock = work + "/qemu.sock", work + "/com2.sock"
for f in (serial, mon_sock, com2_sock):
    if os.path.exists(f): os.remove(f)
shutil.copy(a.bundle, disk)
out_path = os.path.join(here, "..", "docs", "benchmarks", "results", "templeos-%s.jsonl" % a.label)
os.makedirs(os.path.dirname(out_path), exist_ok=True)

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
def wait_for(marker, timeout, start=0):
    t = time.time()
    while time.time() - t < timeout:
        if marker in log()[start:]: return True
        time.sleep(1)
    return False
def push(data, chunk=2048, pause=0.15):
    c = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); c.connect(com2_sock); time.sleep(0.3)
    for i in range(0, len(data), chunk):
        c.sendall(data[i:i + chunk]); time.sleep(pause)
    time.sleep(1.0); c.sendall(b"\x04"); time.sleep(1.0); c.close()

q = subprocess.Popen(["qemu-system-x86_64", "-machine", "pc", "-m", "512", "-display", "none",
    "-serial", "file:" + serial, "-monitor", "unix:%s,server,nowait" % mon_sock,
    "-chardev", "socket,id=com2,path=%s,server=on,wait=off" % com2_sock, "-serial", "chardev:com2",
    "-boot", "c", "-drive", "file=%s,if=ide,format=qcow2" % disk])
rows, stamp = [], {}
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
    if not a.hgitall:
        type_line('I64 sz;U8 *hb=FileRead("C:/Home/HgitAll.HC",&sz);ExePutS(hb);', wait=45)
    type_line('U0 D(){CommPrint(1,"D_OK\\n");while(!_D_exit){if(FifoU8Rem(comm_ports[2].RX_fifo,&Dc)){'
              'if(Dc==4){Db[Di]=0;ExePutS(Db);CommPrint(1,"D_DONE\\n");Di=0;}else if(Di<524287){Db[Di++]=Dc;}}else Sleep(10);}}')
    type_line('D();')
    if not wait_for("D_OK", 60): sys.exit("receiver never came up")
    if a.hgitall:
        data = open(a.hgitall, "rb").read()
        assert len(data) < 520000, "candidate HgitAll.HC exceeds the 512 KB receiver buffer"
        print("pushing candidate HgitAll.HC (%d bytes) ..." % len(data))
        mark = len(log()); push(data)
        if not wait_for("D_DONE", 900, mark): sys.exit("candidate load never finished")
        time.sleep(30)
    scen = open(os.path.join(here, "bench-scenario.hc")).read() + "\nBenchOffers(%d,%d,%d);\n" % (a.files, a.fsz, a.commits)
    mark = len(log())
    print("pushing scenario ..."); push(scen.encode())
    seen, t0 = 0, time.time()
    while time.time() - t0 < a.timeout:
        L = log()
        L = L[: L.rfind("\n") + 1]  # complete lines only: never parse a line mid-write
        for m in re.finditer(r"^(BENCH_\w+)(.*)$", L, re.M):
            key = (m.start())
            if key in stamp: continue
            stamp[key] = time.time()
            kv = dict(re.findall(r"(\w+)=(-?\d+)", m.group(2)))
            row = {"kind": m.group(1), "wall": stamp[key], **{k: int(v) for k, v in kv.items()}}
            rows.append(row); print(m.group(0).strip())
            if m.group(1) == "BENCH_DONE": raise StopIteration
        time.sleep(0.25)
    print("timeout before BENCH_DONE")
except StopIteration:
    pass
finally:
    try:
        s = mon(); s.send(b"quit\n"); time.sleep(1)
    except Exception: pass
    try: q.wait(timeout=20)
    except Exception: q.kill()

begin = next((r for r in rows if r["kind"] == "BENCH_BEGIN"), None)
done = next((r for r in rows if r["kind"] == "BENCH_DONE"), None)
jps = None
if begin and done and done["wall"] > begin["wall"]:
    jps = (done["jiffies"] - begin["jiffies"]) / (done["wall"] - begin["wall"])
with open(out_path, "w") as f:
    for r in rows:
        r["label"] = a.label; r["jiffies_per_wall_second"] = jps
        f.write(json.dumps(r) + "\n")
print("jiffies per wall second (calibration): %s" % jps)
print("wrote", out_path)

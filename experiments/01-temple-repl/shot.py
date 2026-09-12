#!/usr/bin/env python3
"""Screendump via QEMU HMP monitor unix socket, converted to PNG."""
import socket, sys, subprocess, time

sock_path, out_ppm, out_png = sys.argv[1], sys.argv[2], sys.argv[3]
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(5)
s.connect(sock_path)
time.sleep(0.3)
try:
    s.recv(4096)
except socket.timeout:
    pass
s.sendall(f"screendump {out_ppm}\n".encode())
time.sleep(0.8)
try:
    s.recv(4096)
except socket.timeout:
    pass
s.close()
subprocess.run(["convert", out_ppm, out_png], check=True)
print(out_png)

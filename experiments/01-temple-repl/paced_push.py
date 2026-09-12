#!/usr/bin/env python3
"""Push a HolyC source file over the COM2 unix socket in small paced
chunks (rather than one sendall() of the whole file) plus a trailing
EOT (0x04). Written after probe 34 found that a single large (46KB)
unpaced sendall could apparently be dropped/truncated partway through
under host memory pressure - the guest never saw that push's own EOT,
so its bytes silently concatenated with the NEXT push instead of
producing their own compile result. Pacing gives the emulated serial
IRQ path time to drain between bursts.

Usage: paced_push.py <sock_path> <file_path> [chunk_size] [delay]
"""
import socket, sys, time

sock_path = sys.argv[1]
file_path = sys.argv[2]
chunk_size = int(sys.argv[3]) if len(sys.argv) > 3 else 2048
delay = float(sys.argv[4]) if len(sys.argv) > 4 else 0.15

data = open(file_path, 'rb').read()
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(sock_path)
time.sleep(0.3)
sent = 0
for i in range(0, len(data), chunk_size):
    piece = data[i:i+chunk_size]
    s.sendall(piece)
    sent += len(piece)
    time.sleep(delay)
time.sleep(0.3)
s.sendall(b'\x04')
time.sleep(0.5)
s.close()
print(f"sent {sent}/{len(data)} bytes in {chunk_size}-byte pieces")

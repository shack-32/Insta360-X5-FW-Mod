#!/usr/bin/env python3
"""
Minimal telnet client for the Insta360 X5 RAM-only root shell (busybox telnetd).

Usage:
    python cam_shell.py "id; uname -a"
    python cam_shell.py --host 192.168.42.1 --port 2323 "cat /proc/mounts"

Handles the telnet IAC option negotiation that busybox telnetd performs.
"""
import argparse
import socket
import sys
import time

IAC = 0xFF
DONT = 0xFE
DO = 0xFD
WONT = 0xFC
WILL = 0xFB
SB = 0xFA
SE = 0xF0


def strip_negotiation(sock, data, out):
    i = 0
    while i < len(data):
        b = data[i]
        if b != IAC:
            out.append(b)
            i += 1
            continue
        if i + 1 >= len(data):
            break
        cmd = data[i + 1]
        if cmd in (DO, DONT, WILL, WONT):
            if i + 2 >= len(data):
                break
            opt = data[i + 2]
            if cmd == DO:
                sock.sendall(bytes([IAC, WONT, opt]))
            elif cmd == WILL:
                sock.sendall(bytes([IAC, DONT, opt]))
            i += 3
        elif cmd == SB:
            j = i + 2
            while j + 1 < len(data) and not (data[j] == IAC and data[j + 1] == SE):
                j += 1
            i = j + 2
        elif cmd == IAC:
            out.append(IAC)
            i += 2
        else:
            i += 2


def run(host, port, commands, wait=2.0, quiet_time=0.6, timeout=20.0):
    s = socket.create_connection((host, port), timeout=timeout)
    s.settimeout(0.4)

    def drain(seconds):
        end = time.time() + seconds
        buf = bytearray()
        last = time.time()
        while time.time() < end:
            try:
                chunk = s.recv(4096)
                if not chunk:
                    break
                strip_negotiation(s, chunk, buf)
                last = time.time()
            except socket.timeout:
                if time.time() - last > quiet_time and buf:
                    break
        return bytes(buf)

    out = bytearray()
    out += drain(wait)
    for cmd in commands:
        s.sendall((cmd + "\n").encode())
        out += drain(wait)
    try:
        s.sendall(b"exit\n")
    except OSError:
        pass
    time.sleep(0.2)
    s.close()
    return out.decode("utf-8", "replace")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="192.168.42.1")
    ap.add_argument("--port", type=int, default=2323)
    ap.add_argument("--wait", type=float, default=2.0)
    ap.add_argument("commands", nargs="*", help="shell commands to run")
    args = ap.parse_args()
    if not args.commands:
        args.commands = ["id"]
    print(run(args.host, args.port, args.commands, wait=args.wait))


if __name__ == "__main__":
    main()

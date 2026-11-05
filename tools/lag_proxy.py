"""Lokalne proxy UDP symulujace slabe lacze. Tylko do testow.

Uzycie: python tools/lag_proxy.py PORT_WEJSCIOWY PORT_SERWERA OPOZNIENIE_MS STRATA_PROCENT SEKUNDY
Opoznienie dotyczy kazdego kierunku, wiec ping to mniej wiecej jego dwukrotnosc.
"""
import heapq
import itertools
import random
import select
import socket
import sys
import time

listen_port, server_port, delay_ms, loss, duration = (float(v) for v in sys.argv[1:6])
delay = delay_ms / 1000.0

front = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
front.bind(("127.0.0.1", int(listen_port)))
server = ("127.0.0.1", int(server_port))
backs = {}  # adres klienta -> gniazdo do serwera
owners = {}  # gniazdo -> adres klienta
queue = []
order = itertools.count()
forwarded = dropped = 0
end = time.monotonic() + duration

while time.monotonic() < end:
    now = time.monotonic()
    while queue and queue[0][0] <= now:
        _, _, sock, target, data = heapq.heappop(queue)
        sock.sendto(data, target)
    timeout = max(0.0, min(0.002, queue[0][0] - now)) if queue else 0.002
    readable, _, _ = select.select([front, *owners], [], [], timeout)
    for sock in readable:
        try:
            data, sender = sock.recvfrom(65535)
        except ConnectionResetError:
            continue
        if random.random() * 100.0 < loss:
            dropped += 1
            continue
        forwarded += 1
        if sock is front:
            back = backs.get(sender)
            if back is None:
                back = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                back.bind(("127.0.0.1", 0))
                backs[sender] = back
                owners[back] = sender
            heapq.heappush(queue, (now + delay, next(order), back, server, data))
        else:
            heapq.heappush(queue, (now + delay, next(order), front, owners[sock], data))

print(f"[proxy] przeslane: {forwarded}, utracone: {dropped}")

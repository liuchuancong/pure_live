#!/usr/bin/env python3
"""Dependency-free live WebSocket probe for the current Huya danmaku protocol."""

from __future__ import annotations

import base64
import hashlib
import os
import socket
import ssl
import struct
import time

from interface_probe import USER_AGENT, request_json

HOST = "cdnws.api.huya.com"
HEARTBEAT = bytes.fromhex(
    "00031d0000690000006910032c3c4c56086f6e6c696e657569660f4f6e557365724865617274426561747d00003c08"
    "00010604745265711d00002f0a0a0c1600260036076164725f77617046000b1203aef00f2203aef00f3c426d5202605c"
    "60017c82000bb01f9cac0b8c980ca80c20"
)


def _head(type_id: int, tag: int) -> bytes:
    if tag < 15:
        return bytes([(tag << 4) | type_id])
    return bytes([(15 << 4) | type_id, tag])


def _tars_int(value: int, tag: int) -> bytes:
    if value == 0:
        return _head(12, tag)
    if -128 <= value <= 127:
        return _head(0, tag) + struct.pack(">b", value)
    if -32768 <= value <= 32767:
        return _head(1, tag) + struct.pack(">h", value)
    if -(2**31) <= value <= 2**31 - 1:
        return _head(2, tag) + struct.pack(">i", value)
    return _head(3, tag) + struct.pack(">q", value)


def _tars_string(value: str, tag: int) -> bytes:
    encoded = value.encode("utf-8")
    if len(encoded) <= 255:
        return _head(6, tag) + bytes([len(encoded)]) + encoded
    return _head(7, tag) + struct.pack(">I", len(encoded)) + encoded


def _join_packet(uid: int) -> bytes:
    inner = b"".join(
        [
            _tars_int(uid, 0),
            _tars_int(0, 1),
            _tars_string("", 2),
            _tars_string("", 3),
            _tars_int(0, 4),
            _tars_int(0, 5),
            _tars_int(uid, 6),
            _tars_int(3, 7),
        ]
    )
    return _tars_int(1, 0) + _head(13, 1) + _head(0, 0) + _tars_int(len(inner), 0) + inner


def _read_exact(connection: ssl.SSLSocket, length: int) -> bytes:
    chunks = bytearray()
    while len(chunks) < length:
        chunk = connection.recv(length - len(chunks))
        if not chunk:
            raise ConnectionError("WebSocket closed while reading a frame")
        chunks.extend(chunk)
    return bytes(chunks)


def _send_frame(connection: ssl.SSLSocket, payload: bytes, opcode: int = 2) -> None:
    mask = os.urandom(4)
    length = len(payload)
    header = bytearray([0x80 | opcode])
    if length < 126:
        header.append(0x80 | length)
    elif length <= 0xFFFF:
        header.append(0x80 | 126)
        header.extend(struct.pack(">H", length))
    else:
        header.append(0x80 | 127)
        header.extend(struct.pack(">Q", length))
    masked = bytes(value ^ mask[index % 4] for index, value in enumerate(payload))
    connection.sendall(bytes(header) + mask + masked)


def _receive_frame(connection: ssl.SSLSocket) -> tuple[int, bool, bytes]:
    first, second = _read_exact(connection, 2)
    final = bool(first & 0x80)
    opcode = first & 0x0F
    length = second & 0x7F
    if length == 126:
        length = struct.unpack(">H", _read_exact(connection, 2))[0]
    elif length == 127:
        length = struct.unpack(">Q", _read_exact(connection, 8))[0]
    mask = _read_exact(connection, 4) if second & 0x80 else None
    payload = _read_exact(connection, length)
    if mask:
        payload = bytes(value ^ mask[index % 4] for index, value in enumerate(payload))
    return opcode, final, payload


def _connect() -> ssl.SSLSocket:
    raw = socket.create_connection((HOST, 443), timeout=15)
    connection = ssl.create_default_context().wrap_socket(raw, server_hostname=HOST)
    connection.settimeout(30)
    key = base64.b64encode(os.urandom(16)).decode("ascii")
    request = (
        "GET / HTTP/1.1\r\n"
        f"Host: {HOST}\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\n"
        "Sec-WebSocket-Version: 13\r\n"
        "Origin: https://www.huya.com\r\n"
        f"User-Agent: {USER_AGENT}\r\n\r\n"
    )
    connection.sendall(request.encode("ascii"))
    response = bytearray()
    while b"\r\n\r\n" not in response:
        response.extend(_read_exact(connection, 1))
        if len(response) > 16384:
            raise ConnectionError("WebSocket handshake headers are too large")
    header_text = response.decode("iso-8859-1")
    if not header_text.startswith("HTTP/1.1 101"):
        raise ConnectionError(f"WebSocket handshake failed: {header_text.splitlines()[0]}")
    expected = base64.b64encode(hashlib.sha1(f"{key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11".encode()).digest())
    if f"sec-websocket-accept: {expected.decode()}".lower() not in header_text.lower():
        raise ConnectionError("WebSocket accept key mismatch")
    return connection


def _outer_command(payload: bytes) -> int | None:
    if not payload:
        return None
    first = payload[0]
    type_id = first & 0x0F
    tag = first >> 4
    position = 1
    if tag == 15:
        if len(payload) < 2:
            return None
        tag = payload[1]
        position = 2
    if tag != 0:
        return None
    sizes = {0: 1, 1: 2, 2: 4, 3: 8}
    if type_id == 12:
        return 0
    size = sizes.get(type_id)
    if size is None or len(payload) < position + size:
        return None
    return int.from_bytes(payload[position : position + size], "big", signed=True)


def _resolve_live_room() -> tuple[str, int]:
    recommendation = request_json(
        "https://www.huya.com/cache.php",
        {"m": "LiveList", "do": "getLiveListByPage", "tagAll": 0, "page": 1},
    )
    rooms = recommendation.get("data", {}).get("datas", []) if isinstance(recommendation, dict) else []
    if not rooms:
        raise ValueError("Huya recommendation returned no live rooms")
    room_id = str(rooms[0].get("profileRoom", ""))
    detail = request_json(
        "https://mp.huya.com/cache.php",
        {"m": "Live", "do": "profileRoom", "roomid": room_id, "showSecret": 1},
    )
    profile = detail.get("data", {}).get("profileInfo", {}) if isinstance(detail, dict) else {}
    uid = int(profile.get("uid", 0)) if isinstance(profile, dict) else 0
    if not room_id or uid <= 0:
        raise ValueError("Huya live room identity is missing")
    return room_id, uid


def main() -> int:
    room_id, uid = _resolve_live_room()
    connection = _connect()
    try:
        _send_frame(connection, _join_packet(uid))
        _send_frame(connection, HEARTBEAT)
        started = time.monotonic()
        fragmented = bytearray()
        while time.monotonic() - started < 30:
            opcode, final, payload = _receive_frame(connection)
            if opcode == 8:
                raise ConnectionError("Huya closed the WebSocket before a push message")
            if opcode == 9:
                _send_frame(connection, payload, opcode=10)
                continue
            if opcode in (1, 2):
                fragmented = bytearray(payload)
            elif opcode == 0:
                fragmented.extend(payload)
            else:
                continue
            if final:
                message = bytes(fragmented)
                fragmented.clear()
                if _outer_command(message) == 7:
                    print(f"PASS huya.danmaku_websocket room={room_id} uid={uid} push_bytes={len(message)}")
                    return 0
        raise TimeoutError("Huya did not send a push message within 30 seconds")
    finally:
        try:
            _send_frame(connection, b"", opcode=8)
        finally:
            connection.close()


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
import argparse
import struct
from pathlib import Path

TRACKS = 160
SECTORS = 8
SECTOR_SIZE = 256
D88_HEADER_SIZE = 0x2B0
D88_TRACK_SLOTS = 164


def build_d88(raw: bytes, name: str) -> bytes:
    expected = TRACKS * SECTORS * SECTOR_SIZE
    if len(raw) != expected:
        raise ValueError(f"expected {expected} bytes, got {len(raw)} bytes")

    out = bytearray(D88_HEADER_SIZE)
    disk_name = name.encode('ascii', 'replace')[:16]
    out[:len(disk_name)] = disk_name
    out[0x1A] = 0x00
    out[0x1B] = 0x00  # D88 2D media type

    offsets = []
    for logical_track in range(TRACKS):
        offsets.append(len(out))
        cylinder = logical_track // 2
        head = logical_track & 1
        track_base = logical_track * SECTORS * SECTOR_SIZE
        for sector in range(1, SECTORS + 1):
            out += struct.pack(
                '<BBBBHBBB5sH',
                cylinder, head, sector, 1, SECTORS,
                0x00, 0x00, 0x00, b'\x00' * 5, SECTOR_SIZE,
            )
            start = track_base + (sector - 1) * SECTOR_SIZE
            out += raw[start:start + SECTOR_SIZE]

    for index, offset in enumerate(offsets):
        struct.pack_into('<I', out, 0x20 + index * 4, offset)
    for index in range(len(offsets), D88_TRACK_SLOTS):
        struct.pack_into('<I', out, 0x20 + index * 4, 0)
    struct.pack_into('<I', out, 0x1C, len(out))
    return bytes(out)


def main():
    parser = argparse.ArgumentParser(description='Convert PC-8001mkII CP/M raw 2D image to D88')
    parser.add_argument('--name', default='P80MK2 CPM22')
    parser.add_argument('input', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(build_d88(args.input.read_bytes(), args.name))


if __name__ == '__main__':
    main()

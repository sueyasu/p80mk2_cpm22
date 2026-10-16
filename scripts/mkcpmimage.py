#!/usr/bin/env python3
import argparse
import math
from pathlib import Path

TRACKS = 160
SECTORS = 8
SECTOR_SIZE = 256
BOOT_TRACKS = 5
BLOCK_SIZE = 2048
MAX_DIR = 64
EXM = 1
ERASED = 0xE5
RECORD_SIZE = 128
DIR_ENTRY_SIZE = 32


def cpm_name(path: Path):
    name = path.name.upper()
    stem, dot, ext = name.rpartition('.')
    if not dot:
        stem, ext = name, ''
    allowed = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#$%&'()-@^_`{}~"
    if not stem or len(stem) > 8 or len(ext) > 3:
        raise ValueError(f"{path}: filename is not CP/M 8.3 compatible")
    if any(ch not in allowed for ch in stem + ext):
        raise ValueError(f"{path}: filename contains unsupported CP/M characters")
    return stem.ljust(8).encode('ascii'), ext.ljust(3).encode('ascii')


def add_file(image, directory, dir_index, next_block, path):
    data = path.read_bytes()
    name, ext = cpm_name(path)
    boot_bytes = BOOT_TRACKS * SECTORS * SECTOR_SIZE
    total_blocks = (len(image) - boot_bytes) // BLOCK_SIZE
    records_left = math.ceil(len(data) / RECORD_SIZE)
    source_pos = 0
    extent_base = 0

    if records_left == 0:
        records_left = 1

    while records_left:
        if dir_index >= MAX_DIR:
            raise ValueError(f"{path}: CP/M directory is full")

        extent_records = min(records_left, 128 * (EXM + 1))
        extent_bytes = min(max(0, len(data) - source_pos), extent_records * RECORD_SIZE)
        blocks_needed = math.ceil(extent_bytes / BLOCK_SIZE) if extent_bytes else 0
        if blocks_needed > 16:
            raise AssertionError("extent needs more than sixteen allocation pointers")
        if next_block + blocks_needed > total_blocks:
            raise ValueError(f"{path}: disk is full")

        blocks = list(range(next_block, next_block + blocks_needed))
        for block in blocks:
            dest = boot_bytes + block * BLOCK_SIZE
            chunk = data[source_pos:source_pos + BLOCK_SIZE]
            image[dest:dest + len(chunk)] = chunk
            source_pos += len(chunk)

        logical_extent = extent_base + ((extent_records - 1) // 128)
        rc = extent_records - ((extent_records - 1) // 128) * 128
        entry = bytearray([0] * DIR_ENTRY_SIZE)
        entry[0] = 0
        entry[1:9] = name
        entry[9:12] = ext
        entry[12] = logical_extent & 0x1F
        entry[13] = 0
        entry[14] = (logical_extent >> 5) & 0x3F
        entry[15] = rc
        for i, block in enumerate(blocks):
            entry[16 + i] = block

        off = dir_index * DIR_ENTRY_SIZE
        directory[off:off + DIR_ENTRY_SIZE] = entry
        dir_index += 1
        next_block += blocks_needed
        records_left -= extent_records
        extent_base += EXM + 1

    return dir_index, next_block


def main():
    parser = argparse.ArgumentParser(description='Build a PC-8001mkII CP/M 2.2 raw 2D floppy image')
    parser.add_argument('--system', type=Path, required=True)
    parser.add_argument('--file', action='append', type=Path, default=[])
    parser.add_argument('output', type=Path)
    args = parser.parse_args()

    total_size = TRACKS * SECTORS * SECTOR_SIZE
    boot_bytes = BOOT_TRACKS * SECTORS * SECTOR_SIZE
    system = args.system.read_bytes()
    if len(system) > boot_bytes:
        raise ValueError(f"{args.system}: {len(system)} bytes exceeds {boot_bytes}-byte system area")

    image = bytearray([ERASED]) * total_size
    image[:len(system)] = system

    directory_size = MAX_DIR * DIR_ENTRY_SIZE
    directory = bytearray([ERASED]) * directory_size
    dir_index = 0
    next_block = 1  # AL0=80h: block 0 contains the directory.
    seen = set()

    for path in args.file:
        name, ext = cpm_name(path)
        key = name + ext
        if key in seen:
            raise ValueError(f"{path}: duplicate CP/M filename")
        seen.add(key)
        dir_index, next_block = add_file(image, directory, dir_index, next_block, path)

    image[boot_bytes:boot_bytes + directory_size] = directory
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(image)


if __name__ == '__main__':
    main()

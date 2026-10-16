# Building floppy images

The top-level `Makefile` builds the 59k and 64k PC-8001mkII CP/M 2.2 floppy images without committing generated disk images to Git.

## Required tools

The normal `make` target requires:

- `make`
- `z80asm`
- `asm8080`
- Python 3

HxC is optional and is only needed for HFE output.

## Required CP/M 2.2 cores

The repository contains the PC-8001mkII boot loaders and BIOS sources, but not the relocatable CP/M 2.2 CCP/BDOS binaries. Because the 59k and 64k builds use different load addresses, prepare both 5632-byte (`0x1600`) cores:

```text
external/system/cpm22_59k.bin
external/system/cpm22_64k.bin
```

The Makefile assembles the matching BIOS and appends it to each core:

```text
59k: CCP/BDOS 0x1600 bytes + BIOS 0x0d00 bytes = 35 x 256-byte sectors
64k: CCP/BDOS 0x1600 bytes + BIOS 0x0500 bytes = 27 x 256-byte sectors
```

If you already have bootable RAW images made by this port, the cores can be extracted from sector 2 onward (byte offset 256):

```sh
mkdir -p external/system

dd if=old_59k.img of=external/system/cpm22_59k.bin \
   bs=1 skip=256 count=5632 status=none

dd if=old_64k.img of=external/system/cpm22_64k.bin \
   bs=1 skip=256 count=5632 status=none
```

`external/` is ignored by Git.

## Included commands

`command/fdformat.asm` is assembled automatically as `FDFORMAT.COM` and included in user 0 of both generated images.

Any additional `*.COM` files placed in:

```text
external/commands/
```

are also copied into user 0 of both images.

## Build

Run:

```sh
make
```

This creates:

```text
build/p80mk2_cpm22_59k.img
build/p80mk2_cpm22_59k.d88
build/p80mk2_cpm22_64k.img
build/p80mk2_cpm22_64k.d88
```

Both variants use the same PC-80S31-compatible 2D geometry:

- 80 cylinders
- 2 heads
- 8 x 256-byte sectors per side
- 5 reserved system tracks
- 320 KiB RAW image size

`scripts/mkcpmimage.py` creates the CP/M filesystem directly and does not require `cpmtools` for the normal build. `scripts/raw2d88.py` converts the RAW image to D88.

## HFE images

If the HxC command-line converter `hxcfe` is installed, run:

```sh
make hfe
```

This creates:

```text
build/p80mk2_cpm22_59k.hfe
build/p80mk2_cpm22_64k.hfe
```

## Other targets

```sh
make raw          # build both RAW .img images
make d88          # build both D88 images
make hfe          # build both HFE images (requires hxcfe)
make commands     # build FDFORMAT.COM only
make check-tools  # check normal host-side build dependencies
make check-cores  # verify the two external CCP/BDOS cores
make clean        # remove build/
```

Generated floppy images are intentionally ignored by Git and should normally be published as release assets rather than committed to the repository.

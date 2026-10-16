BUILD_DIR := build
COMMAND_BUILD_DIR := $(BUILD_DIR)/commands

Z80ASM ?= z80asm
ASM8080 ?= asm8080
PYTHON ?= python3
HXCFE ?= hxcfe

CORE_59K ?= external/system/cpm22_59k.bin
CORE_64K ?= external/system/cpm22_64k.bin
EXTERNAL_COMMANDS := $(wildcard external/commands/*.COM external/commands/*.com)

BOOT_59K := $(BUILD_DIR)/boot-59k.bin
BIOS_59K := $(BUILD_DIR)/cbios-59k.bin
RESIDENT_59K := $(BUILD_DIR)/resident-59k.bin
SYSTEM_59K := $(BUILD_DIR)/system-59k.bin

BOOT_64K := $(BUILD_DIR)/boot-64k.bin
BIOS_64K := $(BUILD_DIR)/cbios-64k.bin
RESIDENT_64K := $(BUILD_DIR)/resident-64k.bin
SYSTEM_64K := $(BUILD_DIR)/system-64k.bin

FDFORMAT_COM := $(COMMAND_BUILD_DIR)/FDFORMAT.COM
IMAGE_COMMANDS := $(FDFORMAT_COM) $(EXTERNAL_COMMANDS)

IMG_59K := $(BUILD_DIR)/p80mk2_cpm22_59k.img
D88_59K := $(BUILD_DIR)/p80mk2_cpm22_59k.d88
HFE_59K := $(BUILD_DIR)/p80mk2_cpm22_59k.hfe
IMG_64K := $(BUILD_DIR)/p80mk2_cpm22_64k.img
D88_64K := $(BUILD_DIR)/p80mk2_cpm22_64k.d88
HFE_64K := $(BUILD_DIR)/p80mk2_cpm22_64k.hfe

.PHONY: all raw d88 hfe commands clean check-tools check-cores check-hxcfe

all: raw d88

raw: $(IMG_59K) $(IMG_64K)

d88: $(D88_59K) $(D88_64K)

hfe: $(HFE_59K) $(HFE_64K)

commands: $(FDFORMAT_COM)

check-tools:
	@set -e; \
	for t in $(Z80ASM) $(ASM8080) $(PYTHON); do \
		command -v $$t >/dev/null 2>&1 || { echo "missing required tool: $$t" >&2; exit 1; }; \
	done

check-cores:
	@set -e; \
	for f in "$(CORE_59K)" "$(CORE_64K)"; do \
		test -f "$$f" || { echo "missing CP/M 2.2 CCP/BDOS core: $$f" >&2; echo "see BUILD.md" >&2; exit 1; }; \
		test "$$(stat -c%s "$$f")" -eq 5632 || { echo "$$f: expected 5632 (0x1600) bytes" >&2; exit 1; }; \
	done

check-hxcfe:
	@command -v $(HXCFE) >/dev/null 2>&1 || { \
		echo "missing optional HxC command-line converter: $(HXCFE)" >&2; \
		echo "RAW and D88 images are available with 'make' even without HxC." >&2; \
		exit 1; \
	}

$(BUILD_DIR):
	mkdir -p $@

$(COMMAND_BUILD_DIR): | $(BUILD_DIR)
	mkdir -p $@

$(BOOT_59K): 59k/src/boot-59k.asm | $(BUILD_DIR)
	cd 59k/src && $(Z80ASM) -b -o$(abspath $@) boot-59k.asm
	@actual=$$(stat -c%s $@); \
	if [ "$$actual" -gt 256 ]; then echo "$@: assembled size $$actual exceeds one 256-byte boot sector" >&2; exit 1; fi
	truncate -s 256 $@

$(BIOS_59K): 59k/src/cbios-59k.asm 59k/src/keymap-pc8001.inc | $(BUILD_DIR)
	cd 59k/src && $(Z80ASM) -b -o$(abspath $@) cbios-59k.asm
	@actual=$$(stat -c%s $@); \
	if [ "$$actual" -gt 3328 ]; then echo "$@: assembled size $$actual exceeds 3328-byte 59k BIOS area" >&2; exit 1; fi
	truncate -s 3328 $@

$(RESIDENT_59K): $(BIOS_59K) | check-cores $(BUILD_DIR)
	cat "$(CORE_59K)" $(BIOS_59K) > $@
	@test "$$(stat -c%s $@)" -eq 8960 || { echo "$@: expected 8960 bytes" >&2; exit 1; }

$(SYSTEM_59K): $(BOOT_59K) $(RESIDENT_59K)
	cat $^ > $@
	@test "$$(stat -c%s $@)" -eq 9216 || { echo "$@: expected 9216 bytes" >&2; exit 1; }

$(BOOT_64K): 64k/src/boot-64k.asm | $(BUILD_DIR)
	$(ASM8080) $< -o$(basename $@)
	@actual=$$(stat -c%s $@); \
	if [ "$$actual" -gt 256 ]; then echo "$@: assembled size $$actual exceeds one 256-byte boot sector" >&2; exit 1; fi
	truncate -s 256 $@

$(BIOS_64K): 64k/src/cbios-64k.asm | $(BUILD_DIR)
	$(ASM8080) $< -o$(basename $@)
	@actual=$$(stat -c%s $@); \
	if [ "$$actual" -gt 1280 ]; then echo "$@: assembled size $$actual exceeds 1280-byte 64k BIOS area" >&2; exit 1; fi
	truncate -s 1280 $@

$(RESIDENT_64K): $(BIOS_64K) | check-cores $(BUILD_DIR)
	cat "$(CORE_64K)" $(BIOS_64K) > $@
	@test "$$(stat -c%s $@)" -eq 6912 || { echo "$@: expected 6912 bytes" >&2; exit 1; }

$(SYSTEM_64K): $(BOOT_64K) $(RESIDENT_64K)
	cat $^ > $@
	@test "$$(stat -c%s $@)" -eq 7168 || { echo "$@: expected 7168 bytes" >&2; exit 1; }

$(FDFORMAT_COM): command/fdformat.asm | $(COMMAND_BUILD_DIR)
	$(ASM8080) $< -o$(basename $@)
	mv $(basename $@).bin $@

$(IMG_59K): $(SYSTEM_59K) $(IMAGE_COMMANDS) scripts/mkcpmimage.py | $(BUILD_DIR)
	$(PYTHON) scripts/mkcpmimage.py --system $(SYSTEM_59K) \
		$(foreach f,$(IMAGE_COMMANDS),--file $(f)) $@

$(IMG_64K): $(SYSTEM_64K) $(IMAGE_COMMANDS) scripts/mkcpmimage.py | $(BUILD_DIR)
	$(PYTHON) scripts/mkcpmimage.py --system $(SYSTEM_64K) \
		$(foreach f,$(IMAGE_COMMANDS),--file $(f)) $@

$(D88_59K): $(IMG_59K) scripts/raw2d88.py | $(BUILD_DIR)
	$(PYTHON) scripts/raw2d88.py --name "P80MK2 CPM22 59K" $< $@

$(D88_64K): $(IMG_64K) scripts/raw2d88.py | $(BUILD_DIR)
	$(PYTHON) scripts/raw2d88.py --name "P80MK2 CPM22 64K" $< $@

$(HFE_59K): $(D88_59K) | check-hxcfe
	$(HXCFE) -finput:"$<" -conv:HXC_HFE -foutput:"$@"

$(HFE_64K): $(D88_64K) | check-hxcfe
	$(HXCFE) -finput:"$<" -conv:HXC_HFE -foutput:"$@"

clean:
	rm -rf $(BUILD_DIR)

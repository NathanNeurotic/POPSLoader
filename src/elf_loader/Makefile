# _____     ___ ____     ___ ____
#  ____|   |    ____|   |        | |____|
# |     ___|   |____ ___|    ____| |    \    PS2DEV Open Source Project.
#-----------------------------------------------------------------------
# (c) 2020 Francisco Javier Trujillo Mata <fjtrujy@gmail.com>
# Licenced under Academic Free License version 2.0
# Review ps2sdk README & LICENSE files for further details.

BIN2C = $(PS2SDK)/bin/bin2c
EE_OBJS = src/elf.o loader.o
EE_LIB = libcustom-elf-loader.a

.PHONY: FORCE

src/loader/bin/loader.elf:
	$(MAKE) src/loader

# STRIP BEFORE BIN2C. The child loader is embedded whole into POPSLOADER.ELF as
# the `loader_elf` byte array, so anything the linker leaves in that .elf is
# shipped forever. Unstripped it is 1,057,704 bytes, of which ~918 KB is symbol
# + debug tables that the PS2 never loads -- the parent only ever consumes its
# PT_LOAD image. Stripped it is 139,700 bytes, and the loadable image is proven
# byte-identical (same entry point, same PT_LOAD offsets/sizes, identical MD5 of
# `objcopy -O binary` output before/after), so this is a pure payload cut with no
# behavior change to the D-10/D-14/D-15 launch path. Worth ~194 KB (11%) off the
# packed ELF.
# In place, NOT into a copy: CI (compilation.yml / rolling-release.yml) validates
# blob parity by running bin2c on THIS file and cmp'ing against loader.c, so the
# file bin2c reads here must be the same one CI reads.
loader.c: src/loader/bin/loader.elf src/loader/src/loader.c FORCE
	$(EE_STRIP) src/loader/bin/loader.elf
	$(BIN2C) src/loader/bin/loader.elf $@ loader_elf
	touch $@

all: loader.c $(EE_LIB)

clean:
	rm -f $(EE_LIB) $(EE_OBJS)

include $(PS2SDK)/samples/Makefile.pref
include $(PS2SDK)/samples/Makefile.eeglobal

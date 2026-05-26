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

# DIAG_U10 BRANCH: when defined, src/elf.c paints GS background colors at
# each stage of LoadELFFromFileExecPS2RebootIOPWithPartition's direct path
# so we can see WHERE the U-10 (BOOT.ELF from HDD-booted POPSLoader) flow
# black-screens. To prune: revert this block AND remove the matching
# #ifdef POPSLOADER_DIAG_U10 blocks in src/elf.c (grep finds them).
POPSLOADER_DIAG_U10 ?= 1

ifneq (x$(POPSLOADER_DIAG_U10), x0)
EE_CFLAGS += -DPOPSLOADER_DIAG_U10
endif

.PHONY: FORCE

src/loader/bin/loader.elf:
	$(MAKE) src/loader

loader.c: src/loader/bin/loader.elf src/loader/src/loader.c FORCE
	$(BIN2C) src/loader/bin/loader.elf $@ loader_elf
	touch $@

all: loader.c $(EE_LIB)

clean:
	rm -f $(EE_LIB) $(EE_OBJS)

include $(PS2SDK)/samples/Makefile.pref
include $(PS2SDK)/samples/Makefile.eeglobal

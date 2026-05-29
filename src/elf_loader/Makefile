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

# Class B / U-10 exit diagnostic (GS_BGCOLOUR per-stage paint in
# LoadELFFromFileExecPS2RebootIOPWithPartition). Propagated from the
# parent Makefile so a single toggle there controls both the parent
# and this sub-make. Release builds MUST have EXIT_DEBUG_COLORS=0.
EXIT_DEBUG_COLORS ?= 0
ifeq ($(EXIT_DEBUG_COLORS),1)
EE_CFLAGS += -DEXIT_DEBUG_COLORS
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

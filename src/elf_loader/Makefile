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

# Enable HDD launch debug colors (GS background color stages)?
HDD_LAUNCH_DEBUG_COLORS ?= 0

ifneq (x$(HDD_LAUNCH_DEBUG_COLORS), x0)
EE_CFLAGS += -DHDD_LAUNCH_DEBUG_COLORS
endif

src/loader/bin/loader.elf:
	$(MAKE) src/loader

$(EE_OBJS_DIR)loader.c: src/loader/bin/loader.elf
	$(BIN2C) $< $@ loader_elf

all: $(EE_LIB)

clean:
	rm -f $(EE_LIB) $(EE_OBJS)

include $(PS2SDK)/samples/Makefile.pref
include $(PS2SDK)/samples/Makefile.eeglobal
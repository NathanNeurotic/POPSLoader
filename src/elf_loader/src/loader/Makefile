# _____     ___ ____     ___ ____
#  ____|   |    ____|   |        | |____|
# |     ___|   |____ ___|    ____| |    \    PS2DEV Open Source Project.
#-----------------------------------------------------------------------
# (c) 2020 Francisco Javier Trujillo Mata <fjtrujy@gmail.com>
# Licenced under Academic Free License version 2.0
# Review ps2sdk README & LICENSE files for further details.
BINDIR = bin/
EE_BIN = $(BINDIR)loader.elf
EE_ASM_DIR = asm/
EE_OBJS = src/loader.o $(EE_ASM_DIR)iomanX.o $(EE_ASM_DIR)fileXio.o
BIN2S = $(PS2SDK)/bin/bin2c

# Enable debug colors?
LOADER_ENABLE_DEBUG_COLORS ?= 0

# Use nano newlib for saving space
EE_NEWLIB_NANO ?= 1
EE_COMPACT_EXECUTABLE ?= 1

EE_LINKFILE ?= linkfile

ifneq (x$(LOADER_ENABLE_DEBUG_COLORS), x0)
EE_CFLAGS += -DLOADER_ENABLE_DEBUG_COLORS
endif

# Optional handoff debug logs (off by default)
LOADER_HANDOFF_DEBUG ?= 0
ifneq (x$(LOADER_HANDOFF_DEBUG), x0)
EE_CFLAGS += -DLOADER_HANDOFF_DEBUG
endif

all: $(EE_BIN) $(BINDIR)
$(BINDIR):
	mkdir $@

$(EE_ASM_DIR):
	mkdir $@

vpath %.irx $(PS2SDK)/iop/irx/
IRXTAG = $(subst -,_,$(notdir $(addsuffix _irx, $(basename $<))))

$(EE_ASM_DIR)%.c: %.irx | $(EE_ASM_DIR)
	$(BIN2S) $< $@ $(IRXTAG)

clean:
	rm -f $(EE_BIN) $(EE_OBJS)

include $(PS2SDK)/samples/Makefile.pref
include $(PS2SDK)/samples/Makefile.eeglobal

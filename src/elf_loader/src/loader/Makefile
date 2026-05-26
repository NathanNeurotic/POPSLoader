# _____     ___ ____     ___ ____
#  ____|   |    ____|   |        | |____|
# |     ___|   |____ ___|    ____| |    \    PS2DEV Open Source Project.
#-----------------------------------------------------------------------
# (c) 2020 Francisco Javier Trujillo Mata <fjtrujy@gmail.com>
# Licenced under Academic Free License version 2.0
# Review ps2sdk README & LICENSE files for further details.
BINDIR = bin/
EE_BIN = $(BINDIR)loader.elf
EE_OBJS = src/loader.o

# Enable debug colors?
# DIAG_U10 BRANCH: default flipped to 1 so the child loader paints
# background colors at each stage. To prune: revert this line to ?= 0
# OR delete the entire claude/diag-u10 branch.
LOADER_ENABLE_DEBUG_COLORS ?= 1

# Use nano newlib for saving space
EE_NEWLIB_NANO ?= 1
EE_COMPACT_EXECUTABLE ?= 1

EE_LINKFILE ?= linkfile

ifneq (x$(LOADER_ENABLE_DEBUG_COLORS), x0)
EE_CFLAGS += -DLOADER_ENABLE_DEBUG_COLORS
endif

EE_LIBS += -lfileXio

all: $(EE_BIN) $(BINDIR)
$(BINDIR):
	mkdir $@

clean:
	rm -f $(EE_BIN) $(EE_OBJS)

include $(PS2SDK)/samples/Makefile.pref
include $(PS2SDK)/samples/Makefile.eeglobal

IOP_BIN = popsbdm.irx
IOP_OBJS = popsbdm.o imports.o

IOP_IMPORT_INCS += \
	fs/bdm \
	system/iomanx \
	system/sysclib

IOP_INCS += -I$(PS2SDK)/iop/system/iomanx/include
IOP_CFLAGS += -I../../common

include $(PS2SDK)/Defs.make
include ../../modules/Rules.bin.make
include $(PS2SDK)/samples/Makefile.iopglobal

# ata_bd.irx, built from a vendored copy of ps2sdk's iop/dev9/atad/src/ps2atad.c.
#
# WHY VENDORED: upstream's iop/dev9/ata_bd/Makefile builds this by including
# $(PS2SDKSRC)/iop/dev9/atad/Makefile -- the SDK *source* tree, which the ps2dev
# build image does not carry (it ships the installed $(PS2SDK) only). So the one
# source file is vendored here and built with bdm_query's proven rules instead.
#
# THE DELTA vs upstream (see ps2atad.c, search "phantom slave"): the busy-wait
# ladder in gen_ata_wait_busy() ends in thirty 1-second sleeps, so a single wait
# can burn ~31s. A retail PS2's ATA bus has no slave drive, yet ata_init_devices
# still soft-resets and selects device 1 -- and each of those waits runs the
# ladder to the end. We cap the ladder at 100ms/step WHILE PROBING DEVICE 1 ONLY.
# Device 0 keeps the full ladder: a cold drive can need seconds to spin up.
#
# The config flags below mirror the SDK's ata_bd defaults exactly (BDM on, DEV9
# on, GameStar workaround on, AIF off) so this differs from the stock ata_bd.irx
# in the slave-probe timing and nothing else.

IOP_BIN = ata_bd.irx
IOP_OBJS = ps2atad.o imports.o exports.o

IOP_CFLAGS += -DATA_ENABLE_BDM=1
IOP_CFLAGS += -DATA_USE_DEV9=1
IOP_CFLAGS += -DATA_GAMESTAR_WORKAROUND=1

# atad.h is vendored alongside ps2atad.c so the build does not depend on the
# installed SDK exporting it.
IOP_INCS += -I.

IOP_IMPORT_INCS += \
	dev9/dev9 \
	fs/bdm \
	system/loadcore \
	system/stdio \
	system/sysclib \
	system/threadman

include $(PS2SDK)/Defs.make
include ../../modules/Rules.bin.make
include $(PS2SDK)/samples/Makefile.iopglobal

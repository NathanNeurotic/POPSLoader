.SILENT:                                                                              

define HEADER
                                                                       
   @@@@@@@@*#                                                              
  @@@# @@@@@@@ @@@@%                                                    
   @@@.@@@@@@@@@@@@@@@@@@*       &&&&&&&.                                
     ,@@@@@@@@        @@@@@@&&&&&&&&&&&&&&&&                            
       *@@@@@@@          &&&&&&&&&@&&&&&&&&&&&&                         
          @@@@@@@      &&&&&&&&@@@@@@@@&&&&&&&&&&       @@@@@@       
             /@@@@@   &&&&&&@@@@@@@@@@@@@@&&&&  &&&   @@@@@@@@@@     
                 @@@@@@&&&&@@@@@@@@@@@@@@@@@@     &&  @@@@@@@@@@     
                    @@&@@@&&@@@@@@@@@@@@@@@@@      && @@@@@@@@@@     
                     &&&@@@@@@&@@@@@@@@@@@@@@@    &&&   @@@@@@.      
                      &&&&&@@@@@@&&@@@@@@@@@@@@@&&&&&               
                      &&&&&&&@@@@@@@@@@@@@@@@@@&&&&&&@@@                
                       (&&&&&&&@@@@&@@@@@@@@@@&&&&&& #@@@@@.            
                         &&&&&&&&&@@@@@&&@@@&&&&&&&     @@@@@@/         
                           &&&&&&&&@@@@@@@@@&&&&&         @@@@@@@       
                              &&&&&&&&&&&&@@@@@@@@@        @@@@@@@@,    
                                   &&&&&&&,     @@@@@@@@@@@@@@@@@@@@@@
                                                        &@@@@ @@@@@@@.

                                            
                            Enceladus project                                                               
                                                                                
endef
export HEADER

#------------------------------------------------------------------#
#----------------------- Configuration flags ----------------------#
#------------------------------------------------------------------#
#-------------------------- Reset the IOP -------------------------#
RESET_IOP = 1
#---------------------- enable DEBUGGING MODE ---------------------#
DEBUG = 0
#----------------------- Set IP for PS2Client ---------------------#
PS2LINK_IP = 192.168.1.10
#------------------------------------------------------------------#

BINDIR = bin/
EE_BIN = $(BINDIR)enceladus.elf
EE_BIN_PKD = $(BINDIR)POPSLOADER.ELF

EE_LIBS = -L$(PS2SDK)/ports/lib -L$(PS2DEV)/gsKit/lib/ -Lmodules/ds34bt/ee/ -Lmodules/ds34usb/ee/ -lpatches -lfileXio -lpad -ldebug -llua -lmath3d -ljpeg -lfreetype -lgskit_toolkit -lgskit -ldmakit -lpng -lz -lmc -laudsrv  -lds34bt -lds34usb
EE_LIBS += src/elf_loader/libcustom-elf-loader.a
EE_INCS += -I$(PS2DEV)/gsKit/include -I$(PS2SDK)/ports/include -I$(PS2SDK)/ports/include/freetype2 -I$(PS2SDK)/ports/include/zlib
EE_INCS += -Imodules/ds34bt/ee -Imodules/ds34usb/ee

EE_CFLAGS   += -Wno-sign-compare -fno-strict-aliasing -fno-exceptions -DLUA_USE_PS2
EE_CXXFLAGS += -Wno-sign-compare -fno-strict-aliasing -fno-exceptions -DLUA_USE_PS2
EE_ASFLAGS += -call_shared
ifeq ($(RESET_IOP),1)
EE_CXXFLAGS += -DRESET_IOP
endif

ifeq ($(DEBUG),1)
EE_CXXFLAGS += -DDEBUG
endif

BIN2S = $(PS2SDK)/bin/bin2c

# Prefer python3, fallback to python if needed
PYTHON ?= $(shell command -v python3 2>/dev/null || command -v python 2>/dev/null)

# Hard fail early if neither interpreter exists
ifeq ($(PYTHON),)
$(error Python interpreter not found. Install python3 or provide PYTHON=/path/to/python)
endif

#-------------------------- App Content ---------------------------#
EXT_LIBS = modules/ds34usb/ee/libds34usb.a modules/ds34bt/ee/libds34bt.a

APP_CORE = main.o system.o pad.o graphics.o render.o \
		   calc_3d.o gsKit3d_sup.o atlas.o fntsys.o md5.o \
		   sound.o embedfs.o #strUtils.o

LUA_LIBS =	luaplayer.o luasound.o luacontrols.o \
			luatimer.o luaScreen.o luagraphics.o \
			luasystem.o luaRender.o luaHDD.o

IOP_MODULES = iomanX.o fileXio.o \
			  sio2man.o mcman.o mcserv.o padman.o libsd.o \
			  usbd.o audsrv.o bdm.o bdmfs_fatfs.o \
			  usbmass_bd.o cdfs.o ds34bt.o ds34usb.o \
			  ps2dev9.o ps2atad.o ps2hdd-osd.o ps2fs.o mmceman.o \
			  mx4sio_bd.o bdm_query.o

EMBEDDED_RSC = boot.o builtin_font.o embedded_assets.o

EE_OBJS = $(APP_CORE) $(LUA_LIBS) $(IOP_MODULES) $(EMBEDDED_RSC)

EE_OBJS_DIR = obj/
EE_SRC_DIR = src/
EE_ASM_DIR = asm/
EE_OBJS := $(EE_OBJS:%=$(EE_OBJS_DIR)%) # remap all EE_OBJ to obj subdir

#------------------------------------------------------------------#
all: $(EXT_LIBS) $(EE_BIN_PKD)
	@echo "$$HEADER"

$(EE_BIN_PKD): $(EE_BIN)
	$(EE_STRIP) $<
	ps2-packer $< $@ > /dev/null
#--------------------- Embedded ressources ------------------------#

$(EE_ASM_DIR)boot.c: etc/boot.lua | $(EE_ASM_DIR)
	echo "Embedding boot script..."
	$(BIN2S) $< $@ bootString

$(EE_ASM_DIR)embedded_assets.c: assets/embed_manifest.txt tools/gen_embed_assets.py | $(EE_ASM_DIR)
	$(PYTHON) tools/gen_embed_assets.py --manifest $< --output $@

# Images
$(EE_ASM_DIR)%.c: EMBED/%.png
	$(BIN2S) $< $@ $(shell basename $< .png)
$(EE_ASM_DIR)%.c: EMBED/%.ttf
	$(BIN2S) $< $@ $(shell basename $< .ttf)
#------------------------------------------------------------------#


#-------------------- Embedded IOP Modules ------------------------#

vpath %.irx iop/embed/
vpath %.irx $(PS2SDK)/iop/irx/
IRXTAG = $(subst -,_,$(notdir $(addsuffix _irx, $(basename $<))))

$(EE_ASM_DIR)%.c: %.irx | $(EE_ASM_DIR)
	$(BIN2S) $< $@ $(IRXTAG)


modules/ds34bt/ee/libds34bt.a: modules/ds34bt/ee
	$(MAKE) -C $<

modules/ds34bt/iop/ds34bt.irx: modules/ds34bt/iop
	$(MAKE) -C $<

$(EE_ASM_DIR)ds34bt.c: modules/ds34bt/iop/ds34bt.irx | $(EE_ASM_DIR)
	$(BIN2S) $< $@ ds34bt_irx

modules/ds34usb/ee/libds34usb.a: modules/ds34usb/ee
	$(MAKE) -C $<

modules/ds34usb/iop/ds34usb.irx: modules/ds34usb/iop
	$(MAKE) -C $<

$(EE_ASM_DIR)ds34usb.c: modules/ds34usb/iop/ds34usb.irx | $(EE_ASM_DIR)
	$(BIN2S) $< $@ ds34usb_irx

iop/bdm_query/bdm_query.irx: iop/bdm_query
	$(MAKE) -C $<

$(EE_ASM_DIR)bdm_query.c: iop/bdm_query/bdm_query.irx | $(EE_ASM_DIR)
	$(BIN2S) $< $@ bdm_query_irx

# PS2SDK MX4SIO IRX (embedded)
PS2SDK_MX4SIO_DIR = iop/embed/PS2SDK_MX4SIO

$(EE_ASM_DIR)mx4sio_bd.c: $(PS2SDK_MX4SIO_DIR)/mx4sio_bd.irx | $(EE_ASM_DIR)
	$(BIN2S) $< $@ mx4sio_bd_irx

#------------------------------------------------------------------#
elfloader: src/elf_loader/libcustom-elf-loader.a

src/elf_loader/libcustom-elf-loader.a: src/elf_loader
	@$(MAKE) cleanbin
	@$(MAKE) -C src/elf_loader/src/loader/ clean all
	@$(MAKE) -C src/elf_loader clean all

$(EE_OBJS_DIR):
	@mkdir -p $@

$(EE_ASM_DIR):
	@mkdir -p $@

debug: $(EE_BIN)
	echo "Building $(EE_BIN) with debug symbols..."

cleanbin:
	rm -f $(EE_BIN) $(EE_BIN_PKD)
clean: cleanbin
	rm -rf $(EE_OBJS_DIR)
	rm -rf $(EE_ASM_DIR)
	rm -f $(EE_ASM_DIR)embedded_assets.c

	rm -f $(EMBEDDED_RSC)

rebuild: clean all

run:
	cd bin; ps2client -h $(PS2LINK_IP) execee host:$(EE_BIN)
       
reset:
	ps2client -h $(PS2LINK_IP) reset   

POPSLDR_PKG = POPSLoader.zip
PKG_DIR = bin/package
package: $(EE_BIN_PKD)
	rm -f $(POPSLDR_PKG)
	rm -rf $(PKG_DIR)
	mkdir -p $(PKG_DIR)
	cp $(EE_BIN_PKD) $(PKG_DIR)/POPSLOADER.ELF
	cp bin/POPSLDR/POPSTARTER.ELF $(PKG_DIR)/
	cp bin/POPSLDR/icon.sys $(PKG_DIR)/
	cp bin/POPSLDR/list.icn $(PKG_DIR)/
	cp bin/POPSLDR/copy.icn $(PKG_DIR)/
	cp bin/POPSLDR/del.icn $(PKG_DIR)/
	cp bin/POPSLDR/APPINFO.PBT $(PKG_DIR)/
	cp bin/POPSLDR/title.cfg $(PKG_DIR)/
	cd $(PKG_DIR); 7z a -tzip ../$(POPSLDR_PKG) .
	cp bin/$(POPSLDR_PKG) ./$(POPSLDR_PKG)

verify: package
	$(PYTHON) tools/gen_embed_assets.py --check
	! grep -R "mass:/POPSLDR" -n etc/boot.lua bin/POPSLDR/*.lua
	! grep -R "mc0:/POPSLDR" -n etc/boot.lua bin/POPSLDR/*.lua
	grep -n "POPSLDR/IMG" src/system.cpp
	bash -lc 'set -euo pipefail; mapfile -t files < <(7z l POPSLoader.zip | awk "{print \$$NF}" | sed -n "s#^\(POPSLOADER\\.ELF\\|POPSTARTER\\.ELF\\|icon\\.sys\\|list\\.icn\\|copy\\.icn\\|del\\.icn\\|APPINFO\\.PBT\\|title\\.cfg\)$$#\\1#p"); mapfile -t all < <(7z l POPSLoader.zip | awk "{print \$$NF}" | rg -v "^Name$|^-------------------$|^$" || true); if [ "${#all[@]}" -ne 8 ]; then echo "Unexpected file count: ${#all[@]}"; printf "%s\n" "${all[@]}"; exit 1; fi; expected=(POPSLOADER.ELF POPSTARTER.ELF icon.sys list.icn copy.icn del.icn APPINFO.PBT title.cfg); for f in "${expected[@]}"; do printf "%s\n" "${all[@]}" | rg -qx "$f" || { echo "Missing $f"; exit 1; }; done'
	ls -lah bin/POPSLOADER.ELF

dummys:
	touch $(BINDIR)A.vcd
	touch $(BINDIR)B.VCD
	touch $(BINDIR)C.vcd
	touch $(BINDIR)D.VCD
	touch $(BINDIR)E.vcd
	touch $(BINDIR)F.VCD
	touch $(BINDIR)G.vcd
	touch $(BINDIR)H.VCD
	touch $(BINDIR)I.vcd
	touch $(BINDIR)J.VCD
	touch $(BINDIR)K.vcd
	touch $(BINDIR)L.VCD
	touch $(BINDIR)M.vcd
	touch $(BINDIR)N.VCD
	touch $(BINDIR)O.vcd
	touch $(BINDIR)P.VCD
	touch $(BINDIR)Q.vcd
	touch $(BINDIR)R.VCD
	touch $(BINDIR)S.vcd
	touch $(BINDIR)T.VCD
	touch $(BINDIR)U.VCD
	touch $(BINDIR)V.VCD
	touch $(BINDIR)W.VCD
	touch $(BINDIR)X.VCD
	touch $(BINDIR)Y.VCD

cleandummy:
	rm -rf bin/*.vcd
	rm -rf bin/*.VCD


$(EE_OBJS_DIR)%.o: $(EE_SRC_DIR)%.c | $(EE_OBJS_DIR)
	@echo "  - $@"
	@$(EE_CC) $(EE_CFLAGS) $(EE_INCS) -c $< -o $@

$(EE_OBJS_DIR)%.o: $(EE_ASM_DIR)%.s | $(EE_OBJS_DIR)
	@echo "  - $@"
	@$(EE_AS) $(EE_ASFLAGS) $< -o $@

$(EE_OBJS_DIR)%.o: $(EE_ASM_DIR)%.c | $(EE_OBJS_DIR)
	@echo "  - $@"
	@$(EE_CC) $(EE_CFLAGS) $(EE_INCS) -c $< -o $@

$(EE_OBJS_DIR)%.o: $(EE_SRC_DIR)%.cpp | $(EE_OBJS_DIR)
	@echo "  - $@"
	$(EE_CXX) $(EE_CXXFLAGS) $(EE_INCS) -c $< -o $@

include $(PS2SDK)/samples/Makefile.pref
include $(PS2SDK)/samples/Makefile.eeglobal

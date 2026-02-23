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

#-------------------------- App Content ---------------------------#
EXT_LIBS = modules/ds34usb/ee/libds34usb.a modules/ds34bt/ee/libds34bt.a

APP_CORE = main.o system.o pad.o graphics.o render.o \
		   calc_3d.o gsKit3d_sup.o atlas.o fntsys.o md5.o \
		   sound.o assets.o #strUtils.o

LUA_LIBS =	luaplayer.o luasound.o luacontrols.o \
			luatimer.o luaScreen.o luagraphics.o \
			luasystem.o luaRender.o luaHDD.o

IOP_MODULES = iomanX.o fileXio.o \
			  sio2man.o mcman.o mcserv.o padman.o libsd.o \
			  usbd.o audsrv.o bdm.o bdmfs_fatfs.o \
			  usbmass_bd.o cdfs.o ds34bt.o ds34usb.o \
			  ps2dev9.o ps2atad.o ps2hdd-osd.o ps2fs.o mmceman.o \
			  mx4sio_bd.o bdm_query.o

EMBED_LUA_FILES = bin/POPSLDR/system.lua bin/POPSLDR/ui.lua bin/POPSLDR/images.lua bin/POPSLDR/pops_profiles.lua
EMBED_AUDIO_FILES = bin/POPSLDR/boot.adp
EMBED_FONT_FILES = EMBED/builtin_font.ttf
EMBED_IMG_FILES = \
	bin/POPSLDR/IMG/APAHDD.png bin/POPSLDR/IMG/BDHDD.png bin/POPSLDR/IMG/BG.png bin/POPSLDR/IMG/BGM.png bin/POPSLDR/IMG/BKG.png \
	bin/POPSLDR/IMG/DISC.png bin/POPSLDR/IMG/HDD.png bin/POPSLDR/IMG/L1.png bin/POPSLDR/IMG/L2.png bin/POPSLDR/IMG/L3.png \
	bin/POPSLDR/IMG/MISSING.png bin/POPSLDR/IMG/MMCE.png bin/POPSLDR/IMG/MX4SIO.png bin/POPSLDR/IMG/PSL.png bin/POPSLDR/IMG/R1.png \
	bin/POPSLDR/IMG/R2.png bin/POPSLDR/IMG/R3.png bin/POPSLDR/IMG/SMB.png bin/POPSLDR/IMG/USB.png bin/POPSLDR/IMG/circle.png \
	bin/POPSLDR/IMG/cross.png bin/POPSLDR/IMG/down.png bin/POPSLDR/IMG/frame.png bin/POPSLDR/IMG/horz.png bin/POPSLDR/IMG/left.png \
	bin/POPSLDR/IMG/right.png bin/POPSLDR/IMG/select.png bin/POPSLDR/IMG/square.png bin/POPSLDR/IMG/start.png bin/POPSLDR/IMG/triangle.png \
	bin/POPSLDR/IMG/up.png bin/POPSLDR/IMG/vert.png
EMBED_IMG_OBJS = $(patsubst bin/POPSLDR/IMG/%.png,asset_bin_POPSLDR_IMG_%_png.o,$(EMBED_IMG_FILES))

EMBEDDED_RSC = boot.o builtin_font.o \
	asset_bin_POPSLDR_system_lua.o asset_bin_POPSLDR_ui_lua.o asset_bin_POPSLDR_images_lua.o asset_bin_POPSLDR_pops_profiles_lua.o \
	asset_bin_POPSLDR_boot_adp.o \
	$(EMBED_IMG_OBJS)

EE_OBJS = $(APP_CORE) $(LUA_LIBS) $(IOP_MODULES) $(EMBEDDED_RSC)

EE_OBJS_DIR = obj/
EE_SRC_DIR = src/
EE_ASM_DIR = asm/
EE_OBJS := $(EE_OBJS:%=$(EE_OBJS_DIR)%) # remap all EE_OBJ to obj subdir

#------------------------------------------------------------------#
all: embed-verify-assets $(EXT_LIBS) $(EE_BIN_PKD)
	@echo "$$HEADER"

$(EE_BIN_PKD): $(EE_BIN)
	$(EE_STRIP) $<
	ps2-packer $< $@ > /dev/null
#--------------------- Embedded ressources ------------------------#

$(EE_ASM_DIR)boot.c: etc/boot.lua | $(EE_ASM_DIR)
	echo "Embedding boot script..."
	$(BIN2S) $< $@ bootString

# Images
$(EE_ASM_DIR)%.c: EMBED/%.png
	$(BIN2S) $< $@ $(shell basename $< .png)
$(EE_ASM_DIR)%.c: EMBED/%.ttf
	$(BIN2S) $< $@ $(shell basename $< .ttf)
#------------------------------------------------------------------#

$(EE_ASM_DIR)asset_bin_POPSLDR_system_lua.c: bin/POPSLDR/system.lua | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_bin_POPSLDR_system_lua
$(EE_ASM_DIR)asset_bin_POPSLDR_ui_lua.c: bin/POPSLDR/ui.lua | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_bin_POPSLDR_ui_lua
$(EE_ASM_DIR)asset_bin_POPSLDR_images_lua.c: bin/POPSLDR/images.lua | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_bin_POPSLDR_images_lua
$(EE_ASM_DIR)asset_bin_POPSLDR_pops_profiles_lua.c: bin/POPSLDR/pops_profiles.lua | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_bin_POPSLDR_pops_profiles_lua
$(EE_ASM_DIR)asset_bin_POPSLDR_boot_adp.c: bin/POPSLDR/boot.adp | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_bin_POPSLDR_boot_adp

define GEN_POPSLDR_IMG_RULE
$(EE_ASM_DIR)asset_bin_POPSLDR_IMG_$(basename $(notdir $(1)))_png.c: $(1) | $(EE_ASM_DIR)
	$(BIN2S) $$< $$@ asset_bin_POPSLDR_IMG_$(basename $(notdir $(1)))_png
endef
$(foreach _img,$(EMBED_IMG_FILES),$(eval $(call GEN_POPSLDR_IMG_RULE,$(_img))))

embed-verify-assets:
	@missing=0; \
	for f in $(EMBED_LUA_FILES) $(EMBED_AUDIO_FILES) $(EMBED_FONT_FILES) $(EMBED_IMG_FILES); do \
		if [ ! -f "$$f" ]; then echo "MISSING: $$f"; missing=1; fi; \
	done; \
	test $$missing -eq 0


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

	rm -f $(EMBEDDED_RSC)

rebuild: clean all

embed-toolchain-report:
	@echo "objcopy: $(EE_OBJCOPY)"
	@$(EE_OBJCOPY) --help | sed -n "1,80p"
	@echo "main.o header:"
	@$(EE_READELF) -h $(EE_OBJS_DIR)main.o
	@echo "embedded object header:"
	@$(EE_READELF) -h $(EE_OBJS_DIR)asset_bin_POPSLDR_system_lua.o

run:
	cd bin; ps2client -h $(PS2LINK_IP) execee host:$(EE_BIN)
       
reset:
	ps2client -h $(PS2LINK_IP) reset   

POPSLDR_PKG = APP_POPSLOADER.zip
PKG_DIR = dist
PKG_APP_DIR = $(PKG_DIR)/APP_POPSLOADER
package: $(EE_BIN_PKD)
	rm -f $(POPSLDR_PKG)
	rm -rf $(PKG_DIR)
	mkdir -p $(PKG_APP_DIR)
	cp $(EE_BIN_PKD) $(PKG_APP_DIR)/POPSLOADER.ELF
	cd $(PKG_DIR); 7z a -tzip ../$(POPSLDR_PKG) APP_POPSLOADER

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

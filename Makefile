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
#- Embedded child-loader stage-color diagnostic (GS BGCOLOUR per stage).#
#- 0 = release/off. Set to 1 only for a tester build that needs the     #
#- child loader to paint its stage so a frozen color names the failing  #
#- step (e.g. the custom-HDD-path DKWDRV investigation). MUST be 0 for   #
#- any build that ships.                                                 #
LOADER_ENABLE_DEBUG_COLORS = 0
#----------------------- Set IP for PS2Client ---------------------#
PS2LINK_IP = 192.168.1.10
#------------------------------------------------------------------#

BINDIR = bin/
EE_BIN = $(BINDIR)enceladus.elf
EE_BIN_PKD = $(BINDIR)POPSLOADER.ELF

EE_LIBS = -L$(PS2SDK)/ports/lib -L$(PS2DEV)/gsKit/lib/ -Lmodules/ds34bt/ee/ -Lmodules/ds34usb/ee/ -lpatches -lfileXio -lpad -ldebug -llua -ljpeg -lfreetype -lgskit_toolkit -lgskit -ldmakit -lpng -lz -lmc -laudsrv  -lds34bt -lds34usb -lnetman -lps2ips
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

# `default.png` is an optional legacy cover override. When absent from the checkout
# it is simply not embedded; the game-list cover box uses cover_default.png (+
# cover_missing.png overlay) for the no-cover / preview-off states.
OPTIONAL_EMBEDDED_RSC =
ifneq ($(wildcard bin/POPSLDR/IMG/default.png),)
OPTIONAL_EMBEDDED_RSC += asset_default_png.o
EE_CXXFLAGS += -DHAVE_ASSET_DEFAULT_PNG=1
endif

#-------------------------- App Content ---------------------------#
EXT_LIBS = modules/ds34usb/ee/libds34usb.a modules/ds34bt/ee/libds34bt.a

APP_CORE = main.o system.o pad.o graphics.o \
		   atlas.o fntsys.o embed_assets.o \
		   sound.o

LUA_LIBS =	luaplayer.o luasound.o luacontrols.o \
			luatimer.o luaScreen.o luagraphics.o \
			luasystem.o luaHDD.o

IOP_MODULES = iomanX.o fileXio.o \
			  sio2man.o mcman.o mcserv.o padman.o libsd.o \
			  usbd.o audsrv.o bdm.o bdmfs_fatfs.o \
			  usbmass_bd.o cdfs.o ds34bt.o ds34usb.o \
			  ps2dev9.o ps2atad.o ps2hdd-osd.o ps2fs.o mmceman.o \
			  mx4sio_bd.o ata_bd.o bdm_query.o

# Menu-side SMB network stack (Increment 1). LAZY -- loaded by EnsureNet in
# luasystem.cpp only on SMB-page entry, NEVER at boot (main.cpp boot-loads only its
# explicit core set, not all of IOP_MODULES). ps2ip is the netman variant
# (ps2ip-nm.irx) via the explicit rule below, bin2c'd as the symbol ps2ip_irx.
IOP_MODULES += netman.o smap.o ps2ips.o smbman.o ps2ip.o

EMBEDDED_RSC = boot.o builtin_font.o \
	asset_usb_png.o asset_smb_png.o asset_ilink_png.o asset_mmce_png.o asset_mx4sio_png.o asset_apahdd_png.o \
	asset_bdhdd_png.o asset_bg_png.o asset_bkg_png.o asset_bgm_png.o asset_disc_png.o asset_splash_bg_png.o \
	asset_splash_logo_png.o asset_splash_appname_png.o asset_splash_credits_png.o asset_select_png.o \
	asset_start_png.o asset_triangle_png.o asset_circle_png.o asset_cross_png.o asset_square_png.o \
	asset_frame_png.o asset_cover_default_png.o asset_cover_missing_png.o $(OPTIONAL_EMBEDDED_RSC) \
	asset_system_lua.o asset_ui_lua.o asset_images_lua.o asset_pops_profiles_lua.o asset_boot_adp.o \
	asset_usbd_irx_usbexfat.o asset_usbhdfsd_irx_usbexfat.o asset_usbhdfsd_irx_mx4sio.o \
	asset_usbd_irx_mmce.o asset_usbhdfsd_irx_mmce.o \
	asset_usbd_irx_ata.o asset_usbhdfsd_irx_ata.o \
	asset_icon_sys_bdma.o asset_list_icn_bdma.o asset_del_icn_bdma.o \
	asset_smb_poweroff_irx.o asset_smb_ps2dev9_irx.o asset_smb_ps2ip_irx.o \
	asset_smb_ps2smap_irx.o asset_smb_smbman_irx.o asset_smb_smsutils_irx.o

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

# Images
$(EE_ASM_DIR)%.c: EMBED/%.png
	$(BIN2S) $< $@ $(shell basename $< .png)
$(EE_ASM_DIR)%.c: EMBED/%.ttf
	$(BIN2S) $< $@ $(shell basename $< .ttf)

$(EE_ASM_DIR)asset_usb_png.c: bin/POPSLDR/IMG/USB.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_usb_png
$(EE_ASM_DIR)asset_smb_png.c: bin/POPSLDR/IMG/SMB.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_smb_png
$(EE_ASM_DIR)asset_ilink_png.c: bin/POPSLDR/IMG/ILINK.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_ilink_png
$(EE_ASM_DIR)asset_mmce_png.c: bin/POPSLDR/IMG/MMCE.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_mmce_png
$(EE_ASM_DIR)asset_mx4sio_png.c: bin/POPSLDR/IMG/MX4SIO.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_mx4sio_png
$(EE_ASM_DIR)asset_apahdd_png.c: bin/POPSLDR/IMG/APAHDD.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_apahdd_png
$(EE_ASM_DIR)asset_bdhdd_png.c: bin/POPSLDR/IMG/BDHDD.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_bdhdd_png
$(EE_ASM_DIR)asset_bg_png.c: bin/POPSLDR/IMG/BG.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_bg_png
$(EE_ASM_DIR)asset_bkg_png.c: bin/POPSLDR/IMG/BKG.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_bkg_png
$(EE_ASM_DIR)asset_bgm_png.c: bin/POPSLDR/IMG/BGM.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_bgm_png
$(EE_ASM_DIR)asset_disc_png.c: bin/POPSLDR/IMG/DISC.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_disc_png
$(EE_ASM_DIR)asset_splash_bg_png.c: bin/POPSLDR/IMG/splash_bg.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_splash_bg_png
$(EE_ASM_DIR)asset_splash_logo_png.c: bin/POPSLDR/IMG/splash_logo.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_splash_logo_png
$(EE_ASM_DIR)asset_splash_appname_png.c: bin/POPSLDR/IMG/splash_appname.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_splash_appname_png
$(EE_ASM_DIR)asset_splash_credits_png.c: bin/POPSLDR/IMG/splash_credits.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_splash_credits_png
$(EE_ASM_DIR)asset_select_png.c: bin/POPSLDR/IMG/select.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_select_png
$(EE_ASM_DIR)asset_start_png.c: bin/POPSLDR/IMG/start.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_start_png
$(EE_ASM_DIR)asset_triangle_png.c: bin/POPSLDR/IMG/triangle.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_triangle_png
$(EE_ASM_DIR)asset_circle_png.c: bin/POPSLDR/IMG/circle.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_circle_png
$(EE_ASM_DIR)asset_cross_png.c: bin/POPSLDR/IMG/cross.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_cross_png
$(EE_ASM_DIR)asset_square_png.c: bin/POPSLDR/IMG/square.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_square_png
$(EE_ASM_DIR)asset_frame_png.c: bin/POPSLDR/IMG/frame.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_frame_png
$(EE_ASM_DIR)asset_default_png.c: bin/POPSLDR/IMG/default.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_default_png
$(EE_ASM_DIR)asset_cover_default_png.c: bin/POPSLDR/IMG/cover_default.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_cover_default_png
$(EE_ASM_DIR)asset_cover_missing_png.c: bin/POPSLDR/IMG/cover_missing.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_cover_missing_png

# Lua scripts
$(EE_ASM_DIR)asset_system_lua.c: bin/POPSLDR/system.lua | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_system_lua
$(EE_ASM_DIR)asset_ui_lua.c: bin/POPSLDR/ui.lua | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_ui_lua
$(EE_ASM_DIR)asset_images_lua.c: bin/POPSLDR/images.lua | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_images_lua
$(EE_ASM_DIR)asset_pops_profiles_lua.c: bin/POPSLDR/pops_profiles.lua | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_pops_profiles_lua
$(EE_ASM_DIR)asset_boot_adp.c: bin/POPSLDR/boot.adp | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_boot_adp

$(EE_ASM_DIR)asset_usbd_irx_usbexfat.c: bin/POPSLDR/usbd.irx.usbexfat | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_usbd_irx_usbexfat
$(EE_ASM_DIR)asset_usbhdfsd_irx_usbexfat.c: bin/POPSLDR/usbhdfsd.irx.usbexfat | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_usbhdfsd_irx_usbexfat
$(EE_ASM_DIR)asset_usbhdfsd_irx_mx4sio.c: bin/POPSLDR/usbhdfsd.irx.mx4sio | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_usbhdfsd_irx_mx4sio
$(EE_ASM_DIR)asset_usbd_irx_mmce.c: bin/POPSLDR/usbd.irx.mmce | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_usbd_irx_mmce
$(EE_ASM_DIR)asset_usbhdfsd_irx_mmce.c: bin/POPSLDR/usbhdfsd.irx.mmce | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_usbhdfsd_irx_mmce
$(EE_ASM_DIR)asset_usbd_irx_ata.c: bin/POPSLDR/usbd.irx.ata | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_usbd_irx_ata
$(EE_ASM_DIR)asset_usbhdfsd_irx_ata.c: bin/POPSLDR/usbhdfsd.irx.ata | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_usbhdfsd_irx_ata
$(EE_ASM_DIR)asset_icon_sys_bdma.c: bin/POPSLDR/icon.sys.bdma | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_icon_sys_bdma
$(EE_ASM_DIR)asset_list_icn_bdma.c: bin/POPSLDR/list.icn.bdma | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_list_icn_bdma
$(EE_ASM_DIR)asset_del_icn_bdma.c: bin/POPSLDR/del.icn.bdma | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_del_icn_bdma

# SMB streaming pack (popsmb/) -- embedded into the ELF; PLDR.ApplySmbModules stages
# these to mc?:/POPSTARTER/ when SMB modules are turned on. Explicit rules (more
# specific than the generic `vpath %.irx` rule below) + the popsmb/ source path keep
# them distinct from the IOP boot modules ps2dev9.o / ps2ip.o (which resolve via vpath).
$(EE_ASM_DIR)asset_smb_poweroff_irx.c: bin/POPSLDR/popsmb/poweroff.irx | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_smb_poweroff_irx
$(EE_ASM_DIR)asset_smb_ps2dev9_irx.c: bin/POPSLDR/popsmb/ps2dev9.irx | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_smb_ps2dev9_irx
$(EE_ASM_DIR)asset_smb_ps2ip_irx.c: bin/POPSLDR/popsmb/ps2ip.irx | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_smb_ps2ip_irx
$(EE_ASM_DIR)asset_smb_ps2smap_irx.c: bin/POPSLDR/popsmb/ps2smap.irx | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_smb_ps2smap_irx
$(EE_ASM_DIR)asset_smb_smbman_irx.c: bin/POPSLDR/popsmb/smbman.irx | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_smb_smbman_irx
$(EE_ASM_DIR)asset_smb_smsutils_irx.c: bin/POPSLDR/popsmb/SMSUTILS.irx | $(EE_ASM_DIR)
	$(BIN2S) $< $@ asset_smb_smsutils_irx

#------------------------------------------------------------------#


#-------------------- Embedded IOP Modules ------------------------#

vpath %.irx iop/embed/
vpath %.irx $(PS2SDK)/iop/irx/
IRXTAG = $(subst -,_,$(notdir $(addsuffix _irx, $(basename $<))))

# Menu SMB needs the netman ps2ip variant (ps2ip-nm.irx), bin2c'd as the symbol
# ps2ip_irx so the C extern matches. Explicit rule overrides the generic %.c:%.irx
# below (which would grab the wrong ps2ip.irx). Source resolves via the vpath above.
$(EE_ASM_DIR)ps2ip.c: ps2ip-nm.irx | $(EE_ASM_DIR)
	$(BIN2S) $< $@ ps2ip_irx

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
	@$(MAKE) -C src/elf_loader/src/loader/ LOADER_ENABLE_DEBUG_COLORS=$(LOADER_ENABLE_DEBUG_COLORS) clean all
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

rebuild: clean all

run:
	cd bin; ps2client -h $(PS2LINK_IP) execee host:$(EE_BIN)
       
reset:
	ps2client -h $(PS2LINK_IP) reset   

POPSLDR_PKG = POPSLoader.7z
PKG_DIR = bin/package
package: $(EE_BIN_PKD)
	rm -f $(POPSLDR_PKG)
	rm -rf $(PKG_DIR)
	mkdir -p $(PKG_DIR)
	cp $(EE_BIN_PKD) $(PKG_DIR)/
	cp bin/changelog LICENSE README.md $(PKG_DIR)/
	find bin/POPSLDR -maxdepth 1 -type f -exec cp {} $(PKG_DIR)/ \;
	@if [ -d bin/POPSTARTER ]; then cp -r bin/POPSTARTER $(PKG_DIR)/; fi
	@if ls bin/POPSLDR/IMG/*.png >/dev/null 2>&1; then cp bin/POPSLDR/IMG/*.png $(PKG_DIR)/; fi
	@if ls bin/POPSLDR/IRX/*.irx >/dev/null 2>&1; then cp bin/POPSLDR/IRX/*.irx $(PKG_DIR)/; fi
	cd $(PKG_DIR); 7z a ../$(POPSLDR_PKG) .

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

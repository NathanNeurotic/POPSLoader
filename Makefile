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
EE_OBJCOPY ?= mips64r5900el-ps2-elf-objcopy
EE_READELF ?= mips64r5900el-ps2-elf-readelf
EE_OBJDUMP ?= mips64r5900el-ps2-elf-objdump
EE_OBJCOPY_ELF_FMT ?= elf32-tradlittlemips
EE_OBJCOPY_BFDARCH ?= mips:5900

#-------------------------- App Content ---------------------------#
EXT_LIBS = modules/ds34usb/ee/libds34usb.a modules/ds34bt/ee/libds34bt.a

APP_CORE = main.o system.o asset_loader.o embedded_registry.o pad.o graphics.o render.o \
		   calc_3d.o gsKit3d_sup.o atlas.o fntsys.o md5.o \
		   sound.o #strUtils.o

LUA_LIBS =	luaplayer.o luasound.o luacontrols.o \
			luatimer.o luaScreen.o luagraphics.o \
			luasystem.o luaRender.o luaHDD.o

IOP_MODULES = iomanX.o fileXio.o \
			  sio2man.o mcman.o mcserv.o padman.o libsd.o \
			  usbd.o audsrv.o bdm.o bdmfs_fatfs.o \
			  usbmass_bd.o cdfs.o ds34bt.o ds34usb.o \
			  ps2dev9.o ps2atad.o ps2hdd-osd.o ps2fs.o mmceman.o \
			  mx4sio_bd.o bdm_query.o

EMBEDDED_RSC = builtin_font.o

EMBED_ASSET_DIR = $(EE_ASM_DIR)embedded
EMBED_ASSET_TMP = $(EMBED_ASSET_DIR)/tmp
EMBED_SRCS = \
	etc/boot.lua \
	bin/POPSLDR/system.lua \
	bin/POPSLDR/ui.lua \
	bin/POPSLDR/images.lua \
	bin/POPSLDR/pops_profiles.lua \
	bin/POPSLDR/IMG/images.lua \
	bin/POPSLDR/boot.adp \
	$(wildcard bin/POPSLDR/IMG/*.png)

sanitize = $(shell printf '%s' '$(1)' | sed 's/[^A-Za-z0-9]/_/g')
EMBED_STEMS = $(foreach f,$(EMBED_SRCS),$(call sanitize,$(f)))
EMBED_ASSET_OBJS = $(foreach f,$(EMBED_SRCS),embed_asset_$(call sanitize,$(f)).o)

EE_OBJS = $(APP_CORE) $(LUA_LIBS) $(IOP_MODULES) $(EMBEDDED_RSC) $(EMBED_ASSET_OBJS)

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

$(EE_ASM_DIR)embedded_registry.generated.h: $(EMBED_SRCS) | $(EE_ASM_DIR)
	@echo "Generating $@ (no python)..."
	@{ \
		echo "// generated; do not edit"; \
		echo "struct EmbeddedEntryDef { const char* path; const unsigned char* start; unsigned int size; bool compressed; };"; \
		for asset in $(EMBED_SRCS); do \
			stem=$$(printf '%s' "$$asset" | sed 's/[^A-Za-z0-9]/_/g'); \
			sym=$$(printf '%s' "$(EMBED_ASSET_TMP)/$$stem.gz" | sed 's/[^A-Za-z0-9]/_/g'); \
			echo "extern const unsigned char _binary_$${sym}_start[];"; \
			echo "extern const unsigned char _binary_$${sym}_end[];"; \
		done; \
		echo "static const EmbeddedEntryDef kEmbeddedEntries[] = {"; \
		for asset in $(EMBED_SRCS); do \
			stem=$$(printf '%s' "$$asset" | sed 's/[^A-Za-z0-9]/_/g'); \
			sym=$$(printf '%s' "$(EMBED_ASSET_TMP)/$$stem.gz" | sed 's/[^A-Za-z0-9]/_/g'); \
			if printf '%s' "$$asset" | grep -q '^bin/POPSLDR/'; then \
				rel=$${asset#bin/POPSLDR/}; \
				printf '    {"%s", _binary_%s_start, (unsigned int)(_binary_%s_end - _binary_%s_start), true},\n' "$$asset" "$$sym" "$$sym" "$$sym"; \
				printf '    {"%s", _binary_%s_start, (unsigned int)(_binary_%s_end - _binary_%s_start), true},\n' "$$rel" "$$sym" "$$sym" "$$sym"; \
				printf '    {"POPSLDR/%s", _binary_%s_start, (unsigned int)(_binary_%s_end - _binary_%s_start), true},\n' "$$rel" "$$sym" "$$sym" "$$sym"; \
			elif printf '%s' "$$asset" | grep -q '^etc/'; then \
				rel=$${asset#etc/}; \
				printf '    {"%s", _binary_%s_start, (unsigned int)(_binary_%s_end - _binary_%s_start), true},\n' "$$asset" "$$sym" "$$sym" "$$sym"; \
				printf '    {"%s", _binary_%s_start, (unsigned int)(_binary_%s_end - _binary_%s_start), true},\n' "$$rel" "$$sym" "$$sym" "$$sym"; \
			else \
				printf '    {"%s", _binary_%s_start, (unsigned int)(_binary_%s_end - _binary_%s_start), true},\n' "$$asset" "$$sym" "$$sym" "$$sym"; \
			fi; \
		done; \
		echo "};"; \
	} > "$@"

$(EMBED_ASSET_TMP):
	@mkdir -p $@

embed-assets-check:
	@echo "Embedded assets:"; \
	for a in $(EMBED_SRCS); do echo "  $$a"; done
	@echo "Embedded objects:"; \
	for o in $(EMBED_ASSET_OBJS); do echo "  $(EE_OBJS_DIR)$$o"; done
	@for a in $(EMBED_SRCS); do test -f "$$a" || { echo "Missing embedded asset: $$a"; exit 1; }; done

embed-rule-sample:
	@$(MAKE) -n $(EE_OBJS_DIR)embed_asset_etc_boot_lua.o

embed-abi-check: $(EE_OBJS_DIR)main.o $(EE_OBJS_DIR)embed_asset_etc_boot_lua.o
	@echo "== ABI check: normal object ($(EE_OBJS_DIR)main.o) =="
	@$(EE_READELF) -h $(EE_OBJS_DIR)main.o
	@$(EE_READELF) -A $(EE_OBJS_DIR)main.o 2>/dev/null || true
	@$(EE_OBJDUMP) -f $(EE_OBJS_DIR)main.o
	@echo "== ABI check: embedded object ($(EE_OBJS_DIR)embed_asset_etc_boot_lua.o) =="
	@$(EE_READELF) -h $(EE_OBJS_DIR)embed_asset_etc_boot_lua.o
	@$(EE_READELF) -A $(EE_OBJS_DIR)embed_asset_etc_boot_lua.o 2>/dev/null || true
	@$(EE_OBJDUMP) -f $(EE_OBJS_DIR)embed_asset_etc_boot_lua.o
	@set -eu; 	n_hdr="$(EE_OBJS_DIR)main.o"; e_hdr="$(EE_OBJS_DIR)embed_asset_etc_boot_lua.o"; 	n_class=`$(EE_READELF) -h $$n_hdr | sed -n 's/^ *Class: *//p'`; 	e_class=`$(EE_READELF) -h $$e_hdr | sed -n 's/^ *Class: *//p'`; 	n_data=`$(EE_READELF) -h $$n_hdr | sed -n 's/^ *Data: *//p'`; 	e_data=`$(EE_READELF) -h $$e_hdr | sed -n 's/^ *Data: *//p'`; 	n_machine=`$(EE_READELF) -h $$n_hdr | sed -n 's/^ *Machine: *//p'`; 	e_machine=`$(EE_READELF) -h $$e_hdr | sed -n 's/^ *Machine: *//p'`; 	n_flags=`$(EE_READELF) -h $$n_hdr | sed -n 's/^ *Flags: *//p'`; 	e_flags=`$(EE_READELF) -h $$e_hdr | sed -n 's/^ *Flags: *//p'`; 	[ "$$n_class" = "$$e_class" ] || { echo "ABI mismatch: Class"; exit 1; }; 	[ "$$n_data" = "$$e_data" ] || { echo "ABI mismatch: Data"; exit 1; }; 	[ "$$n_machine" = "$$e_machine" ] || { echo "ABI mismatch: Machine"; exit 1; }; 	[ "$$n_flags" = "$$e_flags" ] || { echo "ABI mismatch: Flags"; exit 1; }


define EMBED_OBJ_RULE
$(EE_OBJS_DIR)embed_asset_$(call sanitize,$(1)).o: $(1) | $(EE_OBJS_DIR) $(EMBED_ASSET_TMP)
	@echo "  - $$@"
	@set -eu; \
	mkdir -p "$(EE_OBJS_DIR)" "$(EMBED_ASSET_TMP)" "$(EE_ASM_DIR)"; \
	test -f "$$<" || { echo "Missing embedded asset: $$<"; exit 1; }; \
	gz="$(EMBED_ASSET_TMP)/$(call sanitize,$(1)).gz"; \
	gzip -n -9 -c "$$<" > "$$$$gz"; \
	$(EE_OBJCOPY) -I binary -O $(EE_OBJCOPY_ELF_FMT) --binary-architecture=$(EE_OBJCOPY_BFDARCH) "$$$$gz" "$$@"; \
	rm -f "$$$$gz"
endef

$(foreach a,$(EMBED_SRCS),$(eval $(call EMBED_OBJ_RULE,$(a))))

# Embedded resources built as C translation units (non-asset-pack path)
# Keep these generic rules so objects like obj/builtin_font.o resolve from EMBED/builtin_font.ttf.
$(EE_ASM_DIR)%.c: EMBED/%.png | $(EE_ASM_DIR)
	$(BIN2S) $< $@ $(shell basename $< .png)

$(EE_ASM_DIR)%.c: EMBED/%.ttf | $(EE_ASM_DIR)
	$(BIN2S) $< $@ $(shell basename $< .ttf)

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
	rm -rf $(EMBED_ASSET_DIR)

	rm -f $(EMBEDDED_RSC)

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


$(EE_OBJS_DIR)embedded_registry.o: $(EE_SRC_DIR)embedded_registry.cpp $(EE_ASM_DIR)embedded_registry.generated.h | $(EE_OBJS_DIR)
	@echo "  - $@"
	$(EE_CXX) $(EE_CXXFLAGS) $(EE_INCS) -c $< -o $@

include $(PS2SDK)/samples/Makefile.pref
include $(PS2SDK)/samples/Makefile.eeglobal

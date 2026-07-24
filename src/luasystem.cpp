#include <stdio.h>
#include <unistd.h>
#include <libmc.h>
#include <malloc.h>
#include <sys/fcntl.h>
#include <dirent.h>
#include <sys/stat.h>
#include <sifrpc.h>
#include <kernel.h>    // ee_thread_t / CreateThread / StartThread / ExitDeleteThread for the async ata_bd worker
#include <iopheap.h>   // SifAllocIopHeap/SifFreeIopHeap for the 128 KiB BDM-cache probe
#include <string.h>
#define NEWLIB_PORT_AWARE
#include <fileXio_rpc.h>
#include <fileio.h>
#include "include/luaplayer.h"
#include "include/graphics.h"
#include "include/embed_assets.h"

#include "include/system.h"
#include "include/dprintf.h"

// Menu-side SMB (Increment 1). ps2sdk network headers. Wrapped in extern "C": this
// is a C++ TU and these headers don't all guard their decls, so without it NetManInit/
// NetManIoctl/NetManSetLinkMode/ps2ip_init references get C++-mangled and fail to link
// against the plain-C libnetman/libps2ips. ps2ip.h stays for the header-only ip4 types
// (struct ip4_addr / IP4_ADDR / ip_addr_set) SmbApplyIPConfig uses; ps2ips.h is the
// RPC client to the IOP-side stack -- the one smbman actually uses (see EnsureNet).
extern "C" {
#include <ps2ip.h>
#include <ps2ips.h>
#include <netman.h>
#include <ps2smb.h>
}

#define MAX_DIR_FILES 512

extern unsigned char mx4sio_bd_irx[];
extern unsigned int size_mx4sio_bd_irx;
extern unsigned char ata_bd_irx[];
extern unsigned int size_ata_bd_irx;
extern unsigned char bdm_query_irx[];
extern unsigned int size_bdm_query_irx;

extern unsigned char bdm_irx[];
extern unsigned int size_bdm_irx;
extern unsigned char bdmfs_fatfs_irx[];
extern unsigned int size_bdmfs_fatfs_irx;
extern unsigned char usbmass_bd_irx[];
extern unsigned int size_usbmass_bd_irx;
extern unsigned char cdfs_irx[];
extern unsigned int size_cdfs_irx;

extern unsigned char mmceman_irx[];
extern unsigned int size_mmceman_irx;

// Menu-side SMB network stack (lazy; see EnsureNet/EnsureSMB below).
extern unsigned char netman_irx[];   extern unsigned int size_netman_irx;
extern unsigned char smap_irx[];     extern unsigned int size_smap_irx;
extern unsigned char ps2ip_irx[];    extern unsigned int size_ps2ip_irx;   // ps2ip-nm.irx (Makefile explicit rule)
extern unsigned char ps2ips_irx[];   extern unsigned int size_ps2ips_irx;
extern unsigned char smbman_irx[];   extern unsigned int size_smbman_irx;
// SMSUTILS reused from the embedded popsmb pack (embed_assets.cpp).
extern unsigned char asset_smb_smsutils_irx[];  extern unsigned int size_asset_smb_smsutils_irx;
// ps2dev9 is the IOP_MODULES buffer also loaded by the HDD path (luaHDD.cpp).
extern unsigned char ps2dev9_irx[];  extern unsigned int size_ps2dev9_irx;

extern int pad_reinit();


static bool LoadIrxCheckedBuffer(const char *name, unsigned char *irx, unsigned int size, int *out_id, int *out_ret);
static void BuildMassRootPath(int index, char *out_root, size_t out_sz);
static bool EnsureDev9();   // defined below (with the SMB block); load-once via g_dev9_loaded

#ifndef USBMASS_IOCTL_GET_DRIVERNAME
#define USBMASS_IOCTL_GET_DRIVERNAME 0x0003
#endif

#define BDM_QUERY_RPC_ID 0xB0D10B00
#define BDM_QUERY_RPC_GET_LIST 0
#define BDM_QUERY_MAX_DEVICES 32

typedef struct bdm_dev_info {
	char name[32];
	u32 devNr;
	u32 parNr;
	u8 parId;
	u32 sectorSize;
	u64 sectorCount;
} bdm_dev_info_t;

typedef struct bdm_dev_list {
	u32 count;
	bdm_dev_info_t devs[BDM_QUERY_MAX_DEVICES];
} bdm_dev_list_t;

static SifRpcClientData_t bdm_rpc_client;
static bool bdm_rpc_bound = false;
static bool bdm_rpc_loaded = false;
static bdm_dev_list_t bdm_rpc_buffer __attribute__((aligned(64)));
static bdm_dev_list_t mass_backend_cache;
static bool mass_backend_cache_valid = false;

static bool bdm_irx_loaded = false;
static bool bdm_fatfs_irx_loaded = false;
static bool usbmass_irx_loaded = false;

// USB bring-up diagnostics. Every LoadIrxCheckedBuffer below used to pass
// NULL,NULL and throw the IRX return codes away, and main.cpp's usbd load goes
// through LOAD_IRX_NARG whose only consumer is DPRINTF -- which compiles to
// nothing in a release build. So when a tester reports "No USB backend
// detected" we have had literally no way to tell a failed module load apart
// from a drive that never enumerated. Two "root cause found" fixes have now
// been shipped and refuted on hardware because of that blind spot. Record the
// codes and let the UI show them.
// -999 = "never attempted" (distinct from a real negative rc).
int g_usbd_load_id = -999;   // written by main.cpp at boot
int g_usbd_load_ret = -999;
static int g_bdm_id = -999, g_bdm_ret = -999;
static int g_bdmfs_id = -999, g_bdmfs_ret = -999;
static int g_usbmass_id = -999, g_usbmass_ret = -999;
static bool cdfs_irx_loaded = false;
static bool mx4sio_irx_loaded = false;
static bool mmceman_irx_loaded = false;

static bool EnsureBDM()
{
	if (bdm_irx_loaded) {
		return true;
	}
	if (!LoadIrxCheckedBuffer("bdm.irx", bdm_irx, size_bdm_irx, &g_bdm_id, &g_bdm_ret)) {
		return false;
	}
	bdm_irx_loaded = true;
	return true;
}

static bool EnsureBDMFatFs()
{
	if (bdm_fatfs_irx_loaded) {
		return true;
	}
	if (!EnsureBDM()) {
		return false;
	}
	if (!LoadIrxCheckedBuffer("bdmfs_fatfs.irx", bdmfs_fatfs_irx, size_bdmfs_fatfs_irx, &g_bdmfs_id, &g_bdmfs_ret)) {
		return false;
	}
	bdm_fatfs_irx_loaded = true;
	return true;
}

// Non-static so main.cpp can bring the USB mass stack up at BOOT, adjacent to
// usbd, instead of minutes later on USB-page entry. Idempotent via the latches
// below, so the later Lua-side call becomes a no-op -- which MATTERS: loading a
// second copy of a block driver onto a live bus is the exact bug class that
// caused the old 42% ATA freeze.
bool EnsureUsbMass()
{
	if (usbmass_irx_loaded) {
		return true;
	}
	if (!EnsureBDMFatFs()) {
		return false;
	}
	// bdmfs_fatfs registers as the BDM filesystem provider; give it a moment to
	// settle before usbmass_bd starts producing block devices. Loading usbmass_bd
	// back-to-back races the not-yet-ready FS layer, so the first USB device connect
	// can fail to mount and no mass: root ever appears ("No USB backend detected",
	// deterministically, since usbmass_irx_loaded then latches and a menu rescan only
	// re-queries devices -- it never reloads/re-settles the modules). wLaunchELF_R3Z
	// (saildot4k's "all devices work" fork) does exactly this 1s settle here
	// (waitForUsbMassBdmfsSettle / USB_MASS_BDMFS_SETTLE_MS=1000), and our ATA path
	// already settles the same way after ata_bd. Mirror it for USB.
	sleep(1);
	if (!LoadIrxCheckedBuffer("usbmass_bd.irx", usbmass_bd_irx, size_usbmass_bd_irx, &g_usbmass_id, &g_usbmass_ret)) {
		return false;
	}
	usbmass_irx_loaded = true;
	return true;
}

static bool EnsureCDFS()
{
	if (cdfs_irx_loaded) {
		return true;
	}
	if (!LoadIrxCheckedBuffer("cdfs.irx", cdfs_irx, size_cdfs_irx, NULL, NULL)) {
		return false;
	}
	cdfs_irx_loaded = true;
	return true;
}

// Layer C lazy-load entry point for mmceman. main.cpp's boot sequence
// eagerly loads mmceman_irx ONLY when boot_device_hint == "MMCE"; for any
// other boot device (USB / MC / MX4SIO / HDD in any variant: hdd*, pfs*,
// ata*, apa* — see detectBootDeviceHintFromArgv0 in main.cpp), this is
// called on demand by PLDR.EnsureMmceReadyOnce in system.lua before any
// MMCE probe (PLDR.DetectMMCESlot). Idempotent: subsequent calls after a
// successful load are no-ops.
bool EnsureMmceman()
{
	if (mmceman_irx_loaded) {
		return true;
	}
	if (!LoadIrxCheckedBuffer("mmceman.irx", mmceman_irx, size_mmceman_irx, NULL, NULL)) {
		return false;
	}
	mmceman_irx_loaded = true;
	return true;
}

// Called from main.cpp when mmceman was loaded eagerly by the boot
// sequence (MMCE-booted case). Syncs the EnsureMmceman tracker so the
// Lua-side ensureMmceman() call later is a no-op instead of double-loading.
void MarkMmcemanLoaded()
{
	mmceman_irx_loaded = true;
}

// System.getSio2Owner(): which SIO2-bus storage driver is resident this
// session -- "" (neither), "MMCE" (mmceman), "MX4SIO" (mx4sio_bd), or "BOTH".
// EXP32: DIAGNOSTIC-ONLY. The Lua exclusion guards that read this are gone --
// mmceman and mx4sio_bd coexist (maintainer call, 2026-07-21: official OPL
// runs both resident on freesio2, which we carry since EXP31; the contrary
// R3Z3N /ACK-wiring position is recorded in system.lua as the fallback).
// Kept because it reads the load latches directly (cannot miss a C-internal
// load path) -- useful for future diagnostics and the harness contract tests.
static int lua_get_sio2_owner(lua_State *L)
{
	if (mmceman_irx_loaded && mx4sio_irx_loaded) {
		lua_pushstring(L, "BOTH");
	} else if (mmceman_irx_loaded) {
		lua_pushstring(L, "MMCE");
	} else if (mx4sio_irx_loaded) {
		lua_pushstring(L, "MX4SIO");
	} else {
		lua_pushstring(L, "");
	}
	return 1;
}

static bool EnsureBdmQueryRpc()
{
	if (!bdm_rpc_loaded) {
		if (!LoadIrxCheckedBuffer("bdm_query.irx", bdm_query_irx, size_bdm_query_irx, NULL, NULL)) {
			return false;
		}
		bdm_rpc_loaded = true;
	}
	if (!bdm_rpc_bound) {
		SifInitRpc(0);
		if (SifBindRpc(&bdm_rpc_client, BDM_QUERY_RPC_ID, 0) < 0) {
			DPRINTF("BDM query RPC bind failed\n");
			return false;
		}
		if (bdm_rpc_client.server == NULL) {
			DPRINTF("BDM query RPC server not ready\n");
			return false;
		}
		bdm_rpc_bound = true;
	}
	return true;
}

static bool FetchBdmList(bdm_dev_list_t *out)
{
	if (out == NULL) {
		return false;
	}
	if (!EnsureBdmQueryRpc()) {
		return false;
	}
	memset(&bdm_rpc_buffer, 0, sizeof(bdm_rpc_buffer));
	if (SifCallRpc(&bdm_rpc_client, BDM_QUERY_RPC_GET_LIST, 0, NULL, 0,
	               &bdm_rpc_buffer, sizeof(bdm_rpc_buffer), NULL, NULL) < 0) {
		DPRINTF("BDM query RPC call failed\n");
		return false;
	}
	memcpy(out, &bdm_rpc_buffer, sizeof(*out));
	return true;
}

static const char *ClassifyMassBackend(const char *driver)
{
	if (driver == NULL) {
		return NULL;
	}
	if (strstr(driver, "usb") != NULL) {
		return "usb";
	}
	if (strstr(driver, "sdc") != NULL || strstr(driver, "mx4") != NULL) {
		return "mx4sio";
	}
	if (strstr(driver, "mmce") != NULL) {
		return "mmce";
	}
	// EXACT match, mirroring OPL bdmsupport.c (!strcmp(driver,"ata") && strlen==3):
	// the BDM ata_bd block driver reports the name "ata" exactly. A substring test
	// would mis-catch "sata"/"atad" and could leak ata into the usb/mx4sio buckets
	// (or vice-versa). usb/sdc/mx4/mmce above keep their proven substring matches.
	if (strcmp(driver, "ata") == 0 && strlen(driver) == 3) {
		return "ata";
	}
	return "other";
}

static bool RefreshMassBackendCache()
{
	mass_backend_cache_valid = false;
	if (!FetchBdmList(&mass_backend_cache)) {
		return false;
	}
	mass_backend_cache_valid = true;
	return true;
}

static bool EnsureMassBackendCache()
{
	if (mass_backend_cache_valid) {
		return true;
	}
	return RefreshMassBackendCache();
}

static bool GetMassRootByBackendNameInternal(const char *backend_name, char *out_root, size_t out_sz)
{
	if (backend_name == NULL || backend_name[0] == '\0' || out_root == NULL || out_sz == 0) {
		return false;
	}

	mass_backend_cache_valid = false;
	bdm_rpc_bound = false;

	bdm_dev_list_t list;
	if (!FetchBdmList(&list)) {
		return false;
	}

	for (u32 i = 0; i < list.count; ++i) {
		const bdm_dev_info_t *info = &list.devs[i];
		if (strcmp(info->name, backend_name) == 0) {
			BuildMassRootPath((int)info->parId, out_root, out_sz);
			return true;
		}
	}

	return false;
}

static bool LoadIrxCheckedBuffer(const char *name, unsigned char *irx, unsigned int size, int *out_id, int *out_ret)
{
	int id = -1;
	int ret = -1;
	id = SifExecModuleBuffer(irx, size, 0, NULL, &ret);
	if (out_id) {
		*out_id = id;
	}
	if (out_ret) {
		*out_ret = ret;
	}
	if (id < 0 || ret < 0) {
		return false;
	}
	return true;
}

static void BuildMassRootPath(int index, char *out_root, size_t out_sz)
{
	if (index == 0) {
		snprintf(out_root, out_sz, "mass:/");
	} else {
		snprintf(out_root, out_sz, "mass%d:/", index);
	}
}

static bool ParseMassRootSlot(const char *root, int *out_slot)
{
	if (root == NULL || out_slot == NULL) {
		return false;
	}

	if (strcmp(root, "mass:/") == 0 || strcmp(root, "mass0:/") == 0) {
		*out_slot = 0;
		return true;
	}

	if (strncmp(root, "mass", 4) != 0) {
		return false;
	}

	const char *suffix = root + 4;
	if (suffix[0] < '1' || suffix[0] > '9' || suffix[1] != ':' || suffix[2] != '/' || suffix[3] != '\0') {
		return false;
	}

	*out_slot = suffix[0] - '0';
	return true;
}

static const char *GetMassMountDriverNameBySlot(int slot)
{
	static char driver[32];
	char root[16];

	if (slot < 0 || slot > 9) {
		return NULL;
	}

	BuildMassRootPath(slot, root, sizeof(root));

	int fd = fileXioDopen(root);
	if (fd < 0) {
		return NULL;
	}

	memset(driver, 0, sizeof(driver));
	int ret = fileXioIoctl2(fd, USBMASS_IOCTL_GET_DRIVERNAME, NULL, 0, driver, sizeof(driver));
	fileXioDclose(fd);
	if (ret >= 0 && driver[0] != '\0') {
		return driver;
	}

	return NULL;
}

static int lua_get_mass_mount_driver(lua_State *L)
{
	if (lua_gettop(L) != 1) {
		return luaL_error(L, "Argument error: System.getMassMountDriver(root) takes one argument.");
	}

	const char *root = luaL_checkstring(L, 1);
	int slot = -1;
	if (!ParseMassRootSlot(root, &slot)) {
		lua_pushnil(L);
		return 1;
	}

	const char *driver = GetMassMountDriverNameBySlot(slot);
	if (driver != NULL && driver[0] != '\0') {
		lua_pushstring(L, driver);
	} else {
		lua_pushnil(L);
	}

	return 1;
}

static void PushBdmInfo(lua_State *L, const bdm_dev_info_t *info)
{
	lua_newtable(L);
	lua_pushstring(L, info->name);
	lua_setfield(L, -2, "name");
	lua_pushinteger(L, info->devNr);
	lua_setfield(L, -2, "devNr");
	lua_pushinteger(L, info->parNr);
	lua_setfield(L, -2, "parNr");
	lua_pushinteger(L, info->parId);
	lua_setfield(L, -2, "parId");
	lua_pushinteger(L, info->sectorSize);
	lua_setfield(L, -2, "sectorSize");
	lua_pushnumber(L, (lua_Number)info->sectorCount);
	lua_setfield(L, -2, "sectorCount");
}

static int lua_bdm_list(lua_State *L)
{
	bdm_dev_list_t list;
	if (!FetchBdmList(&list)) {
		lua_pushnil(L);
		return 1;
	}
	DPRINTF("BDM list count=%u\n", list.count);
	lua_newtable(L);
	for (u32 i = 0; i < list.count; ++i) {
		const bdm_dev_info_t *info = &list.devs[i];
		DPRINTF("BDM device %u name=%s devNr=%u parNr=%u parId=%u sectorSize=%u sectorCount=%llu\n",
		        i, info->name, info->devNr, info->parNr, info->parId,
		        info->sectorSize, (unsigned long long)info->sectorCount);
		PushBdmInfo(L, info);
		lua_rawseti(L, -2, i + 1);
	}
	return 1;
}

static int lua_find_bdm_by_driver(lua_State *L)
{
	int argc = lua_gettop(L);
	if (argc != 1) {
		return luaL_error(L, "Argument error: System.findBDMByDriver(driverName) takes one argument.");
	}
	const char *driver = luaL_checkstring(L, 1);
	bdm_dev_list_t list;
	if (!FetchBdmList(&list)) {
		lua_pushnil(L);
		return 1;
	}
	for (u32 i = 0; i < list.count; ++i) {
		const bdm_dev_info_t *info = &list.devs[i];
		if (strcmp(info->name, driver) == 0) {
			PushBdmInfo(L, info);
			return 1;
		}
	}
	lua_pushnil(L);
	return 1;
}

static int lua_refresh_mass_backends(lua_State *L)
{
	bdm_rpc_bound = false;
	lua_pushboolean(L, RefreshMassBackendCache());
	return 1;
}

static int lua_get_mass_backend_info(lua_State *L)
{
	int argc = lua_gettop(L);
	if (argc != 1) {
		return luaL_error(L, "Argument error: System.getMassBackendInfo(index) takes one argument.");
	}
	int index = luaL_checkinteger(L, 1);
	if (!EnsureMassBackendCache()) {
		lua_pushnil(L);
		return 1;
	}
	for (u32 i = 0; i < mass_backend_cache.count; ++i) {
		const bdm_dev_info_t *info = &mass_backend_cache.devs[i];
		if ((int)info->devNr == index) {
			lua_newtable(L);
			lua_pushboolean(L, 1);
			lua_setfield(L, -2, "present");
			lua_pushstring(L, info->name);
			lua_setfield(L, -2, "driver");
			lua_pushstring(L, ClassifyMassBackend(info->name));
			lua_setfield(L, -2, "kind");
			lua_pushinteger(L, info->devNr);
			lua_setfield(L, -2, "index");
			lua_pushinteger(L, info->parId);
			lua_setfield(L, -2, "parId");
			return 1;
		}
	}
	lua_pushnil(L);
	return 1;
}

static int lua_get_mass_root_by_backend_name(lua_State *L)
{
	int argc = lua_gettop(L);
	if (argc != 1) {
		return luaL_error(L, "Argument error: System.getMassRootByBackendName(name) takes one argument.");
	}

	const char *backend_name = luaL_checkstring(L, 1);
	char root[16];
	if (GetMassRootByBackendNameInternal(backend_name, root, sizeof(root))) {
		lua_pushstring(L, root);
		return 1;
	}

	lua_pushnil(L);
	return 1;
}



static int lua_getEmbeddedAsset(lua_State *L)
{
	int argc = lua_gettop(L);
	if (argc != 1) {
		return luaL_error(L, "Argument error: System.getEmbeddedAsset(name) takes one argument.");
	}
	const char *name = luaL_checkstring(L, 1);
	const uint8_t *data = NULL;
	size_t size = 0;
	if (embedded_get(name, &data, &size)) {
		lua_pushlstring(L, (const char *)data, size);
		return 1;
	}
	lua_pushnil(L);
	return 1;
}

static int lua_getCurrentDirectory(lua_State *L)
{
	char path[256];
	getcwd(path, 256);
	lua_pushstring(L, path);
	
	return 1;
}

static int lua_setCurrentDirectory(lua_State *L)
{
    static char temp_path[256];
	const char *path = luaL_checkstring(L, 1);
	if(!path) return luaL_error(L, "Argument error: System.currentDirectory(file) takes a filename as string as argument.");
	DPRINTF("Setting CWD to %s\n", path);
	lua_getCurrentDirectory(L);
	
	// let's do what the ps2sdk should do, 
	// some normalization... :)
	// if absolute path (contains [drive]:path/)
	if (strchr(path, ':'))
	{
	      strcpy(temp_path,path);
	}
	else // relative path
	{
	   // remove last directory ?
	   if(!strncmp(path, "..", 2))
	   {
	        getcwd(temp_path, 256);
	        if ((temp_path[strlen(temp_path)-1] != ':'))
	        {
	           int idx = strlen(temp_path)-1;
	           do
	           {
	                idx--;
	           } while (idx > 0 && temp_path[idx] != '/');
	           temp_path[idx] = '\0';
	        }
	        
        }
           // add given directory to the existing path
           else
        {
	      getcwd(temp_path, 256);
	      strcat(temp_path,"/");
	      strcat(temp_path,path);
	    }
    }
        
        DPRINTF("changing directory to %s\n",__ps2_normalize_path(temp_path));
        chdir(__ps2_normalize_path(temp_path));
       
	return 1;
}

static int lua_curdir(lua_State *L) {
	int argc = lua_gettop(L);
	if(argc == 0) return lua_getCurrentDirectory(L);
	if(argc == 1) return lua_setCurrentDirectory(L);
	return luaL_error(L, "Argument error: System.currentDirectory([file]) takes zero or one argument.");
}


static int lua_dir(lua_State *L)
{
	int argc = lua_gettop(L);
	if (argc != 0 && argc != 1) return luaL_error(L, "Argument error: System.listDirectory([path]) takes zero or one argument.");
	
        const char *temp_path = "";
	char path[256];
	
	getcwd((char *)path, 256);
	DPRINTF("current dir %s\n",(char *)path);
	
	if (argc != 0) 
	{
		temp_path = luaL_checkstring(L, 1);
		// append the given path to the boot_path
	        
	        strcpy ((char *)path, boot_path);
	        
	        if (strchr(temp_path, ':'))
	           // workaround in case of temp_path is containing 
	           // a device name again
	           strcpy ((char *)path, temp_path);
	        else
	           strcat ((char *)path, temp_path);
	}
	
	strcpy(path,__ps2_normalize_path(path));
	DPRINTF("\nchecking path : %s\n",path);
		

        
        //-----------------------------------------------------------------------------------------
	
	// read from MC ?
        
        if( !strcmp( path, "mc0:" ) || !strcmp( path, "mc1:" ) )
        {       
                int	nPort;
                int	numRead;
                char    mcPath[256];
		sceMcTblGetDir mcEntries[MAX_DIR_FILES] __attribute__((aligned(64)));
		
		if( !strcmp( path, "mc0:" ) )
			nPort = 0;
		else
			nPort = 1;
		
		
		// copy only the path without the device (ie : mc0:/xxx/xxx -> /xxx/xxx)
		strcpy(mcPath,(char *)&path[4]);
				
		// it temp_path is empty put a "/" inside
                if (strlen(mcPath)==0)
                   strcpy((char *)mcPath,(char *)"/");
		

		if (mcPath[strlen(mcPath)-1] != '/')
		  strcat( mcPath, "/-*" );
		else
		  strcat( mcPath, "*" );
	
		mcGetDir( nPort, 0, mcPath, 0, MAX_DIR_FILES, mcEntries);
   		while (!mcSync( MC_WAIT, NULL, &numRead ));
   		                	    
	        int cpt = 1;
	        lua_newtable(L);

		for( int i = 0; i < numRead; i++ )
		{
            lua_pushnumber(L, cpt++);  // push key for file entry

	        lua_newtable(L);
            lua_pushstring(L, "name");
            lua_pushstring(L, (const char *)mcEntries[i].EntryName);
            lua_settable(L, -3);
        
            lua_pushstring(L, "size");
            lua_pushnumber(L, mcEntries[i].FileSizeByte);
            lua_settable(L, -3);
    
            lua_pushstring(L, "directory");
            lua_pushboolean(L, ( mcEntries[i].AttrFile & MC_ATTR_SUBDIR ));
            lua_settable(L, -3);
	        lua_settable(L, -3);

		}
		return 1;  // table is already on top
        }
        //-----------------------------------------------------------------------------------------
        
        // else regular one using Dopen/Dread

	int i = 1;

	DIR *d;
	struct dirent *dir;
	d = opendir(path);
	lua_newtable(L);
	if (d) {
		while ((dir = readdir(d)) != NULL) {
			lua_pushnumber(L, i++);  // push key for file entry
	    	DPRINTF("%s\n", dir->d_name);
			lua_newtable(L);
			lua_pushstring(L, "name");
        	lua_pushstring(L, dir->d_name);
        	lua_settable(L, -3);
        		
#ifdef OLD_DIRENT
        	lua_pushstring(L, "size");
        	lua_pushnumber(L, dir->d_stat.st_size);
        	lua_settable(L, -3);
#endif
        	        
        	lua_pushstring(L, "directory");
#ifdef OLD_DIRENT
        	lua_pushboolean(L, S_ISDIR(dir->d_stat.st_mode));
#else
		    lua_pushboolean(L, (dir->d_type == DT_DIR));
#endif
        	lua_settable(L, -3);
			lua_settable(L, -3);
	    }
	    closedir(d);
	}
	else
	{
		lua_pushnil(L);  // return nil
		return 1;
	}
	return 1;  /* table is already on top */
}

static int lua_createDir(lua_State *L)
{
	const char *path = luaL_checkstring(L, 1);
	if(!path) return luaL_error(L, "Argument error: System.createDirectory(directory) takes a directory name as string as argument.");
	mkdir(path, 0777);
	
	return 0;
}

static int lua_removeDir(lua_State *L)
{
	const char *path = luaL_checkstring(L, 1);
	if(!path) return luaL_error(L, "Argument error: System.removeDirectory(directory) takes a directory name as string as argument.");
	rmdir(path);
	
	return 0;
}

/* Shared raw byte copy: open src->dst, stream, close. Returns 0 on success,
   -1 on failure. Used by rename (and historically by copyFile). */
static int copy_file_contents(const char *src, const char *dst)
{
	char buf[BUFSIZ];
	int size;

	int source = open(src, O_RDONLY, 0);
	if (source < 0) return -1;
	int dest = open(dst, O_WRONLY | O_CREAT | O_TRUNC, 0644);
	if (dest < 0) {
		close(source);
		return -1;
	}

	while ((size = read(source, buf, BUFSIZ)) > 0) {
		int wrote = write(dest, buf, size);
		if (wrote < size) {
			close(source);
			close(dest);
			return -1;
		}
	}

	close(source);
	close(dest);
	if (size < 0) {
		return -1; /* read error mid-stream: don't report a partial copy as success */
	}
	return 0;
}

static int lua_removeFile(lua_State *L)
{
	const char *path = luaL_checkstring(L, 1);
	if(!path) return luaL_error(L, "Argument error: System.removeFile(filename) takes a filename as string as argument.");
	remove(path);

	return 0;
}

static int lua_rename(lua_State *L)
{
	const char *oldName = luaL_checkstring(L, 1);
	const char *newName = luaL_checkstring(L, 2);
	if(!oldName || !newName)
		return luaL_error(L, "Argument error: System.rename(source, destination) takes two filenames as strings as arguments.");

	if (copy_file_contents(oldName, newName) != 0)
		return luaL_error(L, "System.rename: copy failed");
	remove(oldName);

	return 0;
}

static int lua_sleep(lua_State *L)
{
	if (lua_gettop(L) != 1) return luaL_error(L, "seconds expected.");
	int sec = luaL_checkinteger(L, 1);
	sleep(sec);
	return 0;
}

static int lua_getFreeMemory(lua_State *L)
{
	if (lua_gettop(L) != 0) return luaL_error(L, "no arguments expected.");
	
	size_t result = GetFreeSize();

	lua_pushinteger(L, (uint32_t)(result));
	return 1;
}

static int lua_exit(lua_State *L)
{
	int argc = lua_gettop(L);
	if (argc != 0) return luaL_error(L, "System.exitToBrowser");
	ExecOSD(0, NULL);
	return 0;
}


static int lua_getmcinfo(lua_State *L){
	int argc = lua_gettop(L);
	int type, freespace, format, result;

	int mcslot = 0;
	if(argc == 1) mcslot = luaL_checkinteger(L, 1);

	mcGetInfo(mcslot, 0, &type, &freespace, &format);
	mcSync(0, NULL, &result);

	lua_newtable(L);

	lua_pushstring(L, "type");
	lua_pushinteger(L, type);
	lua_settable(L, -3);

	lua_pushstring(L, "freemem");
	lua_pushinteger(L, freespace);
	lua_settable(L, -3);

	lua_pushstring(L, "format");
	lua_pushinteger(L, format);
	lua_settable(L, -3);

	return 1;
}

static int lua_openfile(lua_State *L){
	int argc = lua_gettop(L);
	if (argc != 2) return luaL_error(L, "wrong number of arguments");
	const char *file_tbo = luaL_checkstring(L, 1);
	int type = luaL_checkinteger(L, 2);
	int fileHandle = open(file_tbo, type, 0777);
	if (fileHandle < 0) return luaL_error(L, "cannot open '%s'\n\tfd:%d.", file_tbo, fileHandle);
	lua_pushinteger(L,fileHandle);
	return 1;
}


static int lua_readfile(lua_State *L){
	int argc = lua_gettop(L);
	if (argc != 2) return luaL_error(L, "wrong number of arguments");
	int file = luaL_checkinteger(L, 1);
	uint32_t size = luaL_checkinteger(L, 2);
	// Bound the request (callers read in small chunks) so a bogus/huge size
	// can't wrap size+1 to 0 and overflow the heap on the read().
	if (size > 64u * 1024u * 1024u) return luaL_error(L, "read size too large");
	uint8_t *buffer = (uint8_t*)malloc(size + 1);
	if (buffer == NULL) return luaL_error(L, "out of memory");
	int len = read(file, buffer, size);
	if (len < 0) {
		// A device read error (-1) would index buffer[-1] (heap-corrupt) and
		// push a ~4GB string. Fail cleanly; callers pcall this.
		free(buffer);
		return luaL_error(L, "read error");
	}
	buffer[len] = 0;
	lua_pushlstring(L,(const char*)buffer,len);
	free(buffer);
	return 1;
}


static int lua_writefile(lua_State *L){
	int argc = lua_gettop(L);
	if (argc != 3) return luaL_error(L, "wrong number of arguments");
	int fileHandle = luaL_checkinteger(L, 1);
	size_t len = 0;
	const char *text = luaL_checklstring(L, 2, &len);
	int size = luaL_checkinteger(L, 3);
	if (size < 0) size = 0;
	if ((size_t)size > len) size = (int)len;
	int written = write(fileHandle, text, size);
	lua_pushinteger(L, written);
	return 1;
}

static int lua_closefile(lua_State *L){
	int argc = lua_gettop(L);
	if (argc != 1) return luaL_error(L, "wrong number of arguments");
	int fileHandle = luaL_checkinteger(L, 1);
	close(fileHandle);
	return 0;
}

static int lua_seekfile(lua_State *L){
	int argc = lua_gettop(L);
	if (argc != 3) return luaL_error(L, "wrong number of arguments");
	int fileHandle = luaL_checkinteger(L, 1);
	int pos = luaL_checkinteger(L, 2);
	uint32_t type = luaL_checkinteger(L, 3);
	lseek(fileHandle, pos, type);	
	return 0;
}


static int lua_sizefile(lua_State *L){
	int argc = lua_gettop(L);
	if (argc != 1) return luaL_error(L, "wrong number of arguments");
	int fileHandle = luaL_checkinteger(L, 1);
	// Use off_t: a uint32_t cast turned an lseek failure (-1) into 4GB, which
	// made size-checked copies expect a 4GB source and falsely fail. On error
	// return -1 honestly and don't seek back to a bogus offset.
	off_t cur_off = lseek(fileHandle, 0, SEEK_CUR);
	off_t size = lseek(fileHandle, 0, SEEK_END);
	if (cur_off >= 0) {
		lseek(fileHandle, cur_off, SEEK_SET);
	}
	lua_pushinteger(L, (lua_Integer)size);
	return 1;
}

static int lua_checkexist(lua_State *L){
	int argc = lua_gettop(L);
	if (argc != 1) return luaL_error(L, "wrong number of arguments");
	const char *file_tbo = luaL_checkstring(L, 1);
	//printf("opening %s\n", file_tbo);
	int fileHandle = open(file_tbo, O_RDONLY);
	if (fileHandle < 0) lua_pushboolean(L, false);
	else{
		close(fileHandle);
		lua_pushboolean(L,true);
	}
	return 1;
}
extern "C" {
int LoadELFFromFile(const char *filename, int argc, char *argv[]);
int LoadELFFromFileExecPS2(const char *filename, int argc, char *argv[]);
int LoadELFFromFileExecPS2RebootIOP(const char *filename, int argc, char *argv[]);
int LoadELFFromFileExecPS2RebootIOPWithPartition(const char *filename, const char *partition, int argc, char *argv[]);
void SetExecKeepPfsMask(unsigned int mask);
void ClearExecKeepPfsMask(void);
}

static int lua_set_exec_keep_pfs_mask(lua_State *L)
{
	int argc = lua_gettop(L);
	if (argc > 1) return luaL_error(L, "Argument error: System.setExecKeepPfsMask(mask) takes zero or one argument.");
	unsigned int mask = 0;
	if (argc >= 1 && !lua_isnil(L, 1)) {
		mask = (unsigned int)luaL_checkinteger(L, 1);
	}
	SetExecKeepPfsMask(mask);
	return 0;
}

static bool is_partition_context_arg(const char *arg)
{
	size_t len;
	if (arg == NULL) {
		return false;
	}
	len = strlen(arg);
	if (len < 6 || arg[len - 1] != ':') {
		return false;
	}
	if ((strncmp(arg, "hdd", 3) == 0 && arg[3] >= '0' && arg[3] <= '9' && arg[4] == ':') ||
	    (strncmp(arg, "dvr_hdd", 7) == 0 && arg[7] >= '0' && arg[7] <= '9' && arg[8] == ':')) {
		return true;
	}
	return false;
}

static int lua_loadELF(lua_State *L)
{
	int argc = lua_gettop(L);
	if (argc < 2) return luaL_error(L, "%s(path, reboot_iop, args...): not enough args", __FUNCTION__);
	size_t size;
	const char *elftoload = luaL_checklstring(L, 1, &size);
	int rebootIOP = luaL_checkinteger(L, 2);
	int extra_args = argc - 2;
	static char selector_buf[256];
	static char launcharg_buf[64];
	static char *argv_static[3];

	DPRINTF("# Loading ELF '%s' iop_reboot=%d, extra_args=%d\n", elftoload, rebootIOP, extra_args);
	if (extra_args > 0) {
		const char *selector = luaL_checkstring(L, 3);
		snprintf(selector_buf, sizeof(selector_buf), "%s", selector ? selector : "");
		argv_static[0] = selector_buf;
		int argn = 1;
		// Optional 2nd extra arg -> target argv[1]. Added for the SIO2-conflict
		// self-restart (System.loadELF(self, 1, self, "-page=mmce")): argv[0]
		// stays the ELF path (the child's device/cwd resolution keys off it),
		// argv[1] carries one launch flag parseLaunchArgs picks up (it scans
		// argv[1..]). The 1-arg POPSTARTER call sites are byte-identical.
		if (extra_args > 1) {
			const char *launcharg = luaL_checkstring(L, 4);
			snprintf(launcharg_buf, sizeof(launcharg_buf), "%s", launcharg ? launcharg : "");
			argv_static[1] = launcharg_buf;
			argn = 2;
		}
		argv_static[argn] = NULL;
		DPRINTF("# Loading ELF argv0='%s' argc=%d\n", argv_static[0], argn);
		int rc;
		if (rebootIOP != 0) {
			rc = LoadELFFromFileExecPS2RebootIOP(elftoload, argn, argv_static);
		} else {
			rc = LoadELFFromFileExecPS2(elftoload, argn, argv_static);
		}
		ClearExecKeepPfsMask();
		lua_pushinteger(L, rc);
		return 1;
	}

	DPRINTF("# Loading ELF argv0 default (argc=0)\n");
	int rc;
	if (rebootIOP != 0) {
		rc = LoadELFFromFileExecPS2RebootIOP(elftoload, 0, NULL);
	} else {
		rc = LoadELFFromFile(elftoload, 0, NULL);
	}
	ClearExecKeepPfsMask();
	lua_pushinteger(L, rc);
	return 1;
}

// Partition-aware launch binding. The partition_context is passed out-of-band
// to the embedded loader and MUST NOT be copied into the target argv. Use this
// instead of trying to pass partition_context through the legacy
// System.loadELF(path, reboot_iop, selector) API. The legacy API preserves
// POPSTARTER's normal one-argument selector contract for non-HDD launches.
static int lua_loadELFWithPartition(lua_State *L)
{
	int argc = lua_gettop(L);
	if (argc < 3) return luaL_error(L, "%s(path, reboot_iop, partition_context, args...): not enough args", __FUNCTION__);
	const char *elftoload = luaL_checkstring(L, 1);
	int rebootIOP = luaL_checkinteger(L, 2);
	const char *partition_context = luaL_checkstring(L, 3);
	static char arg_storage[2048];
	static char *argv_static[33];
	int rc;
	int arg_count = 0;
	size_t storage_offset = 0;

	if (partition_context == NULL || partition_context[0] == '\0' || !is_partition_context_arg(partition_context)) {
		return luaL_error(L, "System.loadELFWithPartition: partition_context must look like \"hdd?:PART:\"");
	}
	if (rebootIOP == 0) {
		return luaL_error(L, "System.loadELFWithPartition: partition-aware launch requires reboot_iop != 0");
	}

	DPRINTF("# WithPartition ELF '%s' partition='%s' extra_args=%d\n", elftoload, partition_context, argc - 3);
	for (int index = 4; index <= argc; index++) {
		const char *arg = luaL_checkstring(L, index);
		size_t len = strlen(arg) + 1;
		if (arg_count >= 32) {
			return luaL_error(L, "System.loadELFWithPartition supports at most 32 extra arguments");
		}
		if ((storage_offset + len) > sizeof(arg_storage)) {
			return luaL_error(L, "System.loadELFWithPartition argument storage exceeded");
		}
		memcpy(&arg_storage[storage_offset], arg, len);
		argv_static[arg_count] = &arg_storage[storage_offset];
		DPRINTF("#  argv[%d]='%s'\n", arg_count, argv_static[arg_count]);
		storage_offset += len;
		arg_count++;
	}
	argv_static[arg_count] = NULL;

	if (arg_count > 0) {
		rc = LoadELFFromFileExecPS2RebootIOPWithPartition(elftoload, partition_context, arg_count, argv_static);
	} else {
		rc = LoadELFFromFileExecPS2RebootIOPWithPartition(elftoload, partition_context, 0, NULL);
	}
	ClearExecKeepPfsMask();
	lua_pushinteger(L, rc);
	return 1;
}

static int lua_loadELFRebootIOP(lua_State *L)
{
	int argc = lua_gettop(L);
	if (argc < 1) return luaL_error(L, "%s(path, argv0): not enough args", __FUNCTION__);
	const char *elftoload = luaL_checkstring(L, 1);
	if (argc >= 2 && !lua_isnil(L, 2)) {
		static char argv0_buf[256];
		static char *argv_static[2];
		const char *argv0 = luaL_checkstring(L, 2);
		snprintf(argv0_buf, sizeof(argv0_buf), "%s", argv0 ? argv0 : "");
		argv_static[0] = argv0_buf;
		argv_static[1] = NULL;
		int rc = LoadELFFromFileExecPS2RebootIOP(elftoload, 1, argv_static);
		ClearExecKeepPfsMask();
		lua_pushinteger(L, rc);
		return 1;
	}
	int rc = LoadELFFromFileExecPS2RebootIOP(elftoload, 0, NULL);
	ClearExecKeepPfsMask();
	lua_pushinteger(L, rc);
	return 1;
}

DiscType DiscTypes[] = {
    {SCECdGDTFUNCFAIL, "FAIL", -1},
	{SCECdNODISC, "!", 1},
    {SCECdDETCT, "??", 2},
    {SCECdDETCTCD, "CD ?", 3},
    {SCECdDETCTDVDS, "DVD-SL ?", 4},
    {SCECdDETCTDVDD, "DVD-DL ?", 5},
    {SCECdUNKNOWN, "Unknown", 6},
    {SCECdPSCD, "PS1 CD", 7},
    {SCECdPSCDDA, "PS1 CDDA", 8},
    {SCECdPS2CD, "PS2 CD", 9},
    {SCECdPS2CDDA, "PS2 CDDA", 10},
    {SCECdPS2DVD, "PS2 DVD", 11},
    {SCECdESRDVD_0, "ESR DVD (off)", 12},
    {SCECdESRDVD_1, "ESR DVD (on)", 13},
    {SCECdCDDA, "Audio CD", 14},
    {SCECdDVDV, "Video DVD", 15},
    {SCECdIllegalMedia, "Unsupported", 16},
    {0x00, "", 0x00}  //end of list
};              //ends DiscTypes array


static int lua_checkValidDisc(lua_State *L)
{
	int testValid;
	int result;
	result = 0;
	testValid = sceCdGetDiskType();
	switch (testValid) {
		case SCECdPSCD:
		case SCECdPSCDDA:
		case SCECdPS2CD:
		case SCECdPS2CDDA:
		case SCECdPS2DVD:
		case SCECdESRDVD_0:
		case SCECdESRDVD_1:
		case SCECdCDDA:
		case SCECdDVDV:
		case SCECdDETCTCD:
		case SCECdDETCTDVDS:
		case SCECdDETCTDVDD:
			result = 1;
			break;
		case SCECdNODISC:
		case SCECdDETCT:
		case SCECdUNKNOWN:
		case SCECdIllegalMedia:
			result = 0;
	}
	DPRINTF("Valid Disc: %d\n",result);
	lua_pushinteger(L, result); //return the value itself to Lua stack
    return 1; //return value quantity on stack
}

static int lua_checkDiscTray(lua_State *L)
{
	int result;
	if (sceCdStatus() == SCECdStatShellOpen){
		result = 1;
	} else {
		result = 0;
	}
	lua_pushinteger(L, result); //return the value itself to Lua stack
    return 1; //return value quantity on stack
}


static int lua_getDiscType(lua_State *L)
{
    int discType;
    int iz;
    discType = sceCdGetDiskType();
    
    int DiscType_ix = 0;
        for (iz = 0; DiscTypes[iz].name[0]; iz++)
            if (DiscTypes[iz].type == discType)
                DiscType_ix = iz;
    DPRINTF("getDiscType: %d\n",DiscTypes[DiscType_ix].value);
    lua_pushinteger(L, DiscTypes[DiscType_ix].value); //return the value itself to Lua stack
    return 1; //return value quantity on stack
}

extern int mmce_slot0_ready;
extern int mmce_slot1_ready;

static int lua_direxists(lua_State *L)
{
    int argc = lua_gettop(L);
    if (argc != 1)
        return luaL_error(L, "Argument error: lua_direxists takes one argument.");
    const char *folder = luaL_checkstring(L, 1);
    DIR *d = opendir(folder);
    bool ret = false;
	if (d)
    {
        ret = true;
        closedir(d);
    } else {
        ret = false;
    }
    lua_pushboolean(L, ret);
    return 1;
}
extern char* GetArgv0(void);
static int lua_popargv0(lua_State *L) {
	const char* A = GetArgv0();
	if (A == NULL)
		lua_pushnil(L);
	else
		lua_pushstring(L, A);
	return 1;
}

static int lua_getAppDir(lua_State *L) {
	lua_pushstring(L, app_dir);
	return 1;
}

/* NHDDL-style launch arguments parsed in main.cpp parseLaunchArgs().
 * Externs declared in include/luaplayer.h. */
static int lua_getLaunchArgs(lua_State *L) {
	lua_newtable(L);
	lua_pushstring(L, launch_arg_page);
	lua_setfield(L, -2, "page");
	lua_pushstring(L, launch_arg_game);
	lua_setfield(L, -2, "game");
	lua_pushboolean(L, launch_arg_debug != 0);
	lua_setfield(L, -2, "debug");
	return 1;
}

/* Pre-Lua C-side device classification hint (from argv[0]). The
 * authoritative boot device is still resolved in system.lua
 * DetectBootDevice (it handles the mass:/ MX4SIO disambiguation via
 * BDM driver lookup). This hint is for early decisions only.
 * Extern declared in include/luaplayer.h. */
static int lua_getBootDeviceHint(lua_State *L) {
	lua_pushstring(L, boot_device_hint);
	return 1;
}

static int lua_resolveAsset(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 1) return luaL_error(L, "Argument error: System.resolveAsset(relativeName) takes one argument.");
	const char *rel = luaL_checkstring(L, 1);
	char out[255];
	if (ResolveAssetPath(out, sizeof(out), rel)) {
		lua_pushstring(L, out);
	} else {
		lua_pushnil(L);
	}
	return 1;
}

static int lua_resolveAssetType(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 2) return luaL_error(L, "Argument error: System.resolveAssetType(relativeName, kind) takes two arguments.");
	const char *rel = luaL_checkstring(L, 1);
	int kind = luaL_checkinteger(L, 2);
	char out[255];
	if (ResolveAssetPathTyped(out, sizeof(out), rel, (AssetKind)kind)) {
		lua_pushstring(L, out);
	} else {
		lua_pushnil(L);
	}
	return 1;
}

static int lua_ensure_bdm(lua_State *L)
{
	lua_pushboolean(L, EnsureBDM());
	return 1;
}

static int lua_ensure_bdm_fatfs(lua_State *L)
{
	lua_pushboolean(L, EnsureBDMFatFs());
	return 1;
}

// Staged ATA bring-up (EXP11 diagnostics): expose dev9 alone so the Lua side can
// paint a distinct progress step before EACH blocking module load. EnsureAtaBdm
// re-runs EnsureDev9/EnsureBDMFatFs internally, but both are load-once latched,
// so pre-calling them from Lua reduces System.initATA to settle + ata_bd + settle
// -- and a frozen on-screen percent then names the exact stalled module start.
static int lua_ensure_dev9(lua_State *L)
{
	lua_pushboolean(L, EnsureDev9());
	return 1;
}

// Report the USB bring-up state so the USB page can say WHY it found nothing.
// Fields are the raw SifExecModuleBuffer id/ret per module, -999 if never
// attempted. usbd is loaded once at boot (main.cpp) because ds34usb/ds34bt
// hard-import it for pad input; the rest load lazily on USB-page entry.
// Boot profile: {stage=..., ms=...} per stage, in boot order. Backed by
// main.cpp's BootStamp, whose only consumer used to be a DPRINTF that compiles
// to nothing in a release build. The ENTIRE IRX block runs before initGraphics(),
// so all of it is black screen -- this is how we find out which module owns it
// instead of guessing.
extern "C" int BootProfileCount(void);
extern "C" const char *BootProfileStage(int i);
extern "C" unsigned int BootProfileMs(int i);

static int lua_get_boot_profile(lua_State *L)
{
	int n = BootProfileCount();
	lua_newtable(L);
	for (int i = 0; i < n; i++) {
		lua_pushinteger(L, i + 1);
		lua_newtable(L);
		lua_pushstring(L, "stage");
		lua_pushstring(L, BootProfileStage(i));
		lua_settable(L, -3);
		lua_pushstring(L, "ms");
		lua_pushinteger(L, (lua_Integer)BootProfileMs(i));
		lua_settable(L, -3);
		lua_settable(L, -3);
	}
	return 1;
}

// Probe the IOP for a contiguous 128 KiB block -- the exact size bd_cache_create()
// demands for EVERY raw USB block device (32 * 8 * 512, libbdm/src/bd_cache.c:8),
// allocated because usbmass_bd sets parNr = 0 and bdm caches every parNr==0 device.
// BOTH of those allocations are UNCHECKED and dereferenced unconditionally
// (bd_cache.c:162-168), so if the IOP cannot supply the block the USB mass worker
// dies AFTER every IRX has already loaded successfully -- which is exactly the
// "modules OK, no drive seen" we cannot currently explain.
// This matters because POPSLoader loads far more IOP modules than OPL or
// wLaunchELF (ds34usb, ds34bt, audsrv, mcman, mcserv, padman, sio2man, ppctty),
// so IOP memory pressure is a genuine POPSLoader-vs-them delta -- and unlike every
// other theory it blames nothing about the tester's drive or console.
// We allocate and immediately free, so this is a measurement, not a reservation.
static int lua_iop_heap_probe(lua_State *L)
{
	const int want = 128 * 1024;
	int got_128k = 0;
	int largest = 0;

	void *p = SifAllocIopHeap(want);
	if (p != NULL) {
		got_128k = 1;
		largest = want;
		SifFreeIopHeap(p);
	} else {
		// Binary-search downward for the largest block the IOP will still give us.
		// A number well under 128 KiB is the smoking gun.
		int lo = 0, hi = want;
		while (lo < hi) {
			int mid = lo + (hi - lo + 1) / 2;
			void *q = SifAllocIopHeap(mid);
			if (q != NULL) {
				SifFreeIopHeap(q);
				lo = mid;
			} else {
				hi = mid - 1;
			}
			if (hi - lo < 1024) break;   // 1 KiB resolution is plenty
		}
		largest = lo;
	}
	lua_newtable(L);
	lua_pushstring(L, "can_alloc_128k");
	lua_pushboolean(L, got_128k);
	lua_settable(L, -3);
	lua_pushstring(L, "largest");
	lua_pushinteger(L, largest);
	lua_settable(L, -3);
	return 1;
}

static int lua_get_usb_diag(lua_State *L)
{
	lua_newtable(L);
#define DIAG_FIELD(k, v) do { lua_pushstring(L, k); lua_pushinteger(L, (v)); lua_settable(L, -3); } while (0)
	DIAG_FIELD("usbd_id", g_usbd_load_id);
	DIAG_FIELD("usbd_ret", g_usbd_load_ret);
	DIAG_FIELD("bdm_id", g_bdm_id);
	DIAG_FIELD("bdm_ret", g_bdm_ret);
	DIAG_FIELD("bdmfs_id", g_bdmfs_id);
	DIAG_FIELD("bdmfs_ret", g_bdmfs_ret);
	DIAG_FIELD("usbmass_id", g_usbmass_id);
	DIAG_FIELD("usbmass_ret", g_usbmass_ret);
#undef DIAG_FIELD
	lua_pushstring(L, "usbmass_loaded");
	lua_pushboolean(L, usbmass_irx_loaded ? 1 : 0);
	lua_settable(L, -3);
	return 1;
}

static int lua_ensure_usb_mass(lua_State *L)
{
	lua_pushboolean(L, EnsureUsbMass());
	return 1;
}

static int lua_ensure_cdfs(lua_State *L)
{
	lua_pushboolean(L, EnsureCDFS());
	return 1;
}

static int lua_ensure_mmceman(lua_State *L)
{
	lua_pushboolean(L, EnsureMmceman());
	return 1;
}

// Re-open the controller port. Called from Lua after an on-demand mmceman
// load (PLDR.EnsureMmceReadyOnce) to recover pad input that the shared-SIO2
// disruption can silently drop. Returns true if the port came back up.
static int lua_reinit_pad(lua_State *L)
{
	lua_pushboolean(L, pad_reinit());
	return 1;
}

// EXP32: mx4sio_bd loads LAZILY, on engagement -- the MX4SIO page's first entry
// (via System.initMX4SIO), an mx4sio: boot (boot.lua), or the legacy-mass
// sidecar heal (system.lua) when a mass* cwd turns out not to be USB-backed.
// No boot-time load: storage stacks load when their device is engaged
// (wLaunchELF_R3Z's model; OPL loads transports at first BDM init on its
// worker). Coexists with mmceman when both get engaged (official OPL runs
// both resident on freesio2; maintainer call 2026-07-21, no gate). The module
// load itself is cheap and returns promptly (card detection runs on the
// driver's own IOP thread). Failure never latches: the next page entry
// retries (success-only latch, OPL's rule). usbmass_bd stays ordered first
// (maintainer 2026-05-28: "mx4sio will need the usb drivers to activate
// before it"; EnsureUsbMass is idempotent/latched -- a no-op after boot).
bool EnsureMx4sioBd(void)
{
	if (!EnsureUsbMass()) {
		return false;
	}
	if (!mx4sio_irx_loaded) {
		if (!LoadIrxCheckedBuffer("mx4sio_bd.irx", mx4sio_bd_irx, size_mx4sio_bd_irx, NULL, NULL)) {
			return false;
		}
		mx4sio_irx_loaded = true;
	}
	return true;
}

static int lua_mx4sio_init(lua_State *L)
{
	int argc = lua_gettop(L);
	if (argc > 1) {
		return luaL_error(L, "Argument error: System.initMX4SIO() takes at most one argument.");
	}
	if (argc == 1 && !lua_isnil(L, 1)) {
		(void)luaL_checkstring(L, 1);
	}

	bool ok = EnsureMx4sioBd();

	lua_pushboolean(L, ok);
	if (ok) {
		return 1;
	}
	lua_pushstring(L, "IRX_LOAD_FAIL");
	return 2;
}

// Bring up the BDM-enabled ATA stack ONCE: dev9 -> bdm -> bdmfs_fatfs -> ata_bd.
// ata_bd IS ps2atad compiled with ATA_ENABLE_BDM=1 -- it registers BOTH the atad library
// (used by ps2hdd/ps2fs for APA/PFS) AND a BDM "ata" mass device (exFAT). The BDM FS layer
// MUST precede it so ata_bd's bdm_connect_bd registration succeeds. SHARED by the HDD-boot
// APA path (luaHDD.cpp Load_HDD_IRX) and the exFAT page (lua_ata_init) so ONE instance serves
// both -- the config OPL ships. Booting from an APA HDD used to load plain ps2atad (boot) AND
// a SECOND ata_bd (exFAT page): two atad copies re-initing the live ATA bus -> the 42% scan
// freeze with the HDD light latched on (CosmicScale APA-Jail HDD, 2026-06-25). Load-once via
// g_ata_bd_loaded (a non-static global shared with luaHDD.cpp).
bool g_ata_bd_loaded = false;

// EXP33: EnsureAtaBdm is called from TWO threads now -- the boot-time async
// worker (do_boot_init's initATAAsync kick, new in EXP32) AND the main thread
// (APA page: HDD.Initialize -> Load_HDD_IRX -> EnsureAtaBdm; and the exFAT
// page). The load-once latches (g_ata_bd_loaded / g_dev9_loaded / bdm+bdmfs)
// are plain bools set AFTER the load, so two concurrent callers both read
// them false and BOTH loaded -- a second ata_bd _start re-resets the live ATA
// bus (the CosmicScale APA-Jail 42% class). Serialize the whole bring-up with
// a binary semaphore so the second caller waits and returns the completed
// result. Created before the worker is ever spawned (lua_ata_init_async) so
// it always exists by the time the worker runs; the Lua-side cascade bound in
// PLDR.LoadHDDModules normally keeps the main thread from even entering here
// while the worker runs, so this sema almost never actually blocks.
static int g_ata_bdm_sema = -1;
void EnsureAtaBdmSemaInit()
{
	if (g_ata_bdm_sema < 0) {
		ee_sema_t s;
		s.init_count = 1;
		s.max_count = 1;
		s.attr = 0;
		s.option = 0;
		g_ata_bdm_sema = CreateSema(&s);
	}
}

static bool EnsureAtaBdmInner()
{
	if (!EnsureDev9()) {
		return false;
	}
	// ATA uses ata_bd, NOT the USB mass block driver -- load only the BDM FS base
	// (bdm + bdmfs_fatfs), never usbmass_bd, so bringing up the internal exFAT/APA
	// drive does not also spin up USB enumeration. Matches wLaunchELF_R3Z's
	// loadAtaBlockDriver (bdm -> bdmfs -> ata_bd, no usbmass_bd). Verified independent:
	// ata_bd registers its own BDM "ata" device + the atad library for PFS, and the
	// APA-boot path (luaHDD.cpp Load_HDD_IRX) needs the same bdm/bdmfs/ata_bd and never
	// usbmass_bd; ClassifyMassRootDriver treats "ata" and "usb" as distinct buckets.
	if (!EnsureBDMFatFs()) {   // dev9 -> bdm -> bdmfs_fatfs; bdm MUST precede ata_bd
		return false;
	}
	if (!g_ata_bd_loaded) {
		// Let bdmfs_fatfs settle before ata_bd registers with the BDM core -- the same
		// 1s settle EnsureUsbMass applies before usbmass_bd (R3Z gets the equivalent gap
		// from loading dev9 between bdmfs and ata_bd; we load dev9 first, so settle here).
		sleep(1);
		if (!LoadIrxCheckedBuffer("ata_bd.irx", ata_bd_irx, size_ata_bd_irx, NULL, NULL)) {
			return false;
		}
		g_ata_bd_loaded = true;
		// Match NHDDL/wLaunchELF ordering: let ata_bd settle before ps2hdd/ps2fs touch it.
		sleep(1);
	}
	return true;
}

// Locking wrapper (see EnsureAtaBdmSemaInit above). Double-checked: a caller
// that waited behind an in-flight load returns immediately once g_ata_bd_loaded
// is set. All callers (worker thread, APA path, exFAT path) go through here.
bool EnsureAtaBdm()
{
	EnsureAtaBdmSemaInit();
	if (g_ata_bdm_sema >= 0) {
		WaitSema(g_ata_bdm_sema);
	}
	bool ok = EnsureAtaBdmInner();
	if (g_ata_bdm_sema >= 0) {
		SignalSema(g_ata_bdm_sema);
	}
	return ok;
}

static int lua_ata_init(lua_State *L)
{
	int argc = lua_gettop(L);
	if (argc > 1) {
		return luaL_error(L, "Argument error: System.initATA() takes at most one argument.");
	}
	if (argc == 1 && !lua_isnil(L, 1)) {
		(void)luaL_checkstring(L, 1);
	}

	// Bring up the BDM-enabled atad (ata_bd) for the exFAT mass device via EnsureAtaBdm.
	// It is SHARED + load-once with the HDD-boot APA path (luaHDD.cpp): when POPSLoader was
	// booted from an APA HDD (atad already resident for the pfs1: settings) this does NOT
	// load a SECOND atad onto the live ATA bus -- that duplicate load was the 42% scan freeze
	// (CosmicScale APA-Jail HDD, 2026-06-25). On a non-HDD boot it brings the whole stack up
	// itself (dev9 -> bdm -> bdmfs_fatfs -> ata_bd), exactly as before.
	bool ok = EnsureAtaBdm();

	lua_pushboolean(L, ok);
	if (ok) {
		return 1;
	}
	lua_pushstring(L, "IRX_LOAD_FAIL");
	return 2;
}

// System.ataReady(): TRUE iff the ata stack is up (the lazy async worker below
// finished, or an hdd0: boot brought it up via luaHDD). Pure read, NO side
// effects -- BuildATAIdentityDeferred keys off this to skip pointless retries
// after a failed/absent bring-up.
static int lua_ata_ready(lua_State *L)
{
	lua_pushboolean(L, g_ata_bd_loaded ? 1 : 0);
	return 1;
}

// ============================================================================
// Async ata_bd bring-up worker. EXP32: the PREFERRED kick is at BOOT (Lua
// do_boot_init calls initATAAsync when the Internal-HDD setting includes
// exFAT), so the identical blob loads into the same near-empty IOP as the
// EXP22 build -- the only configuration hardware-proven on sAGA's SCPH-30004
// (the byte-identical driver worked at boot and wedged mid-session; the IOP
// census at load time IS the variable, per the EXP24 analysis "no reference
// loads BDM-atad late onto a full IOP"). The worker keeps boot responsive:
// the probe runs behind the splash/carousel instead of blocking ~5s.
// Page entry only POLLS the state, bounded -- it never loads synchronously
// (the sync fallback was the historically-freezing configuration and is gone).
// A done-fail state (3) re-spawns on the next initATAAsync call, so a failed
// early probe stays RETRYABLE at page-entry time -- RiptOPL's hddsupport.c
// SCPH-30004 rule ("early dev9 revisions fail the seconds-after-power-on
// probe and succeed at tab-entry time"; a consumed count poisoned the session).
// Worker mirrors the proven Graphics.threadLoadImage pattern (ee_thread_t,
// priority 16, ExitDeleteThread).
//
// THE APA/PFS BOOT PATH IS UNCHANGED: luaHDD.cpp Load_HDD_IRX calls the
// SYNCHRONOUS EnsureAtaBdm at boot on hdd0: boots (must finish before pfs1:
// mounts) -- do NOT route that through this. Load-once via the SAME
// g_ata_bd_loaded, so whichever path loads ata_bd first wins.
// ============================================================================
extern void *_gp;   // GP for spawned EE threads (same symbol luagraphics uses)

// 0=idle 1=running 2=done-ok 3=done-fail. Written by the worker thread, polled
// from Lua on the main thread; volatile so the poll re-reads it each frame.
static volatile int g_ata_async_state = 0;
static u8 g_ata_async_stack[8192] __attribute__((aligned(16)));

static int ata_async_thread(void *arg)
{
	(void)arg;
	bool ok = EnsureAtaBdm();
	g_ata_async_state = ok ? 2 : 3;
	ExitDeleteThread();
	return 0;
}

// KickAtaAsyncBoot(): kick the ata_bd bring-up onto a worker thread and return
// immediately with the state int. If ata_bd is already loaded (e.g. an APA-HDD
// boot brought it up) it reports done-ok (2) without spawning. A prior
// done-fail (3) re-spawns -- failure is retryable by design (RiptOPL's
// SCPH-30004 rule). Returns -1 if the thread could not be created; callers
// must NEVER fall back to a synchronous load on the UI thread (that was the
// freezing configuration).
//
// EXP61: main.cpp now calls this AT BOOT, right after EnsureUsbMass() -- the
// exact spot rr0718/EXP22 did the synchronous load, the only configuration
// hardware-proven on sAGA's SCPH-30004. The byte-identical ata_bd wedge at
// "exFAT 1c: status 1" (EXP55-60) was never the driver: it was the load
// landing mid-session on a full IOP. Spawning here puts the probe back on the
// leanest IOP this build ever has, while the async worker keeps the EXP24
// verdict intact (no 5-6s serial boot cost).
int KickAtaAsyncBoot(void)
{
	if (g_ata_bd_loaded) {
		g_ata_async_state = 2;
		return 2;
	}
	if (g_ata_async_state == 1) {   // already running -- do not spawn a second
		return 1;
	}
	// Create the EnsureAtaBdm mutex BEFORE the worker exists, so the worker's
	// EnsureAtaBdm and any concurrent main-thread EnsureAtaBdm serialize on the
	// same sema (the caller is single-threaded w.r.t. the worker right here).
	EnsureAtaBdmSemaInit();
	g_ata_async_state = 1;
	ee_thread_t th;
	th.attr = 0;
	th.option = 0;
	th.func = (void *)ata_async_thread;
	th.stack = (void *)g_ata_async_stack;
	th.stack_size = sizeof(g_ata_async_stack);
	th.gp_reg = &_gp;
	th.initial_priority = 16;   // same as the proven Graphics.threadLoadImage worker
	int tid = CreateThread(&th);
	if (tid < 0) {
		g_ata_async_state = 0;   // spawn failed -> caller must NOT sync-load on the UI thread
		return -1;
	}
	StartThread(tid, NULL);
	return 1;
}

// System.initATAAsync(): Lua binding over KickAtaAsyncBoot (page-entry kick /
// retry; the boot kick comes from main.cpp directly).
static int lua_ata_init_async(lua_State *L)
{
	lua_pushinteger(L, KickAtaAsyncBoot());
	return 1;
}

// System.initATAStatus(): 0=idle 1=running 2=done-ok 3=done-fail. Poll each frame.
// ALSO read by the Lua-side cascade bound: the ata worker's module loads go
// through the same IOP module loader a page-entry initMX4SIO uses, so while
// state==1 the MX4SIO page waits BOUNDED (screen alive) instead of queueing a
// synchronous load behind a possibly-wedged loader, then reports not-ready.
static int lua_ata_init_status(lua_State *L)
{
	(void)L;
	lua_pushinteger(L, g_ata_async_state);
	return 1;
}

// ============================================================================
// Menu-side SMB browse (Increment 1: connect + list). Mirrors OPL's proven
// netman recipe (Open-PS2-Loader src/ethsupport.c). LAZY: these IRX load only
// here (System.initSMB / connectSMB on SMB-page entry), never at boot. ps2dev9
// is SHARED with the HDD path (luaHDD.cpp) -- coordinated via g_dev9_loaded so it
// loads exactly once. HARDWARE-ONLY verifiable: link-up/DHCP bind, the LOGON/
// OPENSHARE handshake, and the smb0: dir-walk need a real PS2 + a live SMB server.
// ============================================================================
bool g_dev9_loaded = false;   // shared with luaHDD.cpp Load_HDD_IRX (load ps2dev9 once)
static bool net_irx_loaded = false;
static bool smb_irx_loaded = false;
static char SMB_IFNAME[] = "sm0";   // mutable: ps2ip_getconfig takes char*, not const char*

static bool EnsureDev9()
{
	if (g_dev9_loaded) {
		return true;
	}
	if (!LoadIrxCheckedBuffer("ps2dev9.irx", ps2dev9_irx, size_ps2dev9_irx, NULL, NULL)) {
		return false;
	}
	g_dev9_loaded = true;
	return true;
}

// dev9 -> netman(+NetManInit) -> SMSUTILS -> smap -> ps2ip(-nm) -> ps2ips, then
// ps2ip_init(). Mirrors OPL ethLoadModules; httpclient is intentionally skipped.
static bool EnsureNet()
{
	if (net_irx_loaded) {
		return true;
	}
	if (!EnsureDev9()) {
		return false;
	}
	if (!LoadIrxCheckedBuffer("netman.irx", netman_irx, size_netman_irx, NULL, NULL)) {
		return false;
	}
	NetManInit();
	if (!LoadIrxCheckedBuffer("SMSUTILS.irx", asset_smb_smsutils_irx, size_asset_smb_smsutils_irx, NULL, NULL)) {
		return false;
	}
	if (!LoadIrxCheckedBuffer("smap.irx", smap_irx, size_smap_irx, NULL, NULL)) {
		return false;
	}
	if (!LoadIrxCheckedBuffer("ps2ip.irx", ps2ip_irx, size_ps2ip_irx, NULL, NULL)) {
		return false;
	}
	if (!LoadIrxCheckedBuffer("ps2ips.irx", ps2ips_irx, size_ps2ips_irx, NULL, NULL)) {
		return false;
	}
	// Bind the EE to the IOP-SIDE lwip stack via the ps2ips RPC (OPL ethLoadModules
	// does exactly this). ps2ip-nm.irx already registered the IOP stack with netman;
	// smbman does its TCP on THAT stack. The old EE-side ps2ipInit(...) here stood up
	// a second, orphaned EE stack that never received a frame -- all later IP config
	// (SmbApplyIPConfig) and DHCP went to it, so connect failed on hardware regardless
	// of settings. After ps2ip_init(), ps2ip_getconfig/ps2ip_setconfig/dns_setserver
	// dispatch over the RPC to the stack smbman uses.
	if (ps2ip_init() < 0) {
		return false;
	}
	net_irx_loaded = true;
	return true;
}

static bool EnsureSMB()
{
	if (smb_irx_loaded) {
		return true;
	}
	if (!EnsureNet()) {
		return false;
	}
	if (!LoadIrxCheckedBuffer("smbman.irx", smbman_irx, size_smbman_irx, NULL, NULL)) {
		return false;
	}
	smb_irx_loaded = true;
	return true;
}

static int SmbLinkUp(void)
{
	return (NetManIoctl(NETMAN_NETIF_IOCTL_GET_LINK_STATUS, NULL, 0, NULL, 0) == NETMAN_NETIF_ETH_LINK_STATE_UP);
}

static int SmbDhcpBound(void)
{
	t_ip_info ip_info;
	if (ps2ip_getconfig(SMB_IFNAME, &ip_info) < 0) {
		return 0;
	}
	if (!ip_info.dhcp_enabled) {
		return 1;
	}
	return (ip_info.dhcp_status == DHCP_STATE_BOUND || ip_info.dhcp_status == DHCP_STATE_OFF);
}

// Poll a check fn up to 30s (mirrors OPL WaitValidNetState; sleep() is the same
// newlib delay System.sleep uses). Returns 0 when valid, -1 on timeout.
static int SmbWaitNetState(int (*check)(void))
{
	for (int i = 0; i < 30; i++) {
		if (check()) {
			return 0;
		}
		sleep(1);
	}
	return -1;
}

static int SmbApplyLinkMode(int mode)
{
	static int current = NETMAN_NETIF_ETH_LINK_MODE_AUTO;
	int result = 0;
	if (current != mode) {
		if ((result = NetManSetLinkMode(mode)) == 0) {
			current = mode;
		}
	}
	return result;
}

static int SmbLinkModeConst(const char *m)
{
	if (!strcmp(m, "100full")) return NETMAN_NETIF_ETH_LINK_MODE_100M_FDX;
	if (!strcmp(m, "100half")) return NETMAN_NETIF_ETH_LINK_MODE_100M_HDX;
	if (!strcmp(m, "10full"))  return NETMAN_NETIF_ETH_LINK_MODE_10M_FDX;
	if (!strcmp(m, "10half"))  return NETMAN_NETIF_ETH_LINK_MODE_10M_HDX;
	return NETMAN_NETIF_ETH_LINK_MODE_AUTO;
}

static void SmbParseOctets(const char *s, unsigned char out[4])
{
	int a = 0, b = 0, c = 0, d = 0;
	out[0] = out[1] = out[2] = out[3] = 0;
	if (s != NULL && sscanf(s, "%d.%d.%d.%d", &a, &b, &c, &d) == 4) {
		out[0] = (unsigned char)a; out[1] = (unsigned char)b;
		out[2] = (unsigned char)c; out[3] = (unsigned char)d;
	}
}

// Apply the PS2 IP config (mirrors OPL ethApplyIPConfig). Interface = "sm0".
static int SmbApplyIPConfig(int dhcp, const unsigned char ip[4], const unsigned char mask[4],
                            const unsigned char gw[4], const unsigned char dns[4])
{
	t_ip_info ip_info;
	struct ip4_addr ipaddr, netmask, gateway, dnsaddr;
	if (ps2ip_getconfig(SMB_IFNAME, &ip_info) < 0) {
		return -1;
	}
	if (dhcp) {
		ip4_addr_set_zero((struct ip4_addr *)&ip_info.ipaddr);
		ip4_addr_set_zero((struct ip4_addr *)&ip_info.netmask);
		ip4_addr_set_zero((struct ip4_addr *)&ip_info.gw);
		ip_info.dhcp_enabled = 1;
		ps2ip_setconfig(&ip_info);
	} else {
		IP4_ADDR(&ipaddr, ip[0], ip[1], ip[2], ip[3]);
		IP4_ADDR(&netmask, mask[0], mask[1], mask[2], mask[3]);
		IP4_ADDR(&gateway, gw[0], gw[1], gw[2], gw[3]);
		IP4_ADDR(&dnsaddr, dns[0], dns[1], dns[2], dns[3]);
		ip_addr_set((struct ip4_addr *)&ip_info.ipaddr, &ipaddr);
		ip_addr_set((struct ip4_addr *)&ip_info.netmask, &netmask);
		ip_addr_set((struct ip4_addr *)&ip_info.gw, &gateway);
		ip_info.dhcp_enabled = 0;
		ps2ip_setconfig(&ip_info);
		dns_setserver(0, &dnsaddr);
	}
	return 0;
}

// System.initSMB() -- load the SMB IRX stack (lazy). true / (false,"IRX_LOAD_FAIL").
static int lua_smb_init(lua_State *L)
{
	if (lua_gettop(L) > 0) {
		return luaL_error(L, "Argument error: System.initSMB() takes no arguments.");
	}
	bool ok = EnsureSMB();
	lua_pushboolean(L, ok);
	if (ok) {
		return 1;
	}
	lua_pushstring(L, "IRX_LOAD_FAIL");
	return 2;
}

#define SMB_GET_STR(key, buf) do { \
		lua_getfield(L, 1, key); \
		if (lua_isstring(L, -1)) { strncpy((buf), lua_tostring(L, -1), sizeof(buf) - 1); (buf)[sizeof(buf) - 1] = '\0'; } \
		lua_pop(L, 1); \
	} while (0)
#define SMB_PUSH_ERR(code) do { lua_pushboolean(L, false); lua_pushstring(L, (code)); return 2; } while (0)

// System.smbNetUp(cfg) -- interface bring-up ONLY (link wait + link mode + IP
// config + DHCP wait). Split from connectSMB so Lua can report per-phase progress
// between the (up to 30 s each) blocking waits instead of freezing one overlay
// frame through the whole bring-up. cfg = PLDR.SMB. Returns true, or
// (false,"<ERR>") with ERR = NO_LINK / IPCFG_FAIL / DHCP_FAIL / IRX_LOAD_FAIL.
static int lua_smb_netup(lua_State *L)
{
	if (lua_gettop(L) != 1 || !lua_istable(L, 1)) {
		return luaL_error(L, "System.smbNetUp(cfg) expects a config table.");
	}

	char ps2ip_s[64] = {0}, netmask_s[64] = {0}, gw_s[64] = {0}, dns_s[64] = {0};
	char linkmode[16] = {0};
	int dhcp = 0;

	SMB_GET_STR("PS2_IP", ps2ip_s);
	SMB_GET_STR("NETMASK", netmask_s);
	SMB_GET_STR("GATEWAY", gw_s);
	SMB_GET_STR("DNS", dns_s);
	SMB_GET_STR("LINKMODE", linkmode);
	lua_getfield(L, 1, "DHCP");
	dhcp = lua_toboolean(L, -1);
	lua_pop(L, 1);

	if (!EnsureSMB()) {
		SMB_PUSH_ERR("IRX_LOAD_FAIL");
	}

	// ---- bring up the interface (mirrors OPL ethInitApplyConfig) ----
	int mode = SmbLinkModeConst(linkmode);
	do {
		if (SmbWaitNetState(&SmbLinkUp) != 0) { SMB_PUSH_ERR("NO_LINK"); }
	} while (SmbApplyLinkMode(mode) != 0);
	if (SmbWaitNetState(&SmbLinkUp) != 0) { SMB_PUSH_ERR("NO_LINK"); }

	unsigned char ip4[4], mask4[4], gw4[4], dns4[4];
	SmbParseOctets(ps2ip_s, ip4);
	SmbParseOctets(netmask_s, mask4);
	SmbParseOctets(gw_s, gw4);
	SmbParseOctets(dns_s, dns4);
	// Surface an IP-config failure as its own error instead of letting it fall
	// through and masquerade as CONN_FAIL (static) or an instantly-passed DHCP wait.
	if (SmbApplyIPConfig(dhcp, ip4, mask4, gw4, dns4) != 0) {
		SMB_PUSH_ERR("IPCFG_FAIL");
	}

	if (dhcp && SmbWaitNetState(&SmbDhcpBound) != 0) {
		SMB_PUSH_ERR("DHCP_FAIL");
	}

	lua_pushboolean(L, true);
	return 1;
}

// System.connectSMB(cfg) -- the SMB handshake on smb0: (LOGON/ECHO/OPENSHARE).
// Call System.smbNetUp(cfg) FIRST (PLDR.InitSMBPopsRoot does). cfg = PLDR.SMB.
// Returns (true,"smb0:") on success, or (false,"<ERR>") where ERR is CONN_FAIL /
// PROT_FAIL / LOGON_FAIL / ECHO_FAIL / SHARE_FAIL / NETBIOS_NA / IRX_LOAD_FAIL.
static int lua_smb_connect(lua_State *L)
{
	if (lua_gettop(L) != 1 || !lua_istable(L, 1)) {
		return luaL_error(L, "System.connectSMB(cfg) expects a config table.");
	}

	char server[256] = {0}, share[256] = {0}, user[256] = {0}, pass[256] = {0};
	char addrtype[16] = {0};
	int port = 445;

	SMB_GET_STR("SERVER", server);
	SMB_GET_STR("SHARE", share);
	SMB_GET_STR("USER", user);
	SMB_GET_STR("PASS", pass);
	SMB_GET_STR("ADDR_TYPE", addrtype);
	lua_getfield(L, 1, "PORT");
	if (lua_isstring(L, -1)) { int p = 0; if (sscanf(lua_tostring(L, -1), "%d", &p) == 1) port = p; }
	else if (lua_isnumber(L, -1)) { port = (int)lua_tointeger(L, -1); }
	lua_pop(L, 1);
	if (port <= 0) { port = 445; }

	// IP addressing only. NetBIOS needs nbns.irx, which is OPL-custom (not in stock
	// ps2sdk) -> a build dependency we deliberately don't pull in. Use a Server IP.
	if (!strcmp(addrtype, "netbios")) {
		SMB_PUSH_ERR("NETBIOS_NA");
	}
	if (!EnsureSMB()) {
		SMB_PUSH_ERR("IRX_LOAD_FAIL");
	}

	// ---- SMB handshake on smb0: (mirrors OPL ethSMBConnect) ----
	smbLogOn_in_t logon;
	smbEcho_in_t echo;
	smbOpenShare_in_t openshare;
	int result;
	memset(&logon, 0, sizeof(logon));
	memset(&echo, 0, sizeof(echo));
	memset(&openshare, 0, sizeof(openshare));

	strncpy(logon.serverIP, server, sizeof(logon.serverIP) - 1);
	logon.serverPort = port;

	if (strlen(pass) > 0) {
		smbGetPasswordHashes_in_t passwd;
		smbGetPasswordHashes_out_t passwdhashes;
		memset(&passwd, 0, sizeof(passwd));
		strncpy(logon.User, user, sizeof(logon.User) - 1);
		strncpy(passwd.password, pass, sizeof(passwd.password) - 1);
		if (fileXioDevctl("smb0:", SMB_DEVCTL_GETPASSWORDHASHES, (void *)&passwd, sizeof(passwd), (void *)&passwdhashes, sizeof(passwdhashes)) == 0) {
			memcpy((void *)logon.Password, (void *)&passwdhashes, sizeof(passwdhashes));
			logon.PasswordType = HASHED_PASSWORD;
			memcpy((void *)openshare.Password, (void *)&passwdhashes, sizeof(passwdhashes));
			openshare.PasswordType = HASHED_PASSWORD;
		} else {
			strncpy(logon.Password, pass, sizeof(logon.Password) - 1);
			logon.PasswordType = PLAINTEXT_PASSWORD;
			strncpy(openshare.Password, pass, sizeof(openshare.Password) - 1);
			openshare.PasswordType = PLAINTEXT_PASSWORD;
		}
	} else {
		strncpy(logon.User, user, sizeof(logon.User) - 1);
		logon.PasswordType = NO_PASSWORD;
		openshare.PasswordType = NO_PASSWORD;
	}

	result = fileXioDevctl("smb0:", SMB_DEVCTL_LOGON, (void *)&logon, sizeof(logon), NULL, 0);
	if (result < 0) {
		// Three-way map: an SMBv1 protocol-negotiation refusal (modern Windows/Samba
		// default posture) is NOT a credentials problem -- give it its own code so the
		// UI can say "enable SMBv1 on the host" instead of "check User / Password".
		if (result == -SMB_DEVCTL_LOGON_ERR_CONN) {
			SMB_PUSH_ERR("CONN_FAIL");
		} else if (result == -SMB_DEVCTL_LOGON_ERR_PROT) {
			SMB_PUSH_ERR("PROT_FAIL");
		} else {
			SMB_PUSH_ERR("LOGON_FAIL");
		}
	}

	strcpy(echo.echo, "ALIVE ECHO TEST");
	echo.len = strlen("ALIVE ECHO TEST");
	if (fileXioDevctl("smb0:", SMB_DEVCTL_ECHO, (void *)&echo, sizeof(echo), NULL, 0) < 0) {
		SMB_PUSH_ERR("ECHO_FAIL");
	}

	if (strlen(share) == 0) {
		// No share configured -> enumerate the server's shares so the user knows what to
		// set. Returns (false, "NO_SHARE", "<comma-separated names>"). Buffer 64-byte
		// aligned for the IOP->EE DMA (per OPL smblab.c:55 / ethsupport.c:499-523).
		static ShareEntry_t sharelist[128] __attribute__((aligned(64)));
		smbGetShareList_in_t getsharelist;
		memset(sharelist, 0, sizeof(sharelist));
		// smbman fills the buffer from the IOP via raw SIF DMA, which bypasses the EE
		// D-cache. Write back + invalidate BEFORE the devctl so no dirty zero line from
		// the memset overwrites DMA'd entries, and again AFTER so reads see RAM, not
		// stale cached zeros (silently-skipped share names).
		FlushCache(0);
		getsharelist.EE_addr = (void *)&sharelist[0];
		getsharelist.maxent = 128;
		int count = fileXioDevctl("smb0:", SMB_DEVCTL_GETSHARELIST, (void *)&getsharelist, sizeof(getsharelist), NULL, 0);
		FlushCache(0);
		char names[512];
		names[0] = '\0';
		for (int i = 0; i < count && i < 128; i++) {
			if (sharelist[i].ShareName[0] == '\0') {
				continue;
			}
			if (names[0] != '\0') {
				strncat(names, ", ", sizeof(names) - strlen(names) - 1);
			}
			strncat(names, sharelist[i].ShareName, sizeof(names) - strlen(names) - 1);
		}
		lua_pushboolean(L, false);
		lua_pushstring(L, "NO_SHARE");
		lua_pushstring(L, names);
		return 3;
	}
	strncpy(openshare.ShareName, share, sizeof(openshare.ShareName) - 1);
	if (fileXioDevctl("smb0:", SMB_DEVCTL_OPENSHARE, (void *)&openshare, sizeof(openshare), NULL, 0) < 0) {
		SMB_PUSH_ERR("SHARE_FAIL");
	}

	lua_pushboolean(L, true);
	lua_pushstring(L, "smb0:");
	return 2;
}
#undef SMB_GET_STR
#undef SMB_PUSH_ERR

// System.disconnectSMB() -- close the share + log off (mirror OPL ethSMBDisconnect,
// ethsupport.c:144-159). Called on SMB-page exit so the connection doesn't linger.
// Best-effort: the IRX stay loaded (lazy) and a later connectSMB re-LOGONs; errors
// here are nothing to recover from. No-op if SMB was never brought up.
static int lua_smb_disconnect(lua_State *L)
{
	if (lua_gettop(L) > 0) {
		return luaL_error(L, "Argument error: System.disconnectSMB() takes no arguments.");
	}
	if (smb_irx_loaded) {
		fileXioDevctl("smb0:", SMB_DEVCTL_CLOSESHARE, NULL, 0, NULL, 0);
		fileXioDevctl("smb0:", SMB_DEVCTL_LOGOFF, NULL, 0, NULL, 0);
	}
	lua_pushboolean(L, true);
	return 1;
}

static const luaL_Reg System_functions[] = {
	{"openFile",                   lua_openfile},
	{"readFile",                   lua_readfile},
	{"writeFile",                 lua_writefile},
	{"closeFile",                 lua_closefile},  
	{"seekFile",                   lua_seekfile},  
	{"sizeFile",                   lua_sizefile},
	//{"doesFileExist",            lua_checkexist}, BREAKS ERROR HANDLING IF DECLARED INSIDE TABLE. DONT ASK ME WHY
	{"currentDirectory",             lua_curdir},
	{"listDirectory",           	    lua_dir},
	{"createDirectory",           lua_createDir},
	{"removeDirectory",           lua_removeDir},
	{"removeFile",               lua_removeFile},
	{"rename",                       lua_rename},
	{"sleep",                         lua_sleep},
	{"getFreeMemory",         lua_getFreeMemory},
	{"exitToBrowser",                  lua_exit},
	{"getMCInfo",                 lua_getmcinfo},
	{"loadELF",                 	lua_loadELF},
	{"loadELFWithPartition",    	lua_loadELFWithPartition},
	{"loadELFRebootIOP",        	lua_loadELFRebootIOP},
	{"setExecKeepPfsMask",      lua_set_exec_keep_pfs_mask},
	{"checkValidDisc",       lua_checkValidDisc},
	{"getDiscType",             lua_getDiscType},
	{"checkDiscTray",         lua_checkDiscTray},
	{"GetArgv0",                   lua_popargv0},
	{"getAppDir",                 lua_getAppDir},
	{"getLaunchArgs",         lua_getLaunchArgs},
	{"getBootDeviceHint", lua_getBootDeviceHint},
	{"getEmbeddedAsset",      lua_getEmbeddedAsset},
	{"resolveAsset",           lua_resolveAsset},
	{"resolveAssetType",   lua_resolveAssetType},
	{"ensureBDM",              lua_ensure_bdm},
	{"ensureBDMFatFs",         lua_ensure_bdm_fatfs},
	{"ensureDev9",             lua_ensure_dev9},
	{"ensureUsbMass",          lua_ensure_usb_mass},
	{"getUsbDiag",            lua_get_usb_diag},
	{"iopHeapProbe",          lua_iop_heap_probe},
	{"getBootProfile",        lua_get_boot_profile},
	{"ensureCDFS",             lua_ensure_cdfs},
	{"ensureMmceman",          lua_ensure_mmceman},
	{"reinitPad",              lua_reinit_pad},
	{"initMX4SIO",             lua_mx4sio_init},
	{"initATA",                lua_ata_init},
	{"ataReady",               lua_ata_ready},
	{"initATAAsync",           lua_ata_init_async},
	{"initATAStatus",          lua_ata_init_status},
	{"getSio2Owner",           lua_get_sio2_owner},
	{"initSMB",                lua_smb_init},
	{"smbNetUp",               lua_smb_netup},
	{"connectSMB",             lua_smb_connect},
	{"disconnectSMB",          lua_smb_disconnect},
	{"bdmList",                lua_bdm_list},
	{"refreshMassBackends",    lua_refresh_mass_backends},
	{"getMassBackendInfo",     lua_get_mass_backend_info},
	{"getMassMountDriver",     lua_get_mass_mount_driver},
	{"getMassRootByBackendName", lua_get_mass_root_by_backend_name},
	{"findBDMByDriver",    lua_find_bdm_by_driver},
	{0, 0}
};


static int lua_sifloadmodule(lua_State *L){
	int argc = lua_gettop(L);
	if (argc != 1 && argc != 3) return luaL_error(L, "wrong number of arguments");
	const char *path = luaL_checkstring(L, 1);

	int arg_len = 0;
	const char *args = NULL;

	if(argc == 3){
		arg_len = luaL_checkinteger(L, 2);
		args = luaL_checkstring(L, 3);
	}
	
	int ret = 1;
	int id = SifLoadStartModule(path, arg_len, args, &ret);
	lua_pushinteger(L, id);
	lua_pushinteger(L, ret);
	return 2;
}


static int lua_sifloadmodulebuffer(lua_State *L){
	int argc = lua_gettop(L);
	if (argc != 2 && argc != 4) return luaL_error(L, "wrong number of arguments");
	const char* ptr = luaL_checkstring(L, 1);
	int size = luaL_checkinteger(L, 2);

	int arg_len = 0;
	const char *args = NULL;

	if(argc == 4){
		arg_len = luaL_checkinteger(L, 3);
		args = luaL_checkstring(L, 4);
	}
	int RET;
	int ID = SifExecModuleBuffer((void*)ptr, size, arg_len, args, &RET);
	lua_pushinteger(L, ID);
	lua_pushinteger(L, RET);
	return 2;
}

static const luaL_Reg Sif_functions[] = {
	{"loadModule",             			   lua_sifloadmodule},
	{"loadModuleBuffer",             lua_sifloadmodulebuffer},

	{0, 0}
};
#include <sio.h>
static bool init_sio = false;

static int lua_sio_print(lua_State *L) {
	if (!init_sio) {
		sio_init(38400,0,0,0,0);
		init_sio = true;
		sio_puts("EE UART Initialized at 38400 BAUD");
	}
  	int n = lua_gettop(L);
  	int i;
  	for (i = 1; i <= n; i++) {
  	  size_t l;
  	  const char *s = luaL_tolstring(L, i, &l); 
  	  if (i > 1)  
  	    sio_putc('\t');
	  sio_putsn(s);
  	  lua_pop(L, 1);
  	}
	if (n > 0) sio_putc('\n');
  	return 0;
}
void luaSystem_init(lua_State *L) {

	lua_register(L, "doesFileExist", lua_checkexist);
	lua_register(L, "doesFolderExist", lua_direxists);
	lua_register(L, "print_uart", lua_sio_print);

	lua_newtable(L);
	luaL_setfuncs(L, System_functions, 0);
	lua_setglobal(L, "System");

	lua_newtable(L);
	luaL_setfuncs(L, Sif_functions, 0);
	lua_setglobal(L, "IOP");

	lua_pushstring(L, app_dir);
	lua_setglobal(L, "APP_DIR");

	lua_pushinteger(L, ASSET_GENERIC);
	lua_setglobal(L, "ASSET_GENERIC");

	lua_pushinteger(L, ASSET_IMG);
	lua_setglobal(L, "ASSET_IMG");

	lua_pushinteger(L, ASSET_IRX);
	lua_setglobal(L, "ASSET_IRX");

	lua_pushinteger(L, mmce_slot0_ready);
	lua_setglobal(L, "MMCE_SLOT0_READY");

	lua_pushinteger(L, mmce_slot1_ready);
	lua_setglobal(L, "MMCE_SLOT1_READY");

	lua_pushinteger(L, O_RDONLY);
	lua_setglobal(L, "FREAD");

	lua_pushinteger(L, O_WRONLY);
	lua_setglobal (L, "FWRITE");

	lua_pushinteger(L, O_CREAT | O_WRONLY);
	lua_setglobal(L, "FCREATE");

	lua_pushinteger(L, O_RDWR);
	lua_setglobal(L, "FRDWR");
	
	lua_pushinteger(L, SEEK_SET);
	lua_setglobal(L, "SET");

	lua_pushinteger(L, SEEK_END);
	lua_setglobal(L, "END");

	lua_pushinteger(L, SEEK_CUR);
	lua_setglobal(L, "CUR");

	lua_pushinteger(L, 1);
	lua_setglobal(L, "READ_ONLY");

	lua_pushinteger(L, 2);
	lua_setglobal(L, "READ_WRITE");



	
}

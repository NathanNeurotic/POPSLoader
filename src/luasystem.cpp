#include <stdio.h>
#include <unistd.h>
#include <libmc.h>
#include <malloc.h>
#include <sys/fcntl.h>
#include <dirent.h>
#include <sys/stat.h>
#include <sifrpc.h>
#include <smod.h>
#include <string.h>
#define NEWLIB_PORT_AWARE
#include <fileXio_rpc.h>
#include <fileio.h>
#include <usbhdfsd-common.h>
#include "include/luaplayer.h"
#include "include/md5.h"
#include "include/graphics.h"

#include "include/system.h"
#include "include/dprintf.h"
#include "include/assets.h"

#define MAX_DIR_FILES 512

extern unsigned char mx4sio_bd_irx[];
extern unsigned int size_mx4sio_bd_irx;
extern unsigned char bdm_query_irx[];
extern unsigned int size_bdm_query_irx;

static bool LoadIrxCheckedBuffer(const char *name, unsigned char *irx, unsigned int size, int *out_id, int *out_ret);

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
static bool mx4sio_bd_loaded = false;
static bool mx4sio_runtime_ready = false;
static char mx4sio_runtime_root[16] = {0};

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
	DPRINTF("MX4SIO IRX load %s: id=%d ret=%d\n", name, id, ret);
	if (id < 0 || ret < 0) {
		DPRINTF("MX4SIO IRX load failed: %s id=%d ret=%d\n", name, id, ret);
		return false;
	}
	return true;
}

static bool ProbeDir(const char *path, int *out_ret)
{
	int fd = fileXioDopen(path);
	if (out_ret) {
		*out_ret = fd;
	}
	if (fd >= 0) {
		fileXioDclose(fd);
		return true;
	}
	return false;
}

static bool QueryMassDriverName(int idx, char out_driver[8])
{
	if (out_driver == NULL) {
		return false;
	}
	if (idx < 0 || idx > 9) {
		out_driver[0] = '\0';
		return false;
	}

	char mass_path[16];
	snprintf(mass_path, sizeof(mass_path), "mass%d:/", idx);

	int dd = fileXioDopen(mass_path);
	if (dd < 0) {
		out_driver[0] = '\0';
		return false;
	}

	char devid[8];
	memset(devid, 0, sizeof(devid));

	int *intptr_ctl = (int *)devid;
	int rc = fileXioIoctl(dd, USBMASS_IOCTL_GET_DRIVERNAME, (void*)"");
	*intptr_ctl = rc;
	fileXioDclose(dd);

	if (rc < 0 || devid[0] == '\0') {
		out_driver[0] = '\0';
		return false;
	}

	snprintf(out_driver, 8, "%s", devid);
	return true;
}

// MX4SIO init notes:
// - Bundle inventory (iop/embed/PS2SDK_MX4SIO): mx4sio_bd.irx.
// - IRX load order: mx4sio_bd.irx (PS2SDK).
// - Success condition: chosen MX4SIO prefix root is accessible.
// - TODO: verify any slot or adapter placement requirements for MX4SIO in hardware docs.
int mx4sio_init_and_get_root(const char *hint, char *out_root, size_t out_sz)
{
	if (out_root == NULL || out_sz == 0) {
		return -1;
	}

	if (mx4sio_runtime_ready && mx4sio_runtime_root[0] != '\0') {
		snprintf(out_root, out_sz, "%s", mx4sio_runtime_root);
		return 0;
	}

	DPRINTF("MX4SIO SDK init start\n");
	if (!mx4sio_bd_loaded) {
		smod_mod_info_t info;
		if (smod_get_mod_by_name("mx4sio_bd", &info) >= 0) {
			mx4sio_bd_loaded = true;
		} else {
			if (!LoadIrxCheckedBuffer("mx4sio_bd.irx", mx4sio_bd_irx, size_mx4sio_bd_irx, NULL, NULL)) {
				return -1;
			}
			mx4sio_bd_loaded = true;
		}
	}

	char boot_root[16] = {0};
	const char *slash = strchr(boot_path, '/');
	if (slash != NULL) {
		const size_t len = (size_t)(slash - boot_path + 1);
		if (len > 0 && len < sizeof(boot_root)) {
			memcpy(boot_root, boot_path, len);
			boot_root[len] = '\0';
			bool boot_is_mx4 = false;
			if (strncmp(boot_root, "mx4sio", 6) == 0) {
				boot_is_mx4 = true;
			} else {
				int boot_mass_idx = -1;
				if (strcmp(boot_root, "mass:/") == 0) {
					boot_mass_idx = 0;
				} else if (sscanf(boot_root, "mass%d:/", &boot_mass_idx) != 1) {
					boot_mass_idx = -1;
				}
				if (boot_mass_idx >= 0 && boot_mass_idx <= 9) {
					char driver[8];
					if (QueryMassDriverName(boot_mass_idx, driver)) {
						if (strcmp(driver, "sdc") == 0 || strcmp(driver, "mx4sio") == 0) {
							boot_is_mx4 = true;
						}
					}
				}
			}
			if (boot_is_mx4) {
				int boot_ret = -1;
				if (ProbeDir(boot_root, &boot_ret)) {
					snprintf(mx4sio_runtime_root, sizeof(mx4sio_runtime_root), "%s", boot_root);
					mx4sio_runtime_ready = true;
					snprintf(out_root, out_sz, "%s", mx4sio_runtime_root);
					return 0;
				}
			}
		}
	}

	const char *dedicated_candidates[] = {"mx4sio:/", "mx4sio0:/"};
	for (size_t i = 0; i < sizeof(dedicated_candidates) / sizeof(dedicated_candidates[0]); ++i) {
		const char *prefix = dedicated_candidates[i];
		int root_ret = -1;
		DPRINTF("MX4SIO probe dedicated prefix %s\n", prefix);
		bool root_ok = ProbeDir(prefix, &root_ret);
		DPRINTF("MX4SIO probe %s ret=%d ok=%d\n", prefix, root_ret, root_ok);
		if (root_ok) {
			DPRINTF("Chosen MX4SIO dedicated prefix: %s\n", prefix);
			snprintf(mx4sio_runtime_root, sizeof(mx4sio_runtime_root), "%s", prefix);
			mx4sio_runtime_ready = true;
			snprintf(out_root, out_sz, "%s", mx4sio_runtime_root);
			return 0;
		}
	}
	if (hint != NULL && hint[0] != '\0') {
		int hint_ret = -1;
		DPRINTF("MX4SIO probe hint %s\n", hint);
		bool hint_ok = ProbeDir(hint, &hint_ret);
		if (hint_ok) {
			DPRINTF("Chosen MX4SIO hint prefix: %s\n", hint);
			snprintf(mx4sio_runtime_root, sizeof(mx4sio_runtime_root), "%s", hint);
			mx4sio_runtime_ready = true;
			snprintf(out_root, out_sz, "%s", mx4sio_runtime_root);
			return 0;
		} else {
			DPRINTF("MX4SIO probe %s ret=%d ok=%d\n", hint, hint_ret, hint_ok);
		}
	}

	for (int i = 0; i <= 9; ++i) {
		char driver[8];
		bool has_driver = QueryMassDriverName(i, driver);
		DPRINTF("MX4SIO probe mass%d driver=%s ok=%d\n", i, has_driver ? driver : "", has_driver);
		if (!has_driver) {
			continue;
		}
		if (strcmp(driver, "sdc") != 0 && strcmp(driver, "mx4sio") != 0) {
			continue;
		}
		char mass_prefix[16];
		snprintf(mass_prefix, sizeof(mass_prefix), "mass%d:/", i);
		int root_ret = -1;
		bool root_ok = ProbeDir(mass_prefix, &root_ret);
		DPRINTF("MX4SIO probe %s ret=%d ok=%d\n", mass_prefix, root_ret, root_ok);
		if (!root_ok) {
			continue;
		}
		DPRINTF("Chosen MX4SIO mass prefix: %s\n", mass_prefix);
		snprintf(mx4sio_runtime_root, sizeof(mx4sio_runtime_root), "%s", mass_prefix);
		mx4sio_runtime_ready = true;
		snprintf(out_root, out_sz, "%s", mx4sio_runtime_root);
		return 0;
	}
	return -1;
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
	           } while (temp_path[idx] != '/');
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
	char path[255];
	
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

static int lua_movefile(lua_State *L)
{
	const char *path = luaL_checkstring(L, 1);
	if(!path) return luaL_error(L, "Argument error: System.removeFile(filename) takes a filename as string as argument.");
		const char *oldName = luaL_checkstring(L, 1);
	const char *newName = luaL_checkstring(L, 2);
	if(!oldName || !newName)
		return luaL_error(L, "Argument error: System.rename(source, destination) takes two filenames as strings as arguments.");

	char buf[BUFSIZ];
    size_t size;

	int source = open(oldName, O_RDONLY, 0);
    int dest = open(newName, O_WRONLY | O_CREAT | O_TRUNC, 0644);

	while ((size = read(source, buf, BUFSIZ)) > 0) {
	   write(dest, buf, size);
    }

    close(source);
    close(dest);

	remove(oldName);

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

	char buf[BUFSIZ];
    size_t size;

	int source = open(oldName, O_RDONLY, 0);
    int dest = open(newName, O_WRONLY | O_CREAT | O_TRUNC, 0644);

	while ((size = read(source, buf, BUFSIZ)) > 0) {
	   write(dest, buf, size);
    }

    close(source);
    close(dest);

	remove(oldName);
	
	return 0;
}

static int lua_copyfile(lua_State *L)
{
	const char *ogfile = luaL_checkstring(L, 1);
	const char *newfile = luaL_checkstring(L, 2);
	if(!ogfile || !newfile)
		return luaL_error(L, "Argument error: System.copyFile(source, destination) takes two filenames as strings as arguments.");

	char buf[BUFSIZ];
    size_t size;

	int source = open(ogfile, O_RDONLY, 0);
    int dest = open(newfile, O_WRONLY | O_CREAT | O_TRUNC, 0644);

	while ((size = read(source, buf, BUFSIZ)) > 0) {
	   write(dest, buf, size);
    }

    close(source);
    close(dest);
	
	return 0;
}

static char modulePath[256];

static void setModulePath()
{
	getcwd( modulePath, 256 );
}

static int lua_md5sum(lua_State *L)
{
	size_t size;
	const char *string = luaL_checklstring(L, 1, &size);
	if (!string) return luaL_error(L, "Argument error: System.md5sum(string) takes a string as argument.");

	int i;
	char result[33];        
	u8 digest[16];

	MD5_CTX ctx;
    MD5Init( &ctx );
    MD5Update( &ctx, (u8 *)string, size );
    MD5Final( digest, &ctx );

	for (i = 0; i < 16; i++) sprintf(result + 2 * i, "%02x", digest[i]);
	lua_pushstring(L, result);
	
	return 1;
}

static int lua_sleep(lua_State *L)
{
	if (lua_gettop(L) != 1) return luaL_error(L, "milliseconds expected.");
	int sec = luaL_checkinteger(L, 1);
	sleep(sec);
	return 0;
}

static int lua_delayThreadMs(lua_State *L)
{
	if (lua_gettop(L) != 1) return luaL_error(L, "milliseconds expected.");
	int ms = luaL_checkinteger(L, 1);
	if (ms < 0) {
		ms = 0;
	}
	usleep((useconds_t)ms * 1000);
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
	asm volatile(
            "li $3, 0x04;"
            "syscall;"
            "nop;"
        );
	return 0;
}


void recursive_mkdir(char *dir) {
	char *p = dir;
	while (p) {
		char *p2 = strstr(p, "/");
		if (p2) {
			p2[0] = 0;
			mkdir(dir, 0777);
			p = p2 + 1;
			p2[0] = '/';
		} else break;
	}
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
	uint8_t *buffer = (uint8_t*)malloc(size + 1);
	int len = read(file,buffer, size);
	buffer[len] = 0;
	lua_pushlstring(L,(const char*)buffer,len);
	free(buffer);
	return 1;
}


static int lua_writefile(lua_State *L){
	int argc = lua_gettop(L);
	if (argc != 3) return luaL_error(L, "wrong number of arguments");
	int fileHandle = luaL_checkinteger(L, 1);
	const char *text = luaL_checkstring(L, 2);
	int size = luaL_checknumber(L, 3);
	write(fileHandle, text, size);
	return 0;
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
	uint32_t cur_off = lseek(fileHandle, 0, SEEK_CUR);
	uint32_t size = lseek(fileHandle, 0, SEEK_END);
	lseek(fileHandle, cur_off, SEEK_SET);
	lua_pushinteger(L, size);
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
	static char *argv_static[2];
	printf("# Loading ELF '%s' iop_reboot=%d, extra_args=%d\n", elftoload, rebootIOP, extra_args);
	if (extra_args > 0) {
		const char *selector = luaL_checkstring(L, 3);
		snprintf(selector_buf, sizeof(selector_buf), "%s", selector ? selector : "");
		argv_static[0] = selector_buf;
		argv_static[1] = NULL;
		printf("# Loading ELF argv0='%s' argc=1\n", argv_static[0]);
		int rc = LoadELFFromFileExecPS2(elftoload, 1, argv_static);
		lua_pushinteger(L, rc);
		return 1;
	}
	printf("# Loading ELF argv0 default (argc=0)\n");
	int rc = LoadELFFromFile(elftoload, 0, NULL);
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

extern void *_gp;
extern int mmce_slot0_ready;
extern int mmce_slot1_ready;

#define BUFSIZE (64*1024)

static volatile off_t progress, max_progress;

struct pathMap {
	const char* in;
	const char* out;
};

static int copyThread(void* data)
{
	pathMap* paths = (pathMap*)data;

    char buffer[BUFSIZE];
    int in = open(paths->in, O_RDONLY, 0);
    int out = open(paths->out, O_WRONLY | O_CREAT | O_TRUNC, 644);

    // Get the input file size
	uint32_t size = lseek(in, 0, SEEK_END);
	lseek(in, 0, SEEK_SET);

    progress = 0;
    max_progress = size;

    ssize_t bytes_read;
    while((bytes_read = read(in, buffer, BUFSIZE)) > 0)
    {
        write(out, buffer, bytes_read);
        progress += bytes_read;
    }

    // copy is done, or an error occurred
    close(in);
    close(out);
	free(paths);
	ExitDeleteThread();
    return 0;
}


static int lua_copyasync(lua_State *L){
	int argc = lua_gettop(L);
	if (argc != 2) return luaL_error(L, "wrong number of arguments");

	pathMap* copypaths = (pathMap*)malloc(sizeof(pathMap));

	copypaths->in = luaL_checkstring(L, 1);
	copypaths->out = luaL_checkstring(L, 2);
	
	static u8 copyThreadStack[65*1024] __attribute__((aligned(16)));
	
	ee_thread_t thread_param;
	
	thread_param.gp_reg = &_gp;
    thread_param.func = (void*)copyThread;
    thread_param.stack = (void *)copyThreadStack;
    thread_param.stack_size = sizeof(copyThreadStack);
    thread_param.initial_priority = 0x12;
	int thread = CreateThread(&thread_param);
	
	StartThread(thread, (void*)copypaths);
	return 0;
}


static int lua_getfileprogress(lua_State *L) {
	int argc = lua_gettop(L);
	if (argc != 0) return luaL_error(L, "wrong number of arguments");

	lua_newtable(L);

    lua_pushstring(L, "current");
    lua_pushinteger(L, (int)progress);
    lua_settable(L, -3);

    lua_pushstring(L, "final");
    lua_pushinteger(L, (int)max_progress);
    lua_settable(L, -3);

	return 1;
}

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



static int lua_getSettingsRoot(lua_State *L) {
	lua_pushstring(L, Asset_GetSettingsRoot());
	return 1;
}

static int lua_getMassDriverName(lua_State *L)
{
	int argc = lua_gettop(L);
	if (argc != 1) {
		return luaL_error(L, "Argument error: System.getMassDriverName(index) takes one argument.");
	}
	int idx = luaL_checkinteger(L, 1);
	if (idx < 0 || idx > 9) {
		lua_pushnil(L);
		return 1;
	}

	char driver[8];
	if (!QueryMassDriverName(idx, driver)) {
		lua_pushnil(L);
		return 1;
	}
	lua_pushstring(L, driver);
	return 1;
}

static int lua_mx4sio_init(lua_State *L)
{
	const char *hint = NULL;
	int argc = lua_gettop(L);
	if (argc > 1) {
		return luaL_error(L, "Argument error: System.initMX4SIO() takes at most one argument.");
	}
	if (argc == 1 && !lua_isnil(L, 1)) {
		hint = luaL_checkstring(L, 1);
	}
	char root[16] = {0};
	int rc = mx4sio_init_and_get_root(hint, root, sizeof(root));
	lua_pushboolean(L, rc == 0);
	if (rc == 0) {
		lua_pushstring(L, root);
	} else {
		lua_pushnil(L);
	}
	return 2;
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
	{"moveFile",	               lua_movefile},
	{"copyFile",	               lua_copyfile},
	{"threadCopyFile",	          lua_copyasync},
	{"getFileProgress",	    lua_getfileprogress},
	{"removeFile",               lua_removeFile},
	{"rename",                       lua_rename},
	{"md5sum",                       lua_md5sum},
	{"sleep",                         lua_sleep},
	{"delayThreadMs",          lua_delayThreadMs},
	{"getFreeMemory",         lua_getFreeMemory},
	{"exitToBrowser",                  lua_exit},
	{"getMCInfo",                 lua_getmcinfo},
	{"loadELF",                 	lua_loadELF},
	{"checkValidDisc",       lua_checkValidDisc},
	{"getDiscType",             lua_getDiscType},
	{"checkDiscTray",         lua_checkDiscTray},
	{"GetArgv0",                   lua_popargv0},
	{"getAppDir",                 lua_getAppDir},
	{"getSettingsRoot",       lua_getSettingsRoot},
	{"resolveAsset",           lua_resolveAsset},
	{"resolveAssetType",   lua_resolveAssetType},
	{"getMassDriverName",        lua_getMassDriverName},
	{"initMX4SIO",             lua_mx4sio_init},
	{"bdmList",                lua_bdm_list},
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

	setModulePath();
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

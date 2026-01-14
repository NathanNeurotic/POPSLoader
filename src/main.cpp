
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sifrpc.h>
#include <loadfile.h>
#include <libmc.h>
#include <libcdvd.h>
#include <iopheap.h>
#include <iopcontrol.h>
#include <smod.h>
#include <audsrv.h>
#include <sys/stat.h>

#include <dirent.h>

#include <sbv_patches.h>
#include <smem.h>

#include "include/graphics.h"
#include "include/sound.h"
#include "include/luaplayer.h"
#include "include/pad.h"
#include "include/dprintf.h"

#define NEWLIB_PORT_AWARE
#include <fileXio_rpc.h>
#include <fileio.h>

extern "C"{
#include <libds34bt.h>
#include <libds34usb.h>
}

extern char bootString[];
extern unsigned int size_bootString;

extern unsigned char iomanX_irx[];
extern unsigned int size_iomanX_irx;

extern unsigned char fileXio_irx[];
extern unsigned int size_fileXio_irx;

extern unsigned char sio2man_irx[];
extern unsigned int size_sio2man_irx;

extern unsigned char mcman_irx[];
extern unsigned int size_mcman_irx;

extern unsigned char mcserv_irx[];
extern unsigned int size_mcserv_irx;

extern unsigned char padman_irx[];
extern unsigned int size_padman_irx;

extern unsigned char libsd_irx[];
extern unsigned int size_libsd_irx;

extern unsigned char cdfs_irx[];
extern unsigned int size_cdfs_irx;

extern unsigned char usbd_irx[];
extern unsigned int size_usbd_irx;

extern unsigned char bdm_irx[];
extern unsigned int size_bdm_irx;

extern unsigned char bdmfs_fatfs_irx[];
extern unsigned int size_bdmfs_fatfs_irx;

extern unsigned char usbmass_bd_irx[];
extern unsigned int size_usbmass_bd_irx;

extern unsigned char audsrv_irx[];
extern unsigned int size_audsrv_irx;

extern unsigned char ds34usb_irx[];
extern unsigned int size_ds34usb_irx;

extern unsigned char ds34bt_irx[];
extern unsigned int size_ds34bt_irx;

extern unsigned char mmceman_irx[];
extern unsigned int size_mmceman_irx;

char boot_path[255];
static const char *kMmceDevices[] = {"mmce0:/", "mmce1:/"};
static const char *kFallbackDevice = "mass:/";
static const int kDeviceRetries = 50;

static bool hasDevicePrefix(const char *path)
{
    return path != NULL && strchr(path, ':') != NULL;
}

static void normalizeDevicePath(char *path)
{
    if (path == NULL) {
        return;
    }

    char *colon = strchr(path, ':');
    if (colon == NULL) {
        return;
    }

    char *slash = colon + 1;
    while (slash[0] == '/' && slash[1] == '/') {
        memmove(slash + 1, slash + 2, strlen(slash + 2) + 1);
    }
}

static int waitForDevice(const char *device, int retries)
{
    struct stat buffer;
    int ret = -1;

    while (ret != 0 && retries > 0) {
        ret = stat(device, &buffer);
        /* Wait until the device is ready */
        nopdelay();
        retries--;
    }

    return ret;
}

static const char *detectPreferredDevice(void)
{
    for (size_t idx = 0; idx < (sizeof(kMmceDevices) / sizeof(kMmceDevices[0])); ++idx) {
        if (waitForDevice(kMmceDevices[idx], kDeviceRetries) == 0) {
            return kMmceDevices[idx];
        }
    }

    if (waitForDevice(kFallbackDevice, kDeviceRetries) == 0) {
        return kFallbackDevice;
    }

    return kFallbackDevice;
}

void setLuaBootPath(int argc, char ** argv, int idx, const char *preferred_device)
{
    boot_path[0] = '\0';
    if (argc>=(idx+1))
    {

	char *p;
	if ((p = strrchr(argv[idx], '/'))!=NULL) {
	    snprintf(boot_path, sizeof(boot_path), "%s", argv[idx]);
	    p = strrchr(boot_path, '/');
	if (p!=NULL)
	    p[1]='\0';
	} else if ((p = strrchr(argv[idx], '\\'))!=NULL) {
	   snprintf(boot_path, sizeof(boot_path), "%s", argv[idx]);
	   p = strrchr(boot_path, '\\');
	   if (p!=NULL)
	     p[1]='\0';
	} else if ((p = strchr(argv[idx], ':'))!=NULL) {
	   snprintf(boot_path, sizeof(boot_path), "%s", argv[idx]);
	   p = strchr(boot_path, ':');
	   if (p!=NULL)
	   p[1]='\0';
	}

    }
    
    // check if path needs patching
    normalizeDevicePath(boot_path);

    if (boot_path[0] == '\0' || !hasDevicePrefix(boot_path)) {
        snprintf(boot_path, sizeof(boot_path), "%s", preferred_device);
    }
    
}


void initMC(void)
{
   int ret;
   // mc variables
   int mc_Type, mc_Free, mc_Format;

   DPRINTF("initMC: Initializing Memory Card\n");
   ret = mcInit(MC_TYPE_XMC);
   if( ret < 0 ) {
        DPRINTF("initMC: failed to initialize memcard RPC.\n");
   } else {
        DPRINTF("initMC: memcard RPC started successfully.\n");
   }
   // Since this is the first call, -1 should be returned.
   // makes me sure that next ones will work !
   mcGetInfo(0, 0, &mc_Type, &mc_Free, &mc_Format); 
   mcSync(MC_WAIT, NULL, &ret);
}

static char* ARGV0 = NULL;
char* GetArgv0(void) {
    return ARGV0;
}

#define LOAD_IRX(_irx, argc, arglist) \
    ID = SifExecModuleBuffer(&_irx, size_##_irx, argc, arglist, &RET); \
    printf("%s: id:%d, ret:%d\n", #_irx, ID, RET)
#define LOAD_IRX_NARG(_irx) LOAD_IRX(_irx, 0, NULL)

int main(int argc, char * argv[])
{
    int ID, RET;
    if (argc > 0) ARGV0 = argv[0];
    const char * errMsg;

#ifdef RESET_IOP  
    SifInitRpc(0);
    while (!SifIopReset("", 0)){};
    while (!SifIopSync()){};
    SifInitRpc(0);
#endif
    
    // install sbv patch fix
    DPRINTF("Installing SBV Patches...\n");
    sbv_patch_enable_lmb();
    sbv_patch_disable_prefix_check(); 
    sbv_patch_fileio(); 

#ifdef POWERPC_UART
	LOAD_IRX_NARG(ppctty_irx);
#endif

	LOAD_IRX_NARG(iomanX_irx);
	LOAD_IRX_NARG(fileXio_irx);
	fileXioInit();

	LOAD_IRX_NARG(sio2man_irx);
	LOAD_IRX_NARG(mmceman_irx);
    LOAD_IRX_NARG(mcman_irx);
    LOAD_IRX_NARG(mcserv_irx);
    initMC();
    LOAD_IRX_NARG(padman_irx);

    LOAD_IRX_NARG(libsd_irx);


    // load USB modules    
    LOAD_IRX_NARG(usbd_irx);

    
    int ds3pads = 1;
    LOAD_IRX(ds34usb_irx, 4, (char *)&ds3pads);
    LOAD_IRX(ds34bt_irx, 4, (char *)&ds3pads);
    ds34usb_init();
    ds34bt_init();

    LOAD_IRX_NARG(bdm_irx);
    LOAD_IRX_NARG(bdmfs_fatfs_irx);
    LOAD_IRX_NARG(usbmass_bd_irx);

    LOAD_IRX_NARG(cdfs_irx);

    LOAD_IRX_NARG(audsrv_irx);

    const char *preferred_device = detectPreferredDevice();
    DPRINTF("Preferred device: %s\n", preferred_device);

    setLuaBootPath (argc, argv, 0, preferred_device);
	// Lua init
	// init internals library
    
    // graphics (gsKit)
    initGraphics();

    pad_init();

    // set base path luaplayer
    chdir(boot_path); 

    DPRINTF("boot path : %s\n", boot_path);
	dbgprintf("boot path : %s\n", boot_path);
    
    while (1)
    {
        errMsg = runScript(bootString, true);

        init_scr();

        if (errMsg != NULL)
        {
            scr_setfontcolor(0x0000ff);
            sleep(1); //ensures message is printed no matter what
		    scr_clear();
		    scr_setXY(5, 2);
		    scr_printf("Enceladus ERROR!\n");
		    scr_printf(errMsg);
		    puts(errMsg);
		    scr_printf("\nPress [start] to restart\n");
        	while (!isButtonPressed(PAD_START)) {
                	sleep(1);
		    }
            scr_setfontcolor(0xffffff);
        }

    }

	return 0;
}

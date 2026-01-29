#include <bdm.h>
#include <errno.h>
#include <iomanX.h>
#include <irx.h>
#include <loadcore.h>
#include <sysclib.h>
#include <types.h>

#include "irx_imports.h"
#include "popsbdm_devctl.h"

IRX_ID("popsbdm", 1, 0);

#define POPSBDM_MAX_DEVICES 16

static int popsbdm_open(iomanX_iop_file_t *f, const char *name, int flags, int mode)
{
	(void)f;
	(void)name;
	(void)flags;
	(void)mode;
	return 0;
}

static int popsbdm_close(iomanX_iop_file_t *f)
{
	(void)f;
	return 0;
}

static int popsbdm_name_matches(const char *name, const char *prefix)
{
	size_t prefix_len = strlen(prefix);
	return strncmp(name, prefix, prefix_len) == 0;
}

static void popsbdm_detect_backend(popsbdm_backend_info_t *out)
{
	struct block_device *devices[POPSBDM_MAX_DEVICES];
	int found_usb = 0;
	int found_mx4sio = 0;

	memset(out, 0, sizeof(*out));
	out->backend = POPSBDM_BACKEND_UNKNOWN;
	out->detail[0] = '\0';

	memset(devices, 0, sizeof(devices));
	bdm_get_bd(devices, POPSBDM_MAX_DEVICES);

	for (int i = 0; i < POPSBDM_MAX_DEVICES; ++i) {
		struct block_device *bd = devices[i];
		if (bd == NULL || bd->name == NULL) {
			continue;
		}
		// TODO: verify driver name strings for mx4sio/usbmass in PS2SDK BDM backends.
		if (popsbdm_name_matches(bd->name, "mx4sio")) {
			found_mx4sio = 1;
		} else if (popsbdm_name_matches(bd->name, "usbmass")) {
			found_usb = 1;
		}
	}

	if (found_mx4sio && !found_usb) {
		out->backend = POPSBDM_BACKEND_MX4SIO;
		strncpy(out->detail, "mx4sio", sizeof(out->detail) - 1);
	} else if (found_usb && !found_mx4sio) {
		out->backend = POPSBDM_BACKEND_USB;
		strncpy(out->detail, "usbmass", sizeof(out->detail) - 1);
	} else if (found_usb && found_mx4sio) {
		strncpy(out->detail, "usbmass+mx4sio", sizeof(out->detail) - 1);
	}
	out->detail[sizeof(out->detail) - 1] = '\0';
}

static int popsbdm_devctl(iomanX_iop_file_t *f, const char *name, int cmd, void *arg,
                          unsigned int arglen, void *buf, unsigned int buflen)
{
	(void)f;
	(void)name;
	(void)arg;
	(void)arglen;

	if (cmd != POPSBDM_DEVCTL_GET_BACKEND) {
		return -EINVAL;
	}
	if (buf == NULL || buflen < sizeof(popsbdm_backend_info_t)) {
		return -EINVAL;
	}
	popsbdm_backend_info_t *out = (popsbdm_backend_info_t *)buf;
	popsbdm_detect_backend(out);
	return 0;
}

static iomanX_iop_device_ops_t popsbdm_ops = {
	.open = popsbdm_open,
	.close = popsbdm_close,
	.devctl = popsbdm_devctl,
};

static iomanX_iop_device_t popsbdm_device = {
	.name = "popsbdm",
	.type = IOP_DT_FS,
	.version = 1,
	.desc = "POPS BDM backend",
	.ops = &popsbdm_ops,
};

int _start(int argc, char *argv[])
{
	(void)argc;
	(void)argv;
	return iomanX_AddDrv(&popsbdm_device) ? MODULE_NO_RESIDENT_END : MODULE_RESIDENT_END;
}

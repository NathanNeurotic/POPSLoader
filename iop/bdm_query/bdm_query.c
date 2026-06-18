#include <bdm.h>
#include <irx.h>
#include <loadcore.h>
#include <sifrpc.h>
#include <sysclib.h>
#include <thbase.h>
#include <types.h>

#include "irx_imports.h"

#define BDM_QUERY_RPC_ID 0xB0D10B00
#define BDM_QUERY_RPC_GET_LIST 0
#define BDM_QUERY_RPC_GET_SERIAL 1
#define BDM_QUERY_MAX_DEVICES 32

IRX_ID("bdm_query", 1, 0);

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

/* GET_SERIAL: EE sends a parId (== the mass slot index, see the EE-side
 * BuildMassRootPath(parId) correlation), IOP reads sector 0 of that partition's
 * block device and returns the FAT/exFAT volume serial. Best-effort: valid=0 on
 * any failure so the EE falls back to its driver-name heuristic. */
typedef struct bdm_serial_req {
	u32 parId;
} bdm_serial_req_t;

typedef struct bdm_serial_resp {
	u32 valid;
	u32 serial;
} bdm_serial_resp_t;

static SifRpcDataQueue_t bdm_rpc_queue;
static SifRpcServerData_t bdm_rpc_server;
static u8 bdm_rpc_buffer[64] __attribute__((aligned(16)));
static bdm_dev_list_t bdm_response __attribute__((aligned(16)));
static bdm_serial_resp_t bdm_serial_response __attribute__((aligned(16)));
static u8 bdm_sector_buf[4096] __attribute__((aligned(64)));

/* Read a 32-bit little-endian value byte-wise (offsets like 0x43 are unaligned;
 * a direct u32 load would fault on the IOP's MIPS core). */
static u32 bdm_read_le32(const u8 *p)
{
	return (u32)p[0] | ((u32)p[1] << 8) | ((u32)p[2] << 16) | ((u32)p[3] << 24);
}

/* Local byte compare -- the IOP module's sysclib imports do not include memcmp
 * (memset is available, memcmp is not), so avoid it. */
static int bdm_bytes_eq(const u8 *a, const char *b, int n)
{
	for (int i = 0; i < n; ++i) {
		if (a[i] != (u8)b[i]) {
			return 0;
		}
	}
	return 1;
}

static void *bdm_query_rpc_handler(int func, void *buf, int size)
{
	(void)buf;
	(void)size;

	if (func == BDM_QUERY_RPC_GET_LIST) {
		struct block_device *devices[BDM_QUERY_MAX_DEVICES];
		unsigned int count = 0;

		memset(&bdm_response, 0, sizeof(bdm_response));
		memset(devices, 0, sizeof(devices));
		bdm_get_bd(devices, BDM_QUERY_MAX_DEVICES);

		for (unsigned int i = 0; i < BDM_QUERY_MAX_DEVICES; ++i) {
			struct block_device *bd = devices[i];
			if (bd == NULL || bd->name == NULL) {
				continue;
			}
			bdm_dev_info_t *out = &bdm_response.devs[count];
			strncpy(out->name, bd->name, sizeof(out->name) - 1);
			out->name[sizeof(out->name) - 1] = '\0';
			out->devNr = bd->devNr;
			out->parNr = bd->parNr;
			out->parId = bd->parId;
			out->sectorSize = bd->sectorSize;
			out->sectorCount = bd->sectorCount;
			count++;
		}
		bdm_response.count = count;
		return &bdm_response;
	}

	if (func == BDM_QUERY_RPC_GET_SERIAL) {
		struct block_device *devices[BDM_QUERY_MAX_DEVICES];
		bdm_serial_req_t *req = (bdm_serial_req_t *)buf;

		memset(&bdm_serial_response, 0, sizeof(bdm_serial_response));
		if (req == NULL) {
			return &bdm_serial_response;
		}

		memset(devices, 0, sizeof(devices));
		bdm_get_bd(devices, BDM_QUERY_MAX_DEVICES);

		for (unsigned int i = 0; i < BDM_QUERY_MAX_DEVICES; ++i) {
			struct block_device *bd = devices[i];
			if (bd == NULL || bd->name == NULL || bd->read == NULL) {
				continue;
			}
			if ((u32)bd->parId != req->parId) {
				continue;
			}
			/* Sector 0 = the partition VBR. Validity is gated on the FS
			 * signature, not the read() return code (which varies), so a
			 * failed/garbage read simply yields valid=0. */
			bd->read(bd, 0, bdm_sector_buf, 1);
			if (bdm_bytes_eq(&bdm_sector_buf[3], "EXFAT   ", 8)) {
				bdm_serial_response.serial = bdm_read_le32(&bdm_sector_buf[0x64]);
				bdm_serial_response.valid = 1;
			} else if (bdm_bytes_eq(&bdm_sector_buf[0x52], "FAT32", 5)) {
				bdm_serial_response.serial = bdm_read_le32(&bdm_sector_buf[0x43]);
				bdm_serial_response.valid = 1;
			} else if (bdm_bytes_eq(&bdm_sector_buf[0x36], "FAT", 3)) {
				bdm_serial_response.serial = bdm_read_le32(&bdm_sector_buf[0x27]);
				bdm_serial_response.valid = 1;
			}
			break;
		}
		return &bdm_serial_response;
	}

	return NULL;
}

static void bdm_query_rpc_thread(void *arg)
{
	(void)arg;
	sceSifInitRpc(0);
	sceSifSetRpcQueue(&bdm_rpc_queue, GetThreadId());
	sceSifRegisterRpc(&bdm_rpc_server, BDM_QUERY_RPC_ID, bdm_query_rpc_handler,
	                  bdm_rpc_buffer, NULL, NULL, &bdm_rpc_queue);
	sceSifRpcLoop(&bdm_rpc_queue);
}

int _start(int argc, char *argv[])
{
	iop_thread_t thread;
	int thread_id;

	(void)argc;
	(void)argv;

	thread.attr = TH_C;
	thread.option = 0;
	thread.thread = bdm_query_rpc_thread;
	thread.priority = 40;
	thread.stacksize = 0x800;

	thread_id = CreateThread(&thread);
	if (thread_id >= 0) {
		StartThread(thread_id, NULL);
	}

	return MODULE_RESIDENT_END;
}

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

static SifRpcDataQueue_t bdm_rpc_queue;
static SifRpcServerData_t bdm_rpc_server;
static u8 bdm_rpc_buffer[64] __attribute__((aligned(16)));
static bdm_dev_list_t bdm_response __attribute__((aligned(16)));

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

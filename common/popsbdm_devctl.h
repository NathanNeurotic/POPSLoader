#ifndef POPSBDM_DEVCTL_H
#define POPSBDM_DEVCTL_H

#ifdef __cplusplus
extern "C" {
#endif

#define POPSBDM_DEVCTL_GET_BACKEND 0xB001

typedef enum popsbdm_backend {
	POPSBDM_BACKEND_UNKNOWN = 0,
	POPSBDM_BACKEND_USB = 1,
	POPSBDM_BACKEND_MX4SIO = 2
} popsbdm_backend_t;

#define POPSBDM_BACKEND_DETAIL_LEN 32

typedef struct popsbdm_backend_info {
	int backend;
	char detail[POPSBDM_BACKEND_DETAIL_LEN];
} popsbdm_backend_info_t;

#ifdef __cplusplus
}
#endif

#endif

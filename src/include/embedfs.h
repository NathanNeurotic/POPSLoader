#pragma once

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

int embedfs_exists(const char *path);
int embedfs_get(const char *path, const uint8_t **out_data, size_t *out_size);
const char *embedfs_normalize_path(const char *in);

#ifdef __cplusplus
}
#endif

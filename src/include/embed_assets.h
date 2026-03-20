#ifndef EMBED_ASSETS_H
#define EMBED_ASSETS_H

#include <stddef.h>
#include <stdint.h>

int embedded_get(const char* path_or_name, const uint8_t** out_data, size_t* out_size);

#endif

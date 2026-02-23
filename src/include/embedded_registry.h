#pragma once
#include <stddef.h>

bool EmbeddedExists(const char* path);
bool EmbeddedGet(const char* path, const void** data, size_t* size, bool* is_compressed);

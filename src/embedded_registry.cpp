#include <string.h>
#include "include/embedded_registry.h"

#include "../asm/embedded_registry.generated.h"

static const size_t kEmbeddedCount = sizeof(kEmbeddedEntries) / sizeof(kEmbeddedEntries[0]);

bool EmbeddedExists(const char* path)
{
    const void* data = NULL;
    size_t size = 0;
    bool comp = false;
    return EmbeddedGet(path, &data, &size, &comp);
}

bool EmbeddedGet(const char* path, const void** data, size_t* size, bool* is_compressed)
{
    if (!path || !data || !size || !is_compressed) return false;
    for (size_t i = 0; i < kEmbeddedCount; ++i) {
        if (strcmp(kEmbeddedEntries[i].path, path) == 0) {
            *data = kEmbeddedEntries[i].start;
            *size = kEmbeddedEntries[i].size;
            *is_compressed = kEmbeddedEntries[i].compressed;
            return true;
        }
    }
    return false;
}

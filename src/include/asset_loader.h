#pragma once
#include <stddef.h>

struct AssetBuffer {
    void* data;
    size_t size;
    bool owned;
};

bool LoadAsset(const char* path, AssetBuffer* out);
void FreeAsset(AssetBuffer* asset);

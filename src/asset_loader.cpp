#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

#include "include/asset_loader.h"
#include "include/embedded_registry.h"
#include "include/luaplayer.h"

static bool InflateGzip(const void* in_data, size_t in_size, void** out_data, size_t* out_size)
{
    if (!in_data || in_size == 0 || !out_data || !out_size) return false;

    z_stream strm;
    memset(&strm, 0, sizeof(strm));
    strm.next_in = (Bytef*)in_data;
    strm.avail_in = (uInt)in_size;

    if (inflateInit2(&strm, 16 + MAX_WBITS) != Z_OK) return false;

    size_t cap = in_size * 2;
    if (cap < 1024) cap = 1024;
    unsigned char* out = (unsigned char*)malloc(cap);
    if (!out) {
        inflateEnd(&strm);
        return false;
    }

    int ret = Z_OK;
    while (ret == Z_OK) {
        if (strm.total_out >= cap) {
            size_t new_cap = cap * 2;
            unsigned char* grown = (unsigned char*)realloc(out, new_cap);
            if (!grown) {
                free(out);
                inflateEnd(&strm);
                return false;
            }
            out = grown;
            cap = new_cap;
        }
        strm.next_out = out + strm.total_out;
        strm.avail_out = (uInt)(cap - strm.total_out);
        ret = inflate(&strm, Z_NO_FLUSH);
    }

    if (ret != Z_STREAM_END) {
        free(out);
        inflateEnd(&strm);
        return false;
    }

    *out_size = strm.total_out;
    *out_data = out;
    inflateEnd(&strm);
    return true;
}

static bool ReadFileAll(const char* path, AssetBuffer* out)
{
    FILE* f = fopen(path, "rb");
    if (!f) return false;
    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return false; }
    long sz = ftell(f);
    if (sz <= 0) { fclose(f); return false; }
    if (fseek(f, 0, SEEK_SET) != 0) { fclose(f); return false; }

    void* buf = malloc((size_t)sz);
    if (!buf) { fclose(f); return false; }
    size_t rd = fread(buf, 1, (size_t)sz, f);
    fclose(f);
    if (rd != (size_t)sz) { free(buf); return false; }

    out->data = buf;
    out->size = (size_t)sz;
    out->owned = true;
    return true;
}

bool LoadAsset(const char* path, AssetBuffer* out)
{
    if (!path || !out) return false;
    memset(out, 0, sizeof(*out));

    const void* data = NULL;
    size_t size = 0;
    bool compressed = false;
    if (EmbeddedGet(path, &data, &size, &compressed)) {
        if (compressed) {
            void* inflated = NULL;
            size_t inflated_size = 0;
            if (!InflateGzip(data, size, &inflated, &inflated_size)) return false;
            out->data = inflated;
            out->size = inflated_size;
            out->owned = true;
            return true;
        }
        out->data = (void*)data;
        out->size = size;
        out->owned = false;
        return true;
    }

    char resolved[255];
    if (ResolveAssetPath(resolved, sizeof(resolved), path)) {
        return ReadFileAll(resolved, out);
    }
    return ReadFileAll(path, out);
}

void FreeAsset(AssetBuffer* asset)
{
    if (!asset) return;
    if (asset->owned && asset->data) free(asset->data);
    asset->data = NULL;
    asset->size = 0;
    asset->owned = false;
}

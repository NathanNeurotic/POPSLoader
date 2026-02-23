#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "include/assets.h"
#include "include/luaplayer.h"
#include "include/dprintf.h"

typedef struct {
    const char* logical;
    const unsigned char* data;
    size_t size;
} EmbeddedAsset;

extern unsigned char builtin_font[];
extern unsigned int size_builtin_font;

#define DECL_ASSET(sym) extern unsigned char sym[]; extern unsigned int size_##sym;
DECL_ASSET(asset_bin_POPSLDR_system_lua)
DECL_ASSET(asset_bin_POPSLDR_ui_lua)
DECL_ASSET(asset_bin_POPSLDR_images_lua)
DECL_ASSET(asset_bin_POPSLDR_pops_profiles_lua)
DECL_ASSET(asset_bin_POPSLDR_boot_adp)
DECL_ASSET(asset_bin_POPSLDR_IMG_APAHDD_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_BDHDD_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_BG_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_BGM_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_BKG_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_DISC_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_HDD_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_L1_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_L2_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_L3_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_MISSING_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_MMCE_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_MX4SIO_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_PSL_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_R1_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_R2_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_R3_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_SMB_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_USB_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_circle_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_cross_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_down_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_frame_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_horz_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_left_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_right_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_select_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_square_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_start_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_triangle_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_up_png)
DECL_ASSET(asset_bin_POPSLDR_IMG_vert_png)

static EmbeddedAsset g_assets[] = {
    {"system.lua", asset_bin_POPSLDR_system_lua, size_asset_bin_POPSLDR_system_lua},
    {"ui.lua", asset_bin_POPSLDR_ui_lua, size_asset_bin_POPSLDR_ui_lua},
    {"images.lua", asset_bin_POPSLDR_images_lua, size_asset_bin_POPSLDR_images_lua},
    {"pops_profiles.lua", asset_bin_POPSLDR_pops_profiles_lua, size_asset_bin_POPSLDR_pops_profiles_lua},
    {"boot.adp", asset_bin_POPSLDR_boot_adp, size_asset_bin_POPSLDR_boot_adp},
    {"builtin_font.bin", builtin_font, size_builtin_font},
    {"IMG/APAHDD.png", asset_bin_POPSLDR_IMG_APAHDD_png, size_asset_bin_POPSLDR_IMG_APAHDD_png},
    {"IMG/BDHDD.png", asset_bin_POPSLDR_IMG_BDHDD_png, size_asset_bin_POPSLDR_IMG_BDHDD_png},
    {"IMG/BG.png", asset_bin_POPSLDR_IMG_BG_png, size_asset_bin_POPSLDR_IMG_BG_png},
    {"IMG/BGM.png", asset_bin_POPSLDR_IMG_BGM_png, size_asset_bin_POPSLDR_IMG_BGM_png},
    {"IMG/BKG.png", asset_bin_POPSLDR_IMG_BKG_png, size_asset_bin_POPSLDR_IMG_BKG_png},
    {"IMG/DISC.png", asset_bin_POPSLDR_IMG_DISC_png, size_asset_bin_POPSLDR_IMG_DISC_png},
    {"IMG/HDD.png", asset_bin_POPSLDR_IMG_HDD_png, size_asset_bin_POPSLDR_IMG_HDD_png},
    {"IMG/L1.png", asset_bin_POPSLDR_IMG_L1_png, size_asset_bin_POPSLDR_IMG_L1_png},
    {"IMG/L2.png", asset_bin_POPSLDR_IMG_L2_png, size_asset_bin_POPSLDR_IMG_L2_png},
    {"IMG/L3.png", asset_bin_POPSLDR_IMG_L3_png, size_asset_bin_POPSLDR_IMG_L3_png},
    {"IMG/MISSING.png", asset_bin_POPSLDR_IMG_MISSING_png, size_asset_bin_POPSLDR_IMG_MISSING_png},
    {"IMG/MMCE.png", asset_bin_POPSLDR_IMG_MMCE_png, size_asset_bin_POPSLDR_IMG_MMCE_png},
    {"IMG/MX4SIO.png", asset_bin_POPSLDR_IMG_MX4SIO_png, size_asset_bin_POPSLDR_IMG_MX4SIO_png},
    {"IMG/PSL.png", asset_bin_POPSLDR_IMG_PSL_png, size_asset_bin_POPSLDR_IMG_PSL_png},
    {"IMG/R1.png", asset_bin_POPSLDR_IMG_R1_png, size_asset_bin_POPSLDR_IMG_R1_png},
    {"IMG/R2.png", asset_bin_POPSLDR_IMG_R2_png, size_asset_bin_POPSLDR_IMG_R2_png},
    {"IMG/R3.png", asset_bin_POPSLDR_IMG_R3_png, size_asset_bin_POPSLDR_IMG_R3_png},
    {"IMG/SMB.png", asset_bin_POPSLDR_IMG_SMB_png, size_asset_bin_POPSLDR_IMG_SMB_png},
    {"IMG/USB.png", asset_bin_POPSLDR_IMG_USB_png, size_asset_bin_POPSLDR_IMG_USB_png},
    {"IMG/circle.png", asset_bin_POPSLDR_IMG_circle_png, size_asset_bin_POPSLDR_IMG_circle_png},
    {"IMG/cross.png", asset_bin_POPSLDR_IMG_cross_png, size_asset_bin_POPSLDR_IMG_cross_png},
    {"IMG/down.png", asset_bin_POPSLDR_IMG_down_png, size_asset_bin_POPSLDR_IMG_down_png},
    {"IMG/frame.png", asset_bin_POPSLDR_IMG_frame_png, size_asset_bin_POPSLDR_IMG_frame_png},
    {"IMG/horz.png", asset_bin_POPSLDR_IMG_horz_png, size_asset_bin_POPSLDR_IMG_horz_png},
    {"IMG/left.png", asset_bin_POPSLDR_IMG_left_png, size_asset_bin_POPSLDR_IMG_left_png},
    {"IMG/right.png", asset_bin_POPSLDR_IMG_right_png, size_asset_bin_POPSLDR_IMG_right_png},
    {"IMG/select.png", asset_bin_POPSLDR_IMG_select_png, size_asset_bin_POPSLDR_IMG_select_png},
    {"IMG/square.png", asset_bin_POPSLDR_IMG_square_png, size_asset_bin_POPSLDR_IMG_square_png},
    {"IMG/start.png", asset_bin_POPSLDR_IMG_start_png, size_asset_bin_POPSLDR_IMG_start_png},
    {"IMG/triangle.png", asset_bin_POPSLDR_IMG_triangle_png, size_asset_bin_POPSLDR_IMG_triangle_png},
    {"IMG/up.png", asset_bin_POPSLDR_IMG_up_png, size_asset_bin_POPSLDR_IMG_up_png},
    {"IMG/vert.png", asset_bin_POPSLDR_IMG_vert_png, size_asset_bin_POPSLDR_IMG_vert_png},
};

static const EmbeddedAsset* FindEmbedded(const char* logicalPath) {
    for (size_t i = 0; i < sizeof(g_assets)/sizeof(g_assets[0]); ++i) {
        if (strcmp(g_assets[i].logical, logicalPath) == 0) return &g_assets[i];
    }
    return NULL;
}

int Asset_ResolvePath(char* out, size_t outsz, const char* logicalPath) {
    if (strchr(logicalPath, ':') != NULL) {
        snprintf(out, outsz, "%s", logicalPath);
        return 1;
    }
    char c[255];
    struct stat st;
    snprintf(c, sizeof(c), "%s%s", app_dir, logicalPath);
    if (stat(c, &st) == 0) { snprintf(out, outsz, "%s", c); return 1; }
    snprintf(c, sizeof(c), "%sPOPSLDR/%s", app_dir, logicalPath);
    if (stat(c, &st) == 0) { snprintf(out, outsz, "%s", c); return 1; }
    return 0;
}

bool Asset_Exists(const char* logicalPath) {
    if (!logicalPath) return false;
    if (FindEmbedded(logicalPath) != NULL) return true;
    char out[255];
    return Asset_ResolvePath(out, sizeof(out), logicalPath) == 1;
}

int Asset_ReadAll(const char* logicalPath, const void** outPtr, size_t* outSize, bool* outIsEmbedded) {
    if (!logicalPath || !outPtr || !outSize || !outIsEmbedded) return -1;
    const EmbeddedAsset* a = FindEmbedded(logicalPath);
    if (a != NULL) {
        *outPtr = a->data;
        *outSize = a->size;
        *outIsEmbedded = true;
        return 0;
    }
    char path[255];
    if (!Asset_ResolvePath(path, sizeof(path), logicalPath)) return -2;
    FILE* f = fopen(path, "rb");
    if (!f) return -3;
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (sz <= 0) { fclose(f); return -4; }
    void* p = malloc((size_t)sz);
    if (!p) { fclose(f); return -5; }
    if (fread(p, 1, (size_t)sz, f) != (size_t)sz) { fclose(f); free(p); return -6; }
    fclose(f);
    *outPtr = p;
    *outSize = (size_t)sz;
    *outIsEmbedded = false;
    return 0;
}

void Asset_FreeIfNeeded(const void* ptr, bool isEmbedded) {
    if (!isEmbedded && ptr) free((void*)ptr);
}

static char g_settings_root[255] = "mc0:/POPSLOADER/";

void Asset_InitSettingsRoot(const char* bootPath) {
    struct stat st;
    mkdir("mc0:/POPSLOADER", 0777);
    if (stat("mc0:/POPSLOADER/", &st) == 0) {
        snprintf(g_settings_root, sizeof(g_settings_root), "mc0:/POPSLOADER/");
        return;
    }
    char root[64] = {0};
    if (bootPath) {
        const char* c = strchr(bootPath, ':');
        if (c) {
            size_t n = (size_t)(c - bootPath + 1);
            if (n + 12 < sizeof(root)) {
                memcpy(root, bootPath, n);
                root[n] = '/';
                root[n+1] = 0;
                snprintf(g_settings_root, sizeof(g_settings_root), "%sPOPSLOADER/", root);
                char mk[255]; snprintf(mk, sizeof(mk), "%sPOPSLOADER", root);
                mkdir(mk, 0777);
            }
        }
    }
}

const char* Asset_GetSettingsRoot(void) { return g_settings_root; }

int Asset_BootAuditAndReport(void) {
    const char* req[] = {"system.lua", "ui.lua", "images.lua", "boot.adp", "builtin_font.bin", "IMG/BG.png", "IMG/MISSING.png"};
    int missing = 0;
    for (size_t i = 0; i < sizeof(req)/sizeof(req[0]); ++i) {
        const void* p = NULL; size_t s = 0; bool emb = false;
        int rc = Asset_ReadAll(req[i], &p, &s, &emb);
        if (rc == 0) {
            DPRINTF("ASSET AUDIT: %s %s %u bytes\n", req[i], emb ? "EMBEDDED" : "DISK", (unsigned int)s);
            Asset_FreeIfNeeded(p, emb);
        } else {
            DPRINTF("ASSET AUDIT: MISSING %s rc=%d\n", req[i], rc);
            missing++;
        }
    }
    return missing;
}

#ifndef ASSETS_H
#define ASSETS_H

#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

bool Asset_Exists(const char* logicalPath);
int Asset_ReadAll(const char* logicalPath, const void** outPtr, size_t* outSize, bool* outIsEmbedded);
void Asset_FreeIfNeeded(const void* ptr, bool isEmbedded);
int Asset_ResolvePath(char* out, size_t outsz, const char* logicalPath);
const char* Asset_GetSettingsRoot(void);
void Asset_InitSettingsRoot(const char* bootPath);
int Asset_BootAuditAndReport(void);

#ifdef __cplusplus
}
#endif

#endif

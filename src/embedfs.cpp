#include <stdio.h>
#include <string.h>

#include "include/embedfs.h"

typedef struct {
  const char *path;
  const unsigned char *data;
  unsigned int size;
} embed_asset_t;

extern const embed_asset_t g_embed_assets[];
extern const unsigned int g_embed_assets_count;

static const char *normalize_core(const char *in, char *buf, size_t bufsz)
{
  if (in == NULL || in[0] == '\0') {
    return NULL;
  }

  const char *path = in;
  if (!strncmp(path, "embed:/", 7)) {
    path += 7;
  }
  while (!strncmp(path, "./", 2)) {
    path += 2;
  }
  while (*path == '/') {
    path++;
  }

  if (!strncmp(path, "POPSLDR/", 8)) {
    snprintf(buf, bufsz, "%s", path);
    return buf;
  }

  if (!strncmp(path, "IMG/", 4)) {
    snprintf(buf, bufsz, "POPSLDR/%s", path);
    return buf;
  }

  if (strchr(path, ':') != NULL) {
    return NULL;
  }

  if (strchr(path, '/') == NULL) {
    if (!strcmp(path, "BG.png") ||
        !strcmp(path, "BKG.png") ||
        !strcmp(path, "BGM.png") ||
        !strcmp(path, "splash_bg.png")) {
      snprintf(buf, bufsz, "POPSLDR/%s", path);
      return buf;
    }
    return NULL;
  }

  snprintf(buf, bufsz, "POPSLDR/%s", path);
  return buf;
}

const char *embedfs_normalize_path(const char *in)
{
  static char normalized[512];
  return normalize_core(in, normalized, sizeof(normalized));
}

int embedfs_get(const char *path, const uint8_t **out_data, size_t *out_size)
{
  const char *key = embedfs_normalize_path(path);
  if (key == NULL) {
    return 0;
  }

  for (unsigned int i = 0; i < g_embed_assets_count; ++i) {
    if (!strcmp(g_embed_assets[i].path, key)) {
      if (out_data) {
        *out_data = g_embed_assets[i].data;
      }
      if (out_size) {
        *out_size = g_embed_assets[i].size;
      }
      return 1;
    }
  }

  return 0;
}

int embedfs_exists(const char *path)
{
  return embedfs_get(path, NULL, NULL);
}

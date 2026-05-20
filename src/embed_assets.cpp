#include <string.h>
#include <stdio.h>

#include "include/embed_assets.h"

typedef struct embedded_asset {
	const char *key;
	const uint8_t *data;
	size_t size;
} embedded_asset_t;

extern unsigned char asset_usb_png[];
extern unsigned int size_asset_usb_png;
extern unsigned char asset_smb_png[];
extern unsigned int size_asset_smb_png;
extern unsigned char asset_mmce_png[];
extern unsigned int size_asset_mmce_png;
extern unsigned char asset_mx4sio_png[];
extern unsigned int size_asset_mx4sio_png;
extern unsigned char asset_apahdd_png[];
extern unsigned int size_asset_apahdd_png;
extern unsigned char asset_bdhdd_png[];
extern unsigned int size_asset_bdhdd_png;
extern unsigned char asset_bg_png[];
extern unsigned int size_asset_bg_png;
extern unsigned char asset_bkg_png[];
extern unsigned int size_asset_bkg_png;
extern unsigned char asset_bgm_png[];
extern unsigned int size_asset_bgm_png;
extern unsigned char asset_disc_png[];
extern unsigned int size_asset_disc_png;
extern unsigned char asset_splash_bg_png[];
extern unsigned int size_asset_splash_bg_png;
extern unsigned char asset_splash_logo_png[];
extern unsigned int size_asset_splash_logo_png;
extern unsigned char asset_splash_appname_png[];
extern unsigned int size_asset_splash_appname_png;
extern unsigned char asset_splash_credits_png[];
extern unsigned int size_asset_splash_credits_png;
extern unsigned char asset_select_png[];
extern unsigned int size_asset_select_png;
extern unsigned char asset_start_png[];
extern unsigned int size_asset_start_png;
extern unsigned char asset_triangle_png[];
extern unsigned int size_asset_triangle_png;
extern unsigned char asset_circle_png[];
extern unsigned int size_asset_circle_png;
extern unsigned char asset_cross_png[];
extern unsigned int size_asset_cross_png;
extern unsigned char asset_l1_png[];
extern unsigned int size_asset_l1_png;
extern unsigned char asset_r1_png[];
extern unsigned int size_asset_r1_png;
extern unsigned char asset_r2_png[];
extern unsigned int size_asset_r2_png;
extern unsigned char asset_square_png[];
extern unsigned int size_asset_square_png;
extern unsigned char asset_frame_png[];
extern unsigned int size_asset_frame_png;
#ifdef HAVE_ASSET_DEFAULT_PNG
extern unsigned char asset_default_png[];
extern unsigned int size_asset_default_png;
#endif
extern unsigned char asset_missing_png[];
extern unsigned int size_asset_missing_png;
extern unsigned char asset_left_png[];
extern unsigned int size_asset_left_png;
extern unsigned char asset_right_png[];
extern unsigned int size_asset_right_png;
extern unsigned char asset_up_png[];
extern unsigned int size_asset_up_png;
extern unsigned char asset_down_png[];
extern unsigned int size_asset_down_png;
extern unsigned char asset_system_lua[];
extern unsigned int size_asset_system_lua;
extern unsigned char asset_ui_lua[];
extern unsigned int size_asset_ui_lua;
extern unsigned char asset_images_lua[];
extern unsigned int size_asset_images_lua;
extern unsigned char asset_pops_profiles_lua[];
extern unsigned int size_asset_pops_profiles_lua;
extern unsigned char asset_usbd_irx_usbexfat[];
extern unsigned int size_asset_usbd_irx_usbexfat;
extern unsigned char asset_usbhdfsd_irx_usbexfat[];
extern unsigned int size_asset_usbhdfsd_irx_usbexfat;
extern unsigned char asset_usbd_irx_mx4sio[];
extern unsigned int size_asset_usbd_irx_mx4sio;
extern unsigned char asset_usbhdfsd_irx_mx4sio[];
extern unsigned int size_asset_usbhdfsd_irx_mx4sio;
extern unsigned char asset_usbd_irx_mmce[];
extern unsigned int size_asset_usbd_irx_mmce;
extern unsigned char asset_usbhdfsd_irx_mmce[];
extern unsigned int size_asset_usbhdfsd_irx_mmce;
extern unsigned char asset_icon_sys_bdma[];
extern unsigned int size_asset_icon_sys_bdma;
extern unsigned char asset_list_icn_bdma[];
extern unsigned int size_asset_list_icn_bdma;
extern unsigned char asset_del_icn_bdma[];
extern unsigned int size_asset_del_icn_bdma;
extern unsigned char asset_boot_adp[];
extern unsigned int size_asset_boot_adp;

#define ASSET_ENTRY(key_name, symbol_name) { key_name, symbol_name, (size_t)size_##symbol_name }

static const embedded_asset_t g_embedded_assets[] = {
	ASSET_ENTRY("USB.png", asset_usb_png),
	ASSET_ENTRY("SMB.png", asset_smb_png),
	ASSET_ENTRY("MMCE.png", asset_mmce_png),
	ASSET_ENTRY("MX4SIO.png", asset_mx4sio_png),
	ASSET_ENTRY("APAHDD.png", asset_apahdd_png),
	ASSET_ENTRY("BDHDD.png", asset_bdhdd_png),
	ASSET_ENTRY("BG.png", asset_bg_png),
	ASSET_ENTRY("BKG.png", asset_bkg_png),
	ASSET_ENTRY("BGM.png", asset_bgm_png),
	ASSET_ENTRY("DISC.png", asset_disc_png),
	ASSET_ENTRY("splash_bg.png", asset_splash_bg_png),
	ASSET_ENTRY("splash_logo.png", asset_splash_logo_png),
	ASSET_ENTRY("splash_appname.png", asset_splash_appname_png),
	ASSET_ENTRY("splash_credits.png", asset_splash_credits_png),
	ASSET_ENTRY("select.png", asset_select_png),
	ASSET_ENTRY("start.png", asset_start_png),
	ASSET_ENTRY("triangle.png", asset_triangle_png),
	ASSET_ENTRY("circle.png", asset_circle_png),
	ASSET_ENTRY("cross.png", asset_cross_png),
	ASSET_ENTRY("L1.png", asset_l1_png),
	ASSET_ENTRY("R1.png", asset_r1_png),
	ASSET_ENTRY("R2.png", asset_r2_png),
	ASSET_ENTRY("square.png", asset_square_png),
	ASSET_ENTRY("frame.png", asset_frame_png),
#ifdef HAVE_ASSET_DEFAULT_PNG
	ASSET_ENTRY("default.png", asset_default_png),
#endif
	ASSET_ENTRY("MISSING.png", asset_missing_png),
	ASSET_ENTRY("left.png", asset_left_png),
	ASSET_ENTRY("right.png", asset_right_png),
	ASSET_ENTRY("up.png", asset_up_png),
	ASSET_ENTRY("down.png", asset_down_png),
	ASSET_ENTRY("system.lua", asset_system_lua),
	ASSET_ENTRY("ui.lua", asset_ui_lua),
	ASSET_ENTRY("images.lua", asset_images_lua),
	ASSET_ENTRY("pops_profiles.lua", asset_pops_profiles_lua),
	ASSET_ENTRY("usbd.irx.usbexfat", asset_usbd_irx_usbexfat),
	ASSET_ENTRY("usbhdfsd.irx.usbexfat", asset_usbhdfsd_irx_usbexfat),
	ASSET_ENTRY("usbd.irx.mx4sio", asset_usbd_irx_mx4sio),
	ASSET_ENTRY("usbhdfsd.irx.mx4sio", asset_usbhdfsd_irx_mx4sio),
	ASSET_ENTRY("usbd.irx.mmce", asset_usbd_irx_mmce),
	ASSET_ENTRY("usbhdfsd.irx.mmce", asset_usbhdfsd_irx_mmce),
	ASSET_ENTRY("icon.sys.bdma", asset_icon_sys_bdma),
	ASSET_ENTRY("list.icn.bdma", asset_list_icn_bdma),
	ASSET_ENTRY("del.icn.bdma", asset_del_icn_bdma),
	ASSET_ENTRY("boot.adp", asset_boot_adp),


	ASSET_ENTRY("POPSLDR/IMG/USB.png", asset_usb_png),
	ASSET_ENTRY("POPSLDR/IMG/SMB.png", asset_smb_png),
	ASSET_ENTRY("POPSLDR/IMG/MMCE.png", asset_mmce_png),
	ASSET_ENTRY("POPSLDR/IMG/MX4SIO.png", asset_mx4sio_png),
	ASSET_ENTRY("POPSLDR/IMG/APAHDD.png", asset_apahdd_png),
	ASSET_ENTRY("POPSLDR/IMG/BDHDD.png", asset_bdhdd_png),
	ASSET_ENTRY("POPSLDR/IMG/BG.png", asset_bg_png),
	ASSET_ENTRY("POPSLDR/IMG/BKG.png", asset_bkg_png),
	ASSET_ENTRY("POPSLDR/IMG/BGM.png", asset_bgm_png),
	ASSET_ENTRY("POPSLDR/IMG/DISC.png", asset_disc_png),
	ASSET_ENTRY("POPSLDR/IMG/splash_bg.png", asset_splash_bg_png),
	ASSET_ENTRY("POPSLDR/IMG/splash_logo.png", asset_splash_logo_png),
	ASSET_ENTRY("POPSLDR/IMG/splash_appname.png", asset_splash_appname_png),
	ASSET_ENTRY("POPSLDR/IMG/splash_credits.png", asset_splash_credits_png),
	ASSET_ENTRY("POPSLDR/IMG/select.png", asset_select_png),
	ASSET_ENTRY("POPSLDR/IMG/start.png", asset_start_png),
	ASSET_ENTRY("POPSLDR/IMG/triangle.png", asset_triangle_png),
	ASSET_ENTRY("POPSLDR/IMG/circle.png", asset_circle_png),
	ASSET_ENTRY("POPSLDR/IMG/cross.png", asset_cross_png),
	ASSET_ENTRY("POPSLDR/IMG/L1.png", asset_l1_png),
	ASSET_ENTRY("POPSLDR/IMG/R1.png", asset_r1_png),
	ASSET_ENTRY("POPSLDR/IMG/R2.png", asset_r2_png),
	ASSET_ENTRY("POPSLDR/IMG/square.png", asset_square_png),
	ASSET_ENTRY("POPSLDR/IMG/frame.png", asset_frame_png),
#ifdef HAVE_ASSET_DEFAULT_PNG
	ASSET_ENTRY("POPSLDR/IMG/default.png", asset_default_png),
#endif
	ASSET_ENTRY("POPSLDR/IMG/MISSING.png", asset_missing_png),
	ASSET_ENTRY("POPSLDR/IMG/left.png", asset_left_png),
	ASSET_ENTRY("POPSLDR/IMG/right.png", asset_right_png),
	ASSET_ENTRY("POPSLDR/IMG/up.png", asset_up_png),
	ASSET_ENTRY("POPSLDR/IMG/down.png", asset_down_png),
	ASSET_ENTRY("POPSLDR/system.lua", asset_system_lua),
	ASSET_ENTRY("POPSLDR/ui.lua", asset_ui_lua),
	ASSET_ENTRY("POPSLDR/images.lua", asset_images_lua),
	ASSET_ENTRY("POPSLDR/pops_profiles.lua", asset_pops_profiles_lua),
	ASSET_ENTRY("POPSLDR/usbd.irx.usbexfat", asset_usbd_irx_usbexfat),
	ASSET_ENTRY("POPSLDR/usbhdfsd.irx.usbexfat", asset_usbhdfsd_irx_usbexfat),
	ASSET_ENTRY("POPSLDR/usbd.irx.mx4sio", asset_usbd_irx_mx4sio),
	ASSET_ENTRY("POPSLDR/usbhdfsd.irx.mx4sio", asset_usbhdfsd_irx_mx4sio),
	ASSET_ENTRY("POPSLDR/usbd.irx.mmce", asset_usbd_irx_mmce),
	ASSET_ENTRY("POPSLDR/usbhdfsd.irx.mmce", asset_usbhdfsd_irx_mmce),
	ASSET_ENTRY("POPSLDR/icon.sys.bdma", asset_icon_sys_bdma),
	ASSET_ENTRY("POPSLDR/list.icn.bdma", asset_list_icn_bdma),
	ASSET_ENTRY("POPSLDR/del.icn.bdma", asset_del_icn_bdma),
	ASSET_ENTRY("POPSLDR/boot.adp", asset_boot_adp)
};

static const embedded_asset_t *embedded_find(const char *key)
{
	for (size_t i = 0; i < sizeof(g_embedded_assets) / sizeof(g_embedded_assets[0]); ++i) {
		if (strcmp(g_embedded_assets[i].key, key) == 0) {
			return &g_embedded_assets[i];
		}
	}

	return NULL;
}

static int is_default_png_key(const char *key)
{
	return key != NULL &&
	       (strcmp(key, "default.png") == 0 ||
	        strcmp(key, "IMG/default.png") == 0 ||
	        strcmp(key, "POPSLDR/IMG/default.png") == 0);
}

int embedded_get(const char* path_or_name, const uint8_t** out_data, size_t* out_size)
{
	if (out_data == NULL || out_size == NULL || path_or_name == NULL) {
		return 0;
	}

	*out_data = NULL;
	*out_size = 0;

	const char *input = path_or_name;
	if (strncmp(input, "embed:/", 7) == 0) {
		input += 7;
	}

	while (input[0] == '.' && input[1] == '/') {
		input += 2;
	}
	while (*input == '/') {
		++input;
	}

	if (*input == '\0') {
		return 0;
	}

	char normalized[256];
	const char *lookup_key = input;

	if (strncmp(input, "POPSLDR/", 8) == 0) {
		snprintf(normalized, sizeof(normalized), "%s", input);
		lookup_key = normalized;
	} else if (strncmp(input, "IMG/", 4) == 0) {
		snprintf(normalized, sizeof(normalized), "POPSLDR/IMG/%s", input + 4);
		lookup_key = normalized;
	} else if (strchr(input, '/') != NULL) {
		snprintf(normalized, sizeof(normalized), "POPSLDR/%s", input);
		lookup_key = normalized;
	}

	const embedded_asset_t *asset = embedded_find(lookup_key);
	if (asset == NULL && lookup_key != input && strchr(input, '/') == NULL) {
		asset = embedded_find(input);
	}
#ifndef HAVE_ASSET_DEFAULT_PNG
	if (asset == NULL && (is_default_png_key(lookup_key) || is_default_png_key(input))) {
		asset = embedded_find("MISSING.png");
	}
#endif
	if (asset == NULL) {
		return 0;
	}

	*out_data = asset->data;
	*out_size = asset->size;
	return 1;
}

/* Retro GEM Game ID support.
 *
 * Retro GEM (PixelFX) applies per-game settings keyed on a Game ID. There is no
 * PS2-side data channel for that: the ID is transmitted OPTICALLY, as a small
 * pattern of coloured sprites drawn near the bottom of the frame, which the mod
 * decodes off the video output. So "setting the Game ID" is literally a draw call.
 *
 * The PS1 title ID is read from INSIDE the .VCD. A VCD is a raw CD image behind a
 * 0x100000 header, so the ISO9660 filesystem is walked to find SYSTEM.CNF and its
 * BOOT= line parsed ("BOOT = cdrom:\SLUS_007.42;1" -> "SLUS_007.42"). The filename
 * is only a last resort: plenty of VCDs are not named in the OPL convention.
 *
 * FORMAT CREDIT: both the optical packet layout and the VCD/ISO offsets are
 * interoperability facts taken from the reference implementations --
 * CosmicScale's Retro-GEM tools (the packet and its CRC) and saildot4k's
 * wLaunchELF_R3Z popstarter_vcd.c / popstarter_gameid.c (the VCD walk and the
 * fallback ladder). Neither repository declares a licence, so this is an
 * independent implementation written against the format rather than a copy of
 * either codebase. Behaviour is intended to match exactly; if it diverges, they
 * are correct and this is wrong.
 */

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <gsKit.h>

#include "include/graphics.h"

/* VCD geometry. The image starts after a fixed header; sectors are raw 2352-byte
 * CD sectors, of which 2048 bytes are user data at a mode-dependent offset. */
#define VCD_IMAGE_OFFSET      0x100000
#define VCD_RAW_SECTOR_SIZE   2352
#define CD_SECTOR_DATA_SIZE   2048
/* ISO9660: the volume descriptors start at LBA 16; the root directory record sits
 * at offset 156 inside the Primary Volume Descriptor. */
#define ISO_PVD_LBA           16
#define ISO_PVD_SEARCH        16
#define ISO_ROOT_RECORD_OFF   156
#define ISO_MAX_ROOT_SECTORS  64

#define RG_GAMEID_MAX 11

static uint32_t rg_le32(const unsigned char *p)
{
	return ((uint32_t)p[0]) | ((uint32_t)p[1] << 8) |
	       ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static char rg_lower(char c)
{
	return (c >= 'A' && c <= 'Z') ? (char)(c - 'A' + 'a') : c;
}

/* One 2048-byte user-data sector out of the raw image.
 * raw[15] is the CD mode: mode 1 puts user data at +16; mode 2 form 1 at +24.
 * Mode 2 FORM 2 (raw[18] & 0x20) carries no ISO data and is refused. */
static int rg_read_sector(int fd, uint32_t lba, unsigned char *out)
{
	static unsigned char raw[VCD_RAW_SECTOR_SIZE] __attribute__((aligned(16)));
	int data_off;

	if (lseek(fd, (int)(VCD_IMAGE_OFFSET + (lba * VCD_RAW_SECTOR_SIZE)), SEEK_SET) < 0)
		return 0;
	if (read(fd, raw, VCD_RAW_SECTOR_SIZE) != VCD_RAW_SECTOR_SIZE)
		return 0;

	if (raw[15] == 1) {
		data_off = 16;
	} else if (raw[15] == 2) {
		if (raw[18] & 0x20)
			return 0;
		data_off = 24;
	} else {
		return 0;
	}

	memcpy(out, raw + data_off, CD_SECTOR_DATA_SIZE);
	return 1;
}

static int rg_read_pvd(int fd, unsigned char *pvd)
{
	unsigned char sector[CD_SECTOR_DATA_SIZE] __attribute__((aligned(16)));
	int i;

	for (i = 0; i < ISO_PVD_SEARCH; i++) {
		if (!rg_read_sector(fd, ISO_PVD_LBA + i, sector))
			return 0;
		if (!memcmp(sector + 1, "CD001", 5)) {
			if (sector[0] == 1) {            /* primary volume descriptor */
				memcpy(pvd, sector, CD_SECTOR_DATA_SIZE);
				return 1;
			}
			if (sector[0] == 255)            /* terminator: no PVD */
				return 0;
		}
	}
	return 0;
}

/* ISO directory names are upper-case and carry a ";1" version suffix. */
static int rg_name_is(const unsigned char *name, int name_len, const char *want)
{
	int want_len = (int)strlen(want);
	int i;

	if (name_len < want_len)
		return 0;
	for (i = 0; i < want_len; i++) {
		if (rg_lower((char)name[i]) != rg_lower(want[i]))
			return 0;
	}
	return (name_len == want_len || name[want_len] == ';');
}

static int rg_read_file(int fd, uint32_t lba, uint32_t size, char *buf, int buf_size)
{
	unsigned char sector[CD_SECTOR_DATA_SIZE] __attribute__((aligned(16)));
	int copied = 0;
	uint32_t idx = 0;

	if (buf_size <= 1 || size == 0)
		return 0;

	while (copied < buf_size - 1 && (uint32_t)copied < size) {
		int room = buf_size - 1 - copied;
		int left = (int)(size - (uint32_t)copied);
		int len = CD_SECTOR_DATA_SIZE;

		if (!rg_read_sector(fd, lba + idx, sector))
			break;
		if (len > left) len = left;
		if (len > room) len = room;
		memcpy(buf + copied, sector, len);
		copied += len;
		idx++;
	}
	buf[copied] = '\0';
	return copied > 0;
}

static int rg_read_system_cnf(int fd, char *buf, int buf_size)
{
	unsigned char pvd[CD_SECTOR_DATA_SIZE] __attribute__((aligned(16)));
	unsigned char sector[CD_SECTOR_DATA_SIZE] __attribute__((aligned(16)));
	const unsigned char *root;
	uint32_t root_lba, root_size, root_sectors, s;

	buf[0] = '\0';
	if (!rg_read_pvd(fd, pvd))
		return 0;

	root = pvd + ISO_ROOT_RECORD_OFF;
	if (root[0] < 34)
		return 0;

	root_lba = rg_le32(root + 2);
	root_size = rg_le32(root + 10);
	root_sectors = (root_size + CD_SECTOR_DATA_SIZE - 1) / CD_SECTOR_DATA_SIZE;
	if (root_sectors > ISO_MAX_ROOT_SECTORS)
		root_sectors = ISO_MAX_ROOT_SECTORS;

	for (s = 0; s < root_sectors; s++) {
		int pos = 0;
		if (!rg_read_sector(fd, root_lba + s, sector))
			return 0;

		while (pos < CD_SECTOR_DATA_SIZE) {
			int rec_len = sector[pos];
			int flags, name_len;

			if (rec_len == 0)
				break;                       /* end of records in this sector */
			if (rec_len < 34 || pos + rec_len > CD_SECTOR_DATA_SIZE)
				break;

			flags = sector[pos + 25];
			name_len = sector[pos + 32];
			if (!(flags & 0x02) &&               /* not a directory */
			    rec_len >= 33 + name_len &&
			    rg_name_is(sector + pos + 33, name_len, "SYSTEM.CNF")) {
				return rg_read_file(fd, rg_le32(sector + pos + 2),
				                    rg_le32(sector + pos + 10), buf, buf_size);
			}
			pos += rec_len;
		}
	}
	return 0;
}

/* A title ID looks like SLUS_007.42 / SCUS_941.94: 4 letters, '_', then digits
 * with a dot. Anything else is not an ID and must be rejected rather than sent to
 * the GEM, which would select the wrong per-game profile. */
static int rg_is_title_id(const char *id)
{
	size_t n = id ? strlen(id) : 0;
	return (n >= RG_GAMEID_MAX && id[4] == '_' && (id[7] == '.' || id[8] == '.'));
}

/* Take the ID from the tail of a path, dropping any POPStarter selector prefix. */
static int rg_id_from_name(const char *path, char *out, int out_size)
{
	const char *name, *sep;
	int i;

	if (path == NULL || out_size <= 0)
		return 0;
	out[0] = '\0';

	name = path;
	if ((sep = strrchr(path, '/')) != NULL && sep + 1 > name) name = sep + 1;
	if ((sep = strrchr(path, '\\')) != NULL && sep + 1 > name) name = sep + 1;
	if ((sep = strrchr(path, ':')) != NULL && sep + 1 > name) name = sep + 1;
	if (name[0] == '\0')
		return 0;

	/* XX. (USB/BDM), __. (hidden APA), PP. (partition-installed), SB. (SMB) */
	if (!strncasecmp(name, "XX.", 3) || !strncasecmp(name, "__.", 3) ||
	    !strncasecmp(name, "PP.", 3) || !strncasecmp(name, "SB.", 3))
		name += 3;

	for (i = 0; i < RG_GAMEID_MAX && i < out_size - 1 && name[i] != '\0'; i++)
		out[i] = name[i];
	out[i] = '\0';
	return (i > 0);
}

/* Resolve the Game ID for a VCD: SYSTEM.CNF first, filename as a fallback.
 * Returns 1 and fills out[] (NUL-terminated, <= 11 chars) or 0. */
extern "C" int retrogem_gameid_for_vcd(const char *path, char *out, int out_size)
{
	char cnf[CD_SECTOR_DATA_SIZE + 1];
	int fd;

	if (path == NULL || out == NULL || out_size <= 0)
		return 0;
	out[0] = '\0';

	fd = open(path, O_RDONLY);
	if (fd >= 0) {
		int got = rg_read_system_cnf(fd, cnf, (int)sizeof(cnf));
		close(fd);
		if (got) {
			/* Find the BOOT= line and take the ID off its value. */
			const char *line = cnf;
			while (*line != '\0') {
				const char *end = line;
				while (*end != '\0' && *end != '\r' && *end != '\n') end++;
				{
					const char *p = line;
					while (*p == ' ' || *p == '\t') p++;
					if (!strncasecmp(p, "BOOT", 4)) {
						p += 4;
						while (p < end && (*p == ' ' || *p == '\t')) p++;
						if (p < end && *p == '=') {
							char value[256];
							int vlen = 0;
							p++;
							while (p < end && (*p == ' ' || *p == '\t')) p++;
							while (p < end && *p != ' ' && *p != '\t' &&
							       vlen < (int)sizeof(value) - 1)
								value[vlen++] = *p++;
							value[vlen] = '\0';
							if (rg_id_from_name(value, out, out_size) &&
							    rg_is_title_id(out))
								return 1;
							out[0] = '\0';
						}
					}
				}
				line = end;
				while (*line == '\r' || *line == '\n') line++;
			}
		}
	}

	/* Fallback: the filename, only if it really looks like an ID. */
	if (rg_id_from_name(path, out, out_size) && rg_is_title_id(out))
		return 1;
	out[0] = '\0';
	return 0;
}

/* Packet checksum: two's complement of the sum of everything after it. */
static uint8_t rg_crc(const uint8_t *d, int len)
{
	uint8_t crc = 0;
	int i;
	for (i = 0; i < len; i++)
		crc = (uint8_t)(crc + d[i]);
	return (uint8_t)(0x100 - crc);
}

/* Draw the Game ID where the GEM can see it. Each byte is 8 bits MSB-first; each
 * bit is a 2px-wide pair -- a magenta marker column then a data column, cyan for 1
 * and yellow for 0. Raw screen coordinates on purpose: this is read by hardware
 * looking at the video output, so it must NOT be shifted by our overscan inset. */
extern "C" void retrogem_draw_gameid(const char *game_id)
{
	GSGLOBAL *gs = getGSGLOBAL();
	uint8_t data[64];
	int dpos = 0, len, i, ii, xstart, ystart;
	int idlen;

	if (gs == NULL || game_id == NULL)
		return;
	idlen = (int)strnlen(game_id, RG_GAMEID_MAX);
	if (idlen <= 0)
		return;

	memset(data, 0, sizeof(data));
	data[dpos++] = 0xA5;                 /* detect word */
	data[dpos++] = 0x00;                 /* address offset */
	dpos++;                              /* checksum, filled below */
	data[dpos++] = (uint8_t)idlen;
	memcpy(&data[dpos], game_id, idlen);
	dpos += idlen;
	data[dpos++] = 0x00;
	data[dpos++] = 0xD5;                 /* end word */
	data[dpos++] = 0x00;                 /* padding */
	len = dpos;
	data[2] = rg_crc(&data[3], len - 3);

	xstart = (gs->Width / 2) - (len * 8);
	ystart = gs->Height - (((gs->Height / 8) * 2) + 20);

	for (i = 0; i < len; i++) {
		for (ii = 7; ii >= 0; ii--) {
			int x = xstart + (i * 16 + ((7 - ii) * 2));
			uint32_t color = ((data[i] >> ii) & 1)
				? GS_SETREG_RGBA(0x00, 0xFF, 0xFF, 0x80)   /* 1 = cyan   */
				: GS_SETREG_RGBA(0xFF, 0xFF, 0x00, 0x80);  /* 0 = yellow */

			gsKit_prim_sprite(gs, x, ystart, x + 1, ystart + 2, 1,
			                  GS_SETREG_RGBA(0xFF, 0x00, 0xFF, 0x80));
			gsKit_prim_sprite(gs, x + 1, ystart, x + 2, ystart + 2, 1, color);
		}
	}
}

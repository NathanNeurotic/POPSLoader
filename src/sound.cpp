#include <string.h>
#include <kernel.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>

#include "include/sound.h"
#include "include/dprintf.h"
#include "include/embed_assets.h"

static bool adpcm_started = false;
static bool audsrv_started = false;

/* Lazy one-time init helpers (audsrv must be up before adpcm). Replace the
   repeated if(!started){init();started=true;} guards across the sound API. */
static void ensure_audsrv(void)
{
    if(!audsrv_started) {
        int rc = audsrv_init();
        DPRINTF("ensure_audsrv: audsrv_init rc=%d\n", rc);
        audsrv_started = true;
    }
}

static void ensure_adpcm(void)
{
    ensure_audsrv();
    if(!adpcm_started) {
        int rc = audsrv_adpcm_init();
        DPRINTF("ensure_adpcm: audsrv_adpcm_init rc=%d\n", rc);
        adpcm_started = true;
    }
}

/*static int fillbuffer(void *arg)
{
	iSignalSema((int)arg);
	return 0;
}*/

/*int main(int argc, char **argv)
{
	int ret;
	int played;
	int err;
	int bytes;
	char chunk[2048];
	FILE *wav;
	ee_sema_t sema;
	int fillbuffer_sema;

	sema.init_count = 0;
	sema.max_count = 1;
	sema.option = 0;
	fillbuffer_sema = CreateSema(&sema);

	audsrv_on_fillbuf(sizeof(chunk), fillbuffer, (void *)fillbuffer_sema);

	wav = fopen("host:song_22k.wav", "rb");

	fseek(wav, 0x30, SEEK_SET);

	DPRINTF("starting play loop\n");
	played = 0;
	bytes = 0;
	while (1)
	{
		ret = fread(chunk, 1, sizeof(chunk), wav);
		if (ret > 0)
		{
			WaitSema(fillbuffer_sema);
			audsrv_play_audio(chunk, ret);
		}

		if (ret < sizeof(chunk))
		{
			break;
		}

		played++;
		bytes = bytes + ret;

		if (played % 8 == 0)
		{
			DPRINTF("\r%d bytes sent..", bytes);
		}

		if (played == 512) break;
	}

	fclose(wav);

}*/


void sound_setvolume(int volume) {
    ensure_audsrv();

	audsrv_set_volume(volume);
}

void sound_setformat(int bits, int freq, int channels){
    ensure_audsrv();

	struct audsrv_fmt_t format;

    format.bits = bits;
	format.freq = freq;
	format.channels = channels;
	
	audsrv_set_format(&format);
}

void sound_setadpcmvolume(int slot, int volume) {
    ensure_adpcm();

	audsrv_adpcm_set_volume(slot, volume);
}

audsrv_adpcm_t* sound_loadadpcm(const char* path){
    ensure_adpcm();

	audsrv_adpcm_t *sample = (audsrv_adpcm_t *)malloc(sizeof(audsrv_adpcm_t));
    if (sample == NULL) {
        return NULL;
    }

    if (strncmp(path, "embed:", 6) == 0) {
        const uint8_t *data = NULL;
        size_t size = 0;
        const char *name = path + 6;

        if (!embedded_get(name, &data, &size) || data == NULL || size == 0) {
            free(sample);
            return NULL;
        }

	audsrv_load_adpcm(sample, (u8*)data, size);
        DPRINTF("sound_loadadpcm: loaded embedded %s (%u bytes)\n", name, (unsigned int)size);
        return sample;
    }

	FILE* adpcm;
	int size;
	u8* buffer;

	adpcm = fopen(path, "rb");
    if (adpcm == NULL) {
    DPRINTF("sound_loadadpcm: fopen failed for %s\n", path);
        free(sample);
        return NULL;
    }

	fseek(adpcm, 0, SEEK_END);
	size = ftell(adpcm);
	fseek(adpcm, 0, SEEK_SET);
    if (size <= 0) {
        DPRINTF("sound_loadadpcm: invalid size %d for %s\n", size, path);
        fclose(adpcm);
        free(sample);
        return NULL;
    }

	buffer = (u8*)malloc(size);
    if (buffer == NULL) {
        DPRINTF("sound_loadadpcm: alloc failed for %s\n", path);
        fclose(adpcm);
        free(sample);
        return NULL;
    }

	fread(buffer, 1, size, adpcm);
	fclose(adpcm);

	audsrv_load_adpcm(sample, buffer, size);

	free(buffer);

    DPRINTF("sound_loadadpcm: loaded %s (%d bytes)\n", path, size);

	return sample;
}

void sound_playadpcm(int slot, audsrv_adpcm_t *sample) {
    ensure_adpcm();

    if (sample == NULL) {
        DPRINTF("sound_playadpcm: sample is NULL\n");
        return;
    }
	audsrv_ch_play_adpcm(slot, sample);
    DPRINTF("sound_playadpcm: playing slot=%d sample=%p\n", slot, sample);
}

void sound_freeadpcm(audsrv_adpcm_t *sample) {
    if (sample == NULL) {
        return;
    }
    audsrv_free_adpcm(sample);
    free(sample);
}

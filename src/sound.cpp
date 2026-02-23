#include <string.h>
#include <kernel.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>

#include "include/sound.h"
#include "include/dprintf.h"
#include "include/asset_loader.h"

static bool adpcm_started = false;
static bool audsrv_started = false;

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
    if(!audsrv_started) {
        int rc = audsrv_init();
        DPRINTF("sound_setvolume: audsrv_init rc=%d\n", rc);
        audsrv_started = true;
    }

	audsrv_set_volume(volume);
}

void sound_setformat(int bits, int freq, int channels){
    if(!audsrv_started) {
        int rc = audsrv_init();
        DPRINTF("sound_setformat: audsrv_init rc=%d\n", rc);
        audsrv_started = true;
    }

	struct audsrv_fmt_t format;

    format.bits = bits;
	format.freq = freq;
	format.channels = channels;
	
	audsrv_set_format(&format);
}

void sound_setadpcmvolume(int slot, int volume) {
    if(!audsrv_started) {
        int rc = audsrv_init();
        DPRINTF("sound_setadpcmvolume: audsrv_init rc=%d\n", rc);
        audsrv_started = true;
    }
    if(!adpcm_started) {
        int rc = audsrv_adpcm_init();
        DPRINTF("sound_setadpcmvolume: adpcm_init rc=%d\n", rc);
        adpcm_started = true;
    }

	audsrv_adpcm_set_volume(slot, volume);
}

static audsrv_adpcm_t* sound_loadadpcm_impl(const void* data, size_t size)
{
	audsrv_adpcm_t *sample = (audsrv_adpcm_t *)malloc(sizeof(audsrv_adpcm_t));
	if (sample == NULL || data == NULL || size == 0) {
		if (sample) free(sample);
		return NULL;
	}
	audsrv_load_adpcm(sample, (void*)data, (int)size);
	return sample;
}

audsrv_adpcm_t* sound_loadadpcm_buffer(const void* data, size_t size)
{
    if(!audsrv_started) {
        int rc = audsrv_init();
        DPRINTF("sound_loadadpcm_buffer: audsrv_init rc=%d\n", rc);
        audsrv_started = true;
    }
    if(!adpcm_started) {
        int rc = audsrv_adpcm_init();
        DPRINTF("sound_loadadpcm_buffer: adpcm_init rc=%d\n", rc);
        adpcm_started = true;
    }
    return sound_loadadpcm_impl(data, size);
}

audsrv_adpcm_t* sound_loadadpcm(const char* path){
    if(!audsrv_started) {
        int rc = audsrv_init();
        DPRINTF("sound_loadadpcm: audsrv_init rc=%d\n", rc);
        audsrv_started = true;
    }
    if(!adpcm_started) {
        int rc = audsrv_adpcm_init();
        DPRINTF("sound_loadadpcm: adpcm_init rc=%d\n", rc);
        adpcm_started = true;
    }

    AssetBuffer asset;
    if (!LoadAsset(path, &asset)) {
        DPRINTF("sound_loadadpcm: load asset failed for %s\n", path);
        return NULL;
    }
    audsrv_adpcm_t* sample = sound_loadadpcm_impl(asset.data, asset.size);
    FreeAsset(&asset);
    return sample;
}

void sound_playadpcm(int slot, audsrv_adpcm_t *sample) {
    if(!audsrv_started) {
        int rc = audsrv_init();
        DPRINTF("sound_playadpcm: audsrv_init rc=%d\n", rc);
        audsrv_started = true;
    }
    if(!adpcm_started) {
        int rc = audsrv_adpcm_init();
        DPRINTF("sound_playadpcm: adpcm_init rc=%d\n", rc);
        adpcm_started = true;
    }

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

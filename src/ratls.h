/* Verified HTTPS: the Check for Updates. See src/ratls.c
   (portable TLS + HTTP over callbacks, C so the host test builds it) and src/updater.cpp
   (DNS, TCP, clock, entropy, roots). */
#ifndef __RATLS_H__
#define __RATLS_H__

#include <stddef.h>

/* The configuration the mbedtls library is built with (the Makefile): TLS 1.2 client only. */
#ifndef MBEDTLS_CONFIG_FILE
#define MBEDTLS_CONFIG_FILE "popsloader_mbedtls_slim_config.h"
#endif

#ifdef __cplusplus
extern "C" {
#endif

enum {
    RATLS_ERR_NET = -1,      /* no network, DNS failed, or connect refused */
    RATLS_ERR_CLOCK = -2,    /* console clock unset (before 2025): nothing was sent */
    RATLS_ERR_TLS = -3,      /* handshake or record failure */
    RATLS_ERR_CERT = -4,     /* certificate invalid, expired, untrusted or for another host */
    RATLS_ERR_HTTP = -5,     /* not 200, malformed, or larger than the buffer */
    RATLS_ERR_TIMEOUT = -6,  /* the deadline passed */
    RATLS_ERR_MEM = -7,      /* out of memory, or the crypto library failed to start */
    RATLS_ERR_ARG = -8,      /* bad arguments */
    RATLS_ERR_REDIRECT = -9, /* raTlsDownload: the server redirected; the target is in location */
    RATLS_ERR_SINK = -10     /* raTlsDownload: the sink refused the data (a write failed) */
};

/* Receives each piece of a download's body in order. 0 to go on, anything else stops the download. */
typedef int (*ratls_sink_t)(void *ctx, const char *data, int len);

typedef struct
{
    int (*send)(void *ctx, const unsigned char *buf, size_t len); /* mbedTLS BIO contract */
    int (*recv)(void *ctx, unsigned char *buf, size_t len);       /* MBEDTLS_ERR_SSL_TIMEOUT at the deadline, 0 = closed */
    void *ctx;
    long long (*now_utc)(void); /* seconds since 1970 UTC, -1 = clock unset */
} ratls_io_t;

typedef struct
{
    const unsigned char *der;
    size_t len;
} ratls_anchor_t;

/* 1 when now_utc() gives a usable time. Callers check it before any DNS or connection. */
int raTlsClockOk(long long (*now_utc)(void));

/* One HTTPS GET over an already-connected io. Returns the body offset in buf (>= 0), with the
   total bytes in buf (headers + body, NUL-terminated) in *length, or RATLS_ERR_*. */
int raTlsRequest(const ratls_io_t *io, const char *host, const char *path, const char *user_agent,
                 const ratls_anchor_t *anchors, int anchor_count, char *buf, int max, int *length);

/* One streamed HTTPS GET over an already-connected io, for Check for Updates. buf (max >= 512) holds
   the request and then the headers, so it must hold both; the body goes to sink as it arrives. Only a
   200 with a Content-Length of 1..max_body and no transfer or content encoding is taken. Returns the
   body length, RATLS_ERR_REDIRECT with the Location target in location (301/302/303/307/308), or
   RATLS_ERR_*. Certificates are verified exactly as for raTlsRequest. */
/* The Content-Length of the body raTlsDownload last accepted, set before the first sink call (a progress bar total). */
extern int raTlsBodyLength;
int raTlsDownload(const ratls_io_t *io, const char *host, const char *path, const char *user_agent,
                  const ratls_anchor_t *anchors, int anchor_count, char *buf, int max, int max_body,
                  ratls_sink_t sink, void *sink_ctx, char *location, int location_size);

/* The console RTC (already decoded from BCD, full year) to seconds since 1970 UTC. */
long long raTlsRtcToUtc(int year, int month, int day, int hour, int minute, int second);

/* PS2: raTlsDownload to host:443 with GitHub's roots (Sectigo E46/R46, ISRG X1/X2). The deadline is
   idle time: 15 s without data, so a long download over a slow card is not cut off. Refuses while a
   UDP transport owns the NIC. Same return convention as raTlsDownload. */
int raHttpsDownload(const char *host, const char *path, char *buf, int max, int max_body, ratls_sink_t sink,
                    void *sink_ctx, char *location, int location_size);

/* PS2: 1 while a UDP transport owns (or is chosen for) the NIC, so no HTTPS request may start. */
int ratlsNicBusy(void);

#ifdef __cplusplus
}
#endif

#endif

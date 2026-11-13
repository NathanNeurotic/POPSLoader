/*
  ratls.c -- the portable half of the RetroAchievements HTTPS lookup.

  ORBIT asks retroachievements.org for a game's ID by hash over HTTPS; the RA
  edition does the same. This file runs one TLS 1.3 / 1.2 session (vendored
  mbedTLS, third_party/mbedtls) and one HTTP GET over callbacks the caller
  supplies, so it builds unchanged on the host for tests. raTlsDownload is
  Check for Updates' streamed GET (every standard edition; the non-RA ones
  build this file with the slim TLS 1.2 configuration). Sockets, DNS, the
  console clock, entropy and the embedded roots are in updater.cpp.

  Certificates are always verified (VERIFY_REQUIRED, SNI, host name) against
  the anchors passed in; a clock that is not set fails closed before anything
  is sent. A body is returned only when it arrived whole: Content-Length met,
  chunked encoding terminated, or the server closed a body without either.
*/

#include "ratls.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "mbedtls/platform_time.h"
#include "mbedtls/ssl.h"
#include "mbedtls/x509_crt.h"
#if defined(MBEDTLS_USE_PSA_CRYPTO)
#include "mbedtls/psa_util.h"
#include "psa/crypto.h"
#else /* the slim TLS 1.2 configuration (Check for Updates): mbedTLS's own DRBG */
#include "mbedtls/ctr_drbg.h"
#include "mbedtls/entropy.h"
#endif

#define RATLS_REQUEST_MAX 512

static long long (*g_now)(void);
#if defined(MBEDTLS_USE_PSA_CRYPTO)
static int g_psaReady;
#else
static int g_drbgReady;
static mbedtls_entropy_context g_entropy;
static mbedtls_ctr_drbg_context g_drbg;
#endif

/* The PS2 RTC keeps Japan time (ps2sdk's ps2time() in ee/rpc/cdvd/src/scmd.c converts it with a
   -9 h offset), so UTC = RTC - 9 h. */
#define RATLS_RTC_ZONE_SECONDS (9 * 60 * 60)

long long raTlsRtcToUtc(int year, int month, int day, int hour, int minute, int second)
{
    /* Days from 1970-01-01 (Howard Hinnant's days_from_civil). */
    int y = year - (month <= 2);
    long long era = (y >= 0 ? y : y - 399) / 400;
    unsigned yoe = (unsigned)(y - era * 400);
    unsigned doy = (153u * (unsigned)(month + (month > 2 ? -3 : 9)) + 2u) / 5u + (unsigned)day - 1u;
    unsigned doe = yoe * 365u + yoe / 4u - yoe / 100u + doy;
    long long days = era * 146097 + (long long)doe - 719468;

    return days * 86400 + hour * 3600 + minute * 60 + second - RATLS_RTC_ZONE_SECONDS;
}

int raTlsClockOk(long long (*now_utc)(void))
{
    return now_utc != NULL && now_utc() >= 0;
}

static mbedtls_time_t ratlsTime(mbedtls_time_t *timer)
{
    mbedtls_time_t now = (mbedtls_time_t)(g_now != NULL ? g_now() : -1);
    if (timer != NULL)
        *timer = now;
    return now;
}

/* Header end (index of the body) or -1. */
static int headerEnd(const char *buf, int len)
{
    int i;
    for (i = 0; i + 3 < len; i++)
        if (buf[i] == '\r' && buf[i + 1] == '\n' && buf[i + 2] == '\r' && buf[i + 3] == '\n')
            return i + 4;
    return -1;
}

/* Value of a header (case-insensitive name) within the header block, or NULL. */
static const char *headerValue(const char *buf, int bodyAt, const char *name)
{
    size_t n = strlen(name);
    const char *line = strstr(buf, "\r\n");

    while (line != NULL && line + 2 < buf + bodyAt) {
        const char *p = line + 2;
        size_t i;
        for (i = 0; i < n && p[i] && (p[i] | 0x20) == (name[i] | 0x20); i++)
            ;
        if (i == n && p[n] == ':') {
            p += n + 1;
            while (*p == ' ' || *p == '\t')
                p++;
            return p;
        }
        line = strstr(p, "\r\n");
    }
    return NULL;
}

/* De-chunks the body in place (only checks it when !write). Returns the new body length, or -1
   if malformed or incomplete (the last chunk has not arrived). */
static int dechunk(char *body, int len, int write)
{
    int in = 0, out = 0;

    for (;;) {
        char *end;
        long size;
        int eol;

        for (eol = in; eol + 1 < len && !(body[eol] == '\r' && body[eol + 1] == '\n'); eol++)
            ;
        if (eol + 1 >= len)
            return -1;
        size = strtol(body + in, &end, 16);
        if (end == body + in || size < 0)
            return -1;
        in = eol + 2;
        if (size == 0) {
            /* Complete only at the blank line that ends the (usually empty) trailer section. */
            for (;;) {
                for (eol = in; eol + 1 < len && !(body[eol] == '\r' && body[eol + 1] == '\n'); eol++)
                    ;
                if (eol + 1 >= len)
                    return -1;
                if (eol == in)
                    return out;
                in = eol + 2;
            }
        }
        if (size > len - in - 2 || body[in + size] != '\r' || body[in + size + 1] != '\n')
            return -1;
        if (write)
            memmove(body + out, body + in, (size_t)size);
        out += (int)size;
        in += (int)size + 2;
    }
}

/* Whether everything has arrived: by Content-Length, or the chunked terminator. */
static int responseComplete(char *buf, int len)
{
    int bodyAt = headerEnd(buf, len);
    const char *value;

    if (bodyAt < 0)
        return 0;
    if ((value = headerValue(buf, bodyAt, "Content-Length")) != NULL)
        return len - bodyAt >= atoi(value);
    /* Walk the chunks: a body that merely ends "0\r\n\r\n" inside a chunk is not the end. */
    if ((value = headerValue(buf, bodyAt, "Transfer-Encoding")) != NULL && !strncmp(value, "chunked", 7))
        return dechunk(buf + bodyAt, len - bodyAt, 0) >= 0;
    return 0; /* delimited by the server closing */
}

static int finishResponse(char *buf, int len, int *length)
{
    int status, bodyAt = headerEnd(buf, len);
    const char *value;

    if (bodyAt < 0 || sscanf(buf, "HTTP/%*d.%*d %d", &status) != 1 || status != 200)
        return RATLS_ERR_HTTP;
    if ((value = headerValue(buf, bodyAt, "Transfer-Encoding")) != NULL && !strncmp(value, "chunked", 7)) {
        int body = dechunk(buf + bodyAt, len - bodyAt, 1);
        if (body < 0)
            return RATLS_ERR_HTTP;
        len = bodyAt + body;
    } else if ((value = headerValue(buf, bodyAt, "Content-Length")) != NULL) {
        int want = atoi(value);
        if (want < 0 || len - bodyAt < want)
            return RATLS_ERR_HTTP; /* cut short: never parse a partial document */
        len = bodyAt + want;
    }
    buf[len] = '\0';
    *length = len;
    return bodyAt;
}

static int mapError(int rc, const mbedtls_ssl_context *ssl)
{
    uint32_t flags;

    if (rc == MBEDTLS_ERR_SSL_TIMEOUT)
        return RATLS_ERR_TIMEOUT;
    if (rc == MBEDTLS_ERR_SSL_ALLOC_FAILED)
        return RATLS_ERR_MEM;
    flags = mbedtls_ssl_get_verify_result(ssl);
    if (rc == MBEDTLS_ERR_X509_CERT_VERIFY_FAILED || (flags != 0 && flags != (uint32_t)-1))
        return RATLS_ERR_CERT;
    return RATLS_ERR_TLS;
}

typedef struct
{
    mbedtls_ssl_context ssl;
    mbedtls_ssl_config conf;
    mbedtls_x509_crt ca;
} ratls_session_t;

/* The random source, started once per boot like the PSA one it stands in for. */
static int ratlsRngReady(void)
{
#if defined(MBEDTLS_USE_PSA_CRYPTO)
    if (!g_psaReady) {
        if (psa_crypto_init() != PSA_SUCCESS)
            return 0;
        g_psaReady = 1;
    }
#else
    if (!g_drbgReady) {
        mbedtls_entropy_init(&g_entropy);
        mbedtls_ctr_drbg_init(&g_drbg);
        if (mbedtls_ctr_drbg_seed(&g_drbg, mbedtls_entropy_func, &g_entropy, (const unsigned char *)"riptopl", 7) != 0) {
            mbedtls_ctr_drbg_free(&g_drbg);
            mbedtls_entropy_free(&g_entropy);
            return 0;
        }
        g_drbgReady = 1;
    }
#endif
    return 1;
}

/* Handshake (certificate, host name and date verified) and send the request. 0 or RATLS_ERR_*. The
   caller frees the session with sessionFree whatever this returns. */
static int sessionOpen(ratls_session_t *s, const ratls_io_t *io, const char *host, const ratls_anchor_t *anchors,
                       int anchor_count, const char *request, int reqlen)
{
    int rc, i, sent = 0;

    mbedtls_ssl_init(&s->ssl);
    mbedtls_ssl_config_init(&s->conf);
    mbedtls_x509_crt_init(&s->ca);

    g_now = io->now_utc;
    mbedtls_platform_set_time(ratlsTime);
    if (!ratlsRngReady())
        return RATLS_ERR_MEM;

    for (i = 0; i < anchor_count; i++)
        if (mbedtls_x509_crt_parse_der(&s->ca, anchors[i].der, anchors[i].len) != 0)
            return RATLS_ERR_TLS; /* a broken anchor is a build defect, never "trust anything" */

    if (mbedtls_ssl_config_defaults(&s->conf, MBEDTLS_SSL_IS_CLIENT, MBEDTLS_SSL_TRANSPORT_STREAM,
                                    MBEDTLS_SSL_PRESET_DEFAULT) != 0)
        return RATLS_ERR_TLS;
    mbedtls_ssl_conf_authmode(&s->conf, MBEDTLS_SSL_VERIFY_REQUIRED);
    mbedtls_ssl_conf_ca_chain(&s->conf, &s->ca, NULL);
#if defined(MBEDTLS_USE_PSA_CRYPTO)
    mbedtls_ssl_conf_rng(&s->conf, mbedtls_psa_get_random, MBEDTLS_PSA_RANDOM_STATE);
#else
    mbedtls_ssl_conf_rng(&s->conf, mbedtls_ctr_drbg_random, &g_drbg);
#endif
    if ((rc = mbedtls_ssl_setup(&s->ssl, &s->conf)) != 0 || (rc = mbedtls_ssl_set_hostname(&s->ssl, host)) != 0)
        return rc == MBEDTLS_ERR_SSL_ALLOC_FAILED ? RATLS_ERR_MEM : RATLS_ERR_TLS;
    mbedtls_ssl_set_bio(&s->ssl, io->ctx, io->send, io->recv, NULL);

    while ((rc = mbedtls_ssl_handshake(&s->ssl)) != 0)
        if (rc != MBEDTLS_ERR_SSL_WANT_READ && rc != MBEDTLS_ERR_SSL_WANT_WRITE)
            return mapError(rc, &s->ssl);

    while (sent < reqlen) {
        rc = mbedtls_ssl_write(&s->ssl, (const unsigned char *)request + sent, (size_t)(reqlen - sent));
        if (rc == MBEDTLS_ERR_SSL_WANT_READ || rc == MBEDTLS_ERR_SSL_WANT_WRITE)
            continue;
        if (rc <= 0)
            return mapError(rc, &s->ssl);
        sent += rc;
    }
    return 0;
}

static void sessionFree(ratls_session_t *s)
{
    mbedtls_ssl_free(&s->ssl);
    mbedtls_ssl_config_free(&s->conf);
    mbedtls_x509_crt_free(&s->ca);
}

/* One read: > 0 bytes, 0 when the server closed, or RATLS_ERR_*. */
static int sessionRead(ratls_session_t *s, char *buf, int max)
{
    for (;;) {
        int rc = mbedtls_ssl_read(&s->ssl, (unsigned char *)buf, (size_t)max);
        if (rc > 0)
            return rc;
        if (rc == MBEDTLS_ERR_SSL_WANT_READ || rc == MBEDTLS_ERR_SSL_WANT_WRITE ||
            rc == MBEDTLS_ERR_SSL_RECEIVED_NEW_SESSION_TICKET)
            continue;
        if (rc == 0 || rc == MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY)
            return 0;
        return mapError(rc, &s->ssl);
    }
}

int raTlsRequest(const ratls_io_t *io, const char *host, const char *path, const char *user_agent,
                 const ratls_anchor_t *anchors, int anchor_count, char *buf, int max, int *length)
{
    ratls_session_t s;
    char request[RATLS_REQUEST_MAX];
    int rc, len = 0, result, reqlen;

    if (length != NULL)
        *length = 0;
    if (io == NULL || io->send == NULL || io->recv == NULL || host == NULL || path == NULL || user_agent == NULL ||
        anchors == NULL || anchor_count <= 0 || buf == NULL || max < 64 || length == NULL)
        return RATLS_ERR_ARG;
    if (!raTlsClockOk(io->now_utc))
        return RATLS_ERR_CLOCK;
    reqlen = snprintf(request, sizeof(request),
                      "GET %s HTTP/1.1\r\nHost: %s\r\nUser-Agent: %s\r\nAccept: application/json\r\nConnection: close\r\n\r\n",
                      path, host, user_agent);
    if (reqlen <= 0 || reqlen >= (int)sizeof(request))
        return RATLS_ERR_ARG;

    if ((result = sessionOpen(&s, io, host, anchors, anchor_count, request, reqlen)) != 0)
        goto out;

    for (;;) {
        if (len >= max - 1) {
            result = RATLS_ERR_HTTP; /* larger than the buffer */
            goto out;
        }
        rc = sessionRead(&s, buf + len, max - 1 - len);
        if (rc < 0) {
            result = rc;
            goto out;
        }
        if (rc == 0)
            break; /* the server closed: whatever arrived is complete or rejected below */
        len += rc;
        buf[len] = '\0';
        if (responseComplete(buf, len))
            break;
    }
    buf[len] = '\0';
    result = finishResponse(buf, len, length);
    mbedtls_ssl_close_notify(&s.ssl);

out:
    sessionFree(&s);
    return result;
}

/* Copies the redirect target (Location) into location, NUL-terminated. 1, or 0 when absent or too long. */
static int copyLocation(const char *buf, int bodyAt, char *location, int size)
{
    const char *value = headerValue(buf, bodyAt, "Location");
    int n = 0;

    if (value == NULL || location == NULL || size <= 0)
        return 0;
    while (value[n] != '\0' && value[n] != '\r' && value[n] != '\n') {
        if (n >= size - 1 || (unsigned char)value[n] <= ' ')
            return 0; /* never follow a truncated or odd target */
        location[n] = value[n];
        n++;
    }
    location[n] = '\0';
    return n > 0;
}

int raTlsBodyLength;

int raTlsDownload(const ratls_io_t *io, const char *host, const char *path, const char *user_agent,
                  const ratls_anchor_t *anchors, int anchor_count, char *buf, int max, int max_body,
                  ratls_sink_t sink, void *sink_ctx, char *location, int location_size)
{
    ratls_session_t s;
    int rc, len = 0, result, reqlen, bodyAt = -1, status, want, got;
    const char *value;

    if (location != NULL && location_size > 0)
        location[0] = '\0';
    if (io == NULL || io->send == NULL || io->recv == NULL || host == NULL || path == NULL || user_agent == NULL ||
        anchors == NULL || anchor_count <= 0 || buf == NULL || max < 512 || max_body <= 0 || sink == NULL)
        return RATLS_ERR_ARG;
    if (!raTlsClockOk(io->now_utc))
        return RATLS_ERR_CLOCK;
    /* The request is composed in buf: GitHub's download redirects carry a long signed query. */
    reqlen = snprintf(buf, (size_t)max, "GET %s HTTP/1.1\r\nHost: %s\r\nUser-Agent: %s\r\nAccept: */*\r\nConnection: close\r\n\r\n",
                      path, host, user_agent);
    if (reqlen <= 0 || reqlen >= max)
        return RATLS_ERR_ARG;

    if ((result = sessionOpen(&s, io, host, anchors, anchor_count, buf, reqlen)) != 0)
        goto out;

    /* The header block, whole, within buf. */
    while (bodyAt < 0) {
        if (len >= max - 1) {
            result = RATLS_ERR_HTTP;
            goto out;
        }
        rc = sessionRead(&s, buf + len, max - 1 - len);
        if (rc <= 0) {
            result = rc < 0 ? rc : RATLS_ERR_HTTP; /* closed before the headers ended */
            goto out;
        }
        len += rc;
        buf[len] = '\0';
        bodyAt = headerEnd(buf, len);
    }
    result = RATLS_ERR_HTTP;
    if (sscanf(buf, "HTTP/%*d.%*d %d", &status) != 1)
        goto out;
    if (status == 301 || status == 302 || status == 303 || status == 307 || status == 308) {
        if (copyLocation(buf, bodyAt, location, location_size))
            result = RATLS_ERR_REDIRECT;
        goto out;
    }
    /* Only a whole, sized, plain body: no chunked or compressed transfer, nothing past the limit. */
    if (status != 200 || headerValue(buf, bodyAt, "Transfer-Encoding") != NULL)
        goto out;
    if ((value = headerValue(buf, bodyAt, "Content-Length")) == NULL || *value < '0' || *value > '9')
        goto out;
    for (want = 0; *value >= '0' && *value <= '9'; value++)
        if ((want = want * 10 + (*value - '0')) > max_body)
            goto out; /* stops before it could overflow */
    if (want <= 0 || (*value != '\0' && *value != '\r' && *value != '\n' && *value != ' '))
        goto out;
    if ((value = headerValue(buf, bodyAt, "Content-Encoding")) != NULL && strncmp(value, "identity", 8))
        goto out;

    raTlsBodyLength = want;
    got = len - bodyAt;
    if (got > want)
        got = want; /* never hand on bytes past the declared body */
    if (got > 0 && sink(sink_ctx, buf + bodyAt, got) != 0) {
        result = RATLS_ERR_SINK;
        goto out;
    }
    while (got < want) {
        rc = sessionRead(&s, buf, (want - got) < max ? want - got : max);
        if (rc <= 0) {
            result = rc < 0 ? rc : RATLS_ERR_HTTP; /* cut short */
            goto out;
        }
        if (sink(sink_ctx, buf, rc) != 0) {
            result = RATLS_ERR_SINK;
            goto out;
        }
        got += rc;
    }
    result = want;
    mbedtls_ssl_close_notify(&s.ssl);

out:
    sessionFree(&s);
    return result;
}

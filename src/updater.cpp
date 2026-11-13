/*
  updater.cpp -- Check for Updates: verified HTTPS to GitHub on a worker thread, and the Lua
  bindings that drive it (System.updateStart / System.updateStatus).

  The menu's SMB network stack (EnsureNet + System.smbNetUp: modules, link, the saved IP
  settings, DHCP) is already up when this runs; here it is only DNS, a TCP connection through
  ps2ips, a BIO for mbedTLS, the console clock as UTC, an entropy source and the embedded roots
  (third_party/ca-roots). TLS 1.2 client only, full certificate verification (ratls.c).

  Two jobs: "check" reads the latest release's SHA256SUMS.txt (version from the zip's name, hash
  of POPSLOADER.ELF); "install" streams POPSLOADER.ELF to a file the caller names, checking the
  ELF header and the SHA-256 from the check. Moving the file into place is Lua's (System.rename,
  with no backup of the old ELF), so a failed download never touches the running ELF.
*/

#include "ratls.h"

#include <ps2ips.h>
#include <netinet/in.h> /* sockaddr_in */
#include <netdb.h>
#include <kernel.h>
#include <delaythread.h>
#include <libcdvd.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

extern "C" {
#include "lua.h"
#include "lauxlib.h"
}

#include "mbedtls/net_sockets.h" /* MBEDTLS_ERR_NET_SEND_FAILED */
#include "mbedtls/platform_time.h"
#include "mbedtls/sha256.h"
#include "mbedtls/ssl.h"

constexpr int DEADLINE_MS = 8000; /* DNS, connect and handshake */
constexpr int IDLE_MS = 15000;    /* a download: no data for this long ends it */
constexpr int POLL_MS = 25;
constexpr int MIN_YEAR = 2025; /* an earlier RTC is unset: fail closed */
constexpr int BUF = 16 * 1024; /* the request and each piece of the headers and body */
constexpr int LOCATION = 2048; /* GitHub's signed download redirects run to about 900 bytes */
constexpr int SUMS_MAX = 8 * 1024;
constexpr int ELF_MAX = 8 * 1024 * 1024;
constexpr int STACK = 96 * 1024; /* mbedTLS's handshake needs a real stack */

extern "C" {
extern unsigned char ratls_root_sectigoe46[], ratls_root_sectigor46[], ratls_root_isrgrootx1[], ratls_root_isrgrootx2[];
extern unsigned int size_ratls_root_sectigoe46, size_ratls_root_sectigor46, size_ratls_root_isrgrootx1, size_ratls_root_isrgrootx2;
mbedtls_ms_time_t mbedtls_ms_time(void);
int mbedtls_hardware_poll(void *data, unsigned char *out, size_t len, size_t *olen);
}

/* Results handed to Lua. */
enum {
    UP_OK = 0,
    UP_NEWEST = 1,   /* check: nothing newer */
    UP_NET = 2,      /* DNS, connect, timeout */
    UP_CLOCK = 3,    /* console clock unset */
    UP_TLS = 4,      /* handshake or certificate */
    UP_GITHUB = 5,   /* GitHub answered something unusable */
    UP_WRITE = 6,    /* the file could not be written */
    UP_VERIFY = 7,   /* not an ELF, or the SHA-256 differs */
    UP_MEMORY = 8,
    UP_BUSY = 9
};

static volatile int gState; /* 0 idle, 1 running, 2 done */
static volatile int gResult;
static volatile int gDone, gTotal;
static char gRemote[32];
static unsigned char gSha[32];
static char gLocal[32];
static char gDest[256];
static int gInstall;

static int bcd(unsigned char v)
{
    return (v >> 4) * 10 + (v & 0x0F);
}

static long long now(void)
{
    sceCdCLOCK clk;

    if (sceCdReadClock(&clk) == 0)
        return -1;
    int year = 2000 + bcd(clk.year);
    if (year < MIN_YEAR)
        return -1;
    return raTlsRtcToUtc(year, bcd(clk.month & 0x1F), bcd(clk.day), bcd(clk.hour), bcd(clk.minute), bcd(clk.second));
}

mbedtls_ms_time_t mbedtls_ms_time(void)
{
    return static_cast<mbedtls_ms_time_t>(clock()) * 1000 / CLOCKS_PER_SEC;
}

static inline unsigned int cop0Count(void)
{
    unsigned int count;
    __asm__ volatile("mfc0 %0, $9"
                     : "=r"(count));
    return count;
}

/* The PS2 has no hardware RNG. Each output byte folds 8 samples of the 294.912 MHz COP0 count's
   low bits across a thread switch (interrupt and DMA timing make them jitter), credited at 1 bit
   per sample; the CDVD clock and clock() are mixed in once per call. mbedTLS gathers until the
   CTR_DRBG seed reaches its threshold. Same source as RiptOPL's updater. */
int mbedtls_hardware_poll(void *data, unsigned char *out, size_t len, size_t *olen)
{
    sceCdCLOCK clk;

    (void)data;
    for (size_t i = 0; i < len; i++) {
        unsigned char byte = 0;
        for (int s = 0; s < 8; s++) {
            unsigned int before = cop0Count();
            DelayThread(1);
            byte = static_cast<unsigned char>((byte << 1) | (byte >> 7)) ^ static_cast<unsigned char>(cop0Count() - before);
        }
        out[i] = byte ^ static_cast<unsigned char>(clock());
    }
    if (len >= sizeof(clk) && sceCdReadClock(&clk) != 0) {
        const unsigned char *c = reinterpret_cast<const unsigned char *>(&clk);
        for (size_t i = 0; i < sizeof(clk); i++)
            out[i] ^= c[i];
    }
    *olen = len;
    return 0;
}

struct Bio
{
    int sock;
    clock_t start; /* the budget runs from before DNS */
    int idle;      /* a download: the budget restarts at every received piece */
};

/* clock() is a 32-bit microsecond counter here: compare elapsed time, which survives the wrap. */
static int expired(clock_t start, int ms)
{
    return (clock_t)(clock() - start) >= (clock_t)ms * (CLOCKS_PER_SEC / 1000);
}

static int bioSend(void *ctx, const unsigned char *buf, size_t len)
{
    Bio *bio = static_cast<Bio *>(ctx);
    int n = send(bio->sock, const_cast<unsigned char *>(buf), len, 0);
    return n < 0 ? MBEDTLS_ERR_NET_SEND_FAILED : n;
}

/* ps2ips copies a received length whole only when it is a multiple of 64 with a short tail, so
   peek first, then take a length it copies whole (the same rule as RiptOPL's ranet). */
static int tcpRecv(int sock, void *aligned, int max)
{
    int got = recv(sock, aligned, max, 0x08 | 0x01); /* MSG_DONTWAIT | MSG_PEEK, lwIP's values */
    if (got <= 0)
        return got;
    if (got > 64 && got % 64 > 48)
        got -= got % 64 - 48;
    return recv(sock, aligned, got, 0x08);
}

/* Reads through a 64-byte-aligned bounce buffer, polling until data, close or the deadline. */
static int bioRecv(void *ctx, unsigned char *buf, size_t len)
{
    static unsigned char chunk[960] __attribute__((aligned(64)));
    Bio *bio = static_cast<Bio *>(ctx);

    for (;;) {
        if (expired(bio->start, bio->idle ? IDLE_MS : DEADLINE_MS))
            return MBEDTLS_ERR_SSL_TIMEOUT;
        int got = tcpRecv(bio->sock, chunk, len < sizeof(chunk) ? static_cast<int>(len) : static_cast<int>(sizeof(chunk)));
        if (got == 0)
            return 0; /* closed */
        if (got > 0) {
            memcpy(buf, chunk, got);
            if (bio->idle)
                bio->start = clock();
            return got;
        }
        DelayThread(POLL_MS * 1000);
    }
}

/* One streamed GET to host:443 with GitHub's roots. The body length, or RATLS_ERR_*. */
static int httpsDownload(const char *host, const char *path, char *buf, int max, int max_body, ratls_sink_t sink,
                         void *sink_ctx, char *location, int location_size)
{
    const ratls_anchor_t anchors[] = {
        {ratls_root_sectigoe46, size_ratls_root_sectigoe46}, /* github.com */
        {ratls_root_sectigor46, size_ratls_root_sectigor46},
        {ratls_root_isrgrootx1, size_ratls_root_isrgrootx1}, /* the release download host */
        {ratls_root_isrgrootx2, size_ratls_root_isrgrootx2},
    };
    struct sockaddr_in to;
    clock_t start = clock();

    if (location != NULL && location_size > 0)
        location[0] = '\0';
    if (!raTlsClockOk(now)) /* before any DNS lookup or connection */
        return RATLS_ERR_CLOCK;

    struct hostent *he = gethostbyname(host);
    if (he == NULL || he->h_addr_list == NULL || he->h_addr_list[0] == NULL)
        return RATLS_ERR_NET;
    memset(&to, 0, sizeof(to));
    to.sin_family = AF_INET;
    to.sin_port = 0xBB01; /* htons(443) on this little-endian EE */
    memcpy(&to.sin_addr, he->h_addr_list[0], sizeof(to.sin_addr));

    Bio bio = {socket(AF_INET, SOCK_STREAM, 0), start, 0};
    if (bio.sock < 0)
        return RATLS_ERR_NET;
    if (connect(bio.sock, reinterpret_cast<struct sockaddr *>(&to), sizeof(to)) < 0) {
        disconnect(bio.sock);
        return RATLS_ERR_NET;
    }
    if (expired(start, DEADLINE_MS)) { /* DNS and connect already used the budget */
        disconnect(bio.sock);
        return RATLS_ERR_TIMEOUT;
    }
    bio.idle = 1; /* from here, only a stall ends it */
    bio.start = clock();
    const ratls_io_t io = {bioSend, bioRecv, &bio, now};

    int rc = raTlsDownload(&io, host, path, "POPSLoader-updater", anchors, sizeof(anchors) / sizeof(anchors[0]), buf, max, max_body,
                           sink, sink_ctx, location, location_size);
    disconnect(bio.sock);
    return rc;
}

static int toResult(int rc)
{
    switch (rc) {
        case RATLS_ERR_CLOCK:
            return UP_CLOCK;
        case RATLS_ERR_MEM:
            return UP_MEMORY;
        case RATLS_ERR_SINK:
            return UP_WRITE;
        case RATLS_ERR_NET:
        case RATLS_ERR_TIMEOUT:
            return UP_NET;
        case RATLS_ERR_TLS:
        case RATLS_ERR_CERT:
            return UP_TLS;
        default:
            return UP_GITHUB;
    }
}

/* ---- GitHub URLs: only https://github.com/... or the release download host, never elsewhere. ---- */

/* Splits "https://host/path" into host and the path (with its query); NULL if it is not https. */
static const char *splitUrl(const char *url, char *host, int host_max)
{
    if (strncmp(url, "https://", 8) != 0)
        return NULL;
    url += 8;
    const char *slash = strchr(url, '/');
    if (slash == NULL || slash == url || slash - url >= host_max)
        return NULL;
    memcpy(host, url, slash - url);
    host[slash - url] = '\0';
    if (strchr(host, ':') != NULL || strchr(host, '@') != NULL)
        return NULL;
    if (strcmp(host, "github.com") != 0 && strcmp(host, "objects.githubusercontent.com") != 0 &&
        strcmp(host, "release-assets.githubusercontent.com") != 0)
        return NULL; /* a redirect anywhere but GitHub is never followed */
    return slash;
}

struct Buffers
{
    char buf[BUF];
    char location[2][LOCATION];
};

/* Follows up to three redirects. The body length, or RATLS_ERR_*. */
static int fetch(Buffers *b, const char *path, int max_body, ratls_sink_t sink, void *ctx)
{
    char host[64] = "github.com";
    int rc = RATLS_ERR_HTTP;

    for (int hop = 0; hop < 4; hop++) {
        char *location = b->location[hop & 1]; /* path may point into the other one */
        rc = httpsDownload(host, path, b->buf, BUF, max_body, sink, ctx, location, LOCATION);
        if (rc != RATLS_ERR_REDIRECT)
            return rc;
        if ((path = splitUrl(location, host, sizeof(host))) == NULL)
            return RATLS_ERR_HTTP;
    }
    return rc;
}

/* ---- SHA256SUMS.txt ---- */

struct Sums
{
    char text[SUMS_MAX];
    int len;
};

static int sumsSink(void *ctx, const char *data, int len)
{
    Sums *s = static_cast<Sums *>(ctx);
    if (s->len + len >= SUMS_MAX)
        return -1;
    memcpy(s->text + s->len, data, len);
    s->len += len;
    s->text[s->len] = '\0';
    return 0;
}

static int hexVal(char c)
{
    if (c >= '0' && c <= '9')
        return c - '0';
    if (c >= 'a' && c <= 'f')
        return c - 'a' + 10;
    if (c >= 'A' && c <= 'F')
        return c - 'A' + 10;
    return -1;
}

/* "<64 hex>  <name>" lines (sha256sum's; a '*' before the name marks binary mode). ELF's hash into
   sha, and the version out of the zip's name "PS1_POPSLOADER-<version>.zip". 0 when both are found. */
static int parseSums(const char *text, unsigned char sha[32], char *version, int version_max)
{
    int haveSha = 0, haveVer = 0;

    for (const char *p = text; *p;) {
        const char *eol = strchr(p, '\n');
        int len = eol != NULL ? static_cast<int>(eol - p) : static_cast<int>(strlen(p));
        if (len > 66) {
            unsigned char hash[32];
            int ok = 1;
            for (int i = 0; i < 32 && ok; i++) {
                int hi = hexVal(p[2 * i]), lo = hexVal(p[2 * i + 1]);
                if (hi < 0 || lo < 0)
                    ok = 0;
                else
                    hash[i] = static_cast<unsigned char>(hi * 16 + lo);
            }
            const char *name = p + 64;
            while (name < p + len && (*name == ' ' || *name == '*'))
                name++;
            int n = static_cast<int>(p + len - name);
            if (n > 0 && name[n - 1] == '\r')
                n--;
            if (ok && n == 14 && !strncmp(name, "POPSLOADER.ELF", 14)) {
                memcpy(sha, hash, 32);
                haveSha = 1;
            } else if (ok && n > 19 && !strncmp(name, "PS1_POPSLOADER-", 15) && !strncmp(name + n - 4, ".zip", 4)) {
                int v = n - 19;
                if (v < version_max) {
                    int digits = 1;
                    for (int i = 0; i < v; i++)
                        if (!((name[15 + i] >= '0' && name[15 + i] <= '9') || name[15 + i] == '.'))
                            digits = 0;
                    if (digits) {
                        memcpy(version, name + 15, v);
                        version[v] = '\0';
                        haveVer = 1;
                    }
                }
            }
        }
        if (eol == NULL)
            break;
        p = eol + 1;
    }
    return haveSha && haveVer ? 0 : -1;
}

/* Dotted numbers, compared part by part: 1.4.10 > 1.4.9. */
static int versionNewer(const char *remote, const char *local)
{
    while (*remote || *local) {
        long r = 0, l = 0;
        while (*remote >= '0' && *remote <= '9')
            r = r * 10 + (*remote++ - '0');
        while (*local >= '0' && *local <= '9')
            l = l * 10 + (*local++ - '0');
        if (r != l)
            return r > l;
        if (*remote == '.')
            remote++;
        else if (*remote)
            return 0;
        if (*local == '.')
            local++;
        else if (*local)
            return 0;
    }
    return 0;
}

/* ---- the ELF ---- */

struct FileSink
{
    int fd;
    int written;
    int headLen;
    unsigned char head[4];
    mbedtls_sha256_context sha;
};

static int fileSink(void *ctx, const char *data, int len)
{
    FileSink *f = static_cast<FileSink *>(ctx);

    if (f->written == 0) { /* hold the magic until it is whole: the first piece can be short */
        int take = len < 4 - f->headLen ? len : 4 - f->headLen;
        memcpy(f->head + f->headLen, data, take);
        f->headLen += take;
        data += take;
        len -= take;
        if (f->headLen < 4)
            return 0;
        if (f->head[0] != 0x7F || f->head[1] != 'E' || f->head[2] != 'L' || f->head[3] != 'F')
            return -1; /* not an ELF: stop before writing anything */
        if (write(f->fd, f->head, 4) != 4)
            return -1;
        mbedtls_sha256_update(&f->sha, f->head, 4);
        f->written = 4;
    }
    if (len > 0) {
        if (write(f->fd, data, len) != len)
            return -1;
        mbedtls_sha256_update(&f->sha, reinterpret_cast<const unsigned char *>(data), len);
        f->written += len;
    }
    gDone = f->written;
    gTotal = raTlsBodyLength;
    return 0;
}

static void jobCheck(Buffers *b)
{
    Sums *sums = static_cast<Sums *>(malloc(sizeof(Sums)));

    if (sums == NULL) {
        gResult = UP_MEMORY;
        return;
    }
    sums->len = 0;
    sums->text[0] = '\0';
    int rc = fetch(b, "/NathanNeurotic/POPSLoader/releases/latest/download/SHA256SUMS.txt", SUMS_MAX, sumsSink, sums);
    if (rc < 0)
        gResult = toResult(rc);
    else if (parseSums(sums->text, gSha, gRemote, sizeof(gRemote)) != 0)
        gResult = UP_GITHUB;
    else
        gResult = versionNewer(gRemote, gLocal) ? UP_OK : UP_NEWEST;
    free(sums);
}

static void jobInstall(Buffers *b)
{
    FileSink f;
    unsigned char sha[32];

    gResult = UP_WRITE;
    if ((f.fd = open(gDest, O_WRONLY | O_CREAT | O_TRUNC, 0644)) < 0)
        return;
    f.written = 0;
    f.headLen = 0;
    mbedtls_sha256_init(&f.sha);
    mbedtls_sha256_starts(&f.sha, 0);
    int rc = fetch(b, "/NathanNeurotic/POPSLoader/releases/latest/download/POPSLOADER.ELF", ELF_MAX, fileSink, &f);
    int closed = close(f.fd);
    mbedtls_sha256_finish(&f.sha, sha);
    mbedtls_sha256_free(&f.sha);
    if (rc >= 0 && f.written == 0)
        rc = RATLS_ERR_SINK; /* shorter than an ELF header */
    if (rc < 0 || closed < 0) {
        gResult = rc < 0 ? (rc == RATLS_ERR_SINK && f.written == 0 && f.headLen >= 4 ? UP_VERIFY : toResult(rc)) : UP_WRITE;
        unlink(gDest);
        return;
    }
    if (memcmp(sha, gSha, sizeof(sha)) != 0) {
        unlink(gDest);
        gResult = UP_VERIFY;
        return;
    }
    gResult = UP_OK;
}

static void worker(void *)
{
    Buffers *b = static_cast<Buffers *>(malloc(sizeof(Buffers)));

    if (b == NULL) {
        gResult = UP_MEMORY;
    } else {
        gDone = gTotal = 0;
        if (gInstall)
            jobInstall(b);
        else
            jobCheck(b);
        free(b);
    }
    __sync_synchronize(); /* publish the results before the done flag */
    gState = 2;
    ExitDeleteThread();
}

static unsigned char gStack[STACK] __attribute__((aligned(16)));

/* System.updateStart("check", localVersion) or System.updateStart("install", destFile). The
   "install" job needs a "check" that found a newer release (it uses that check's SHA-256). */
extern "C" int lua_updateStart(lua_State *L)
{
    const char *job = luaL_checkstring(L, 1);
    const char *arg = luaL_checkstring(L, 2);

    if (gState == 1) {
        lua_pushboolean(L, 0);
        return 1;
    }
    gInstall = !strcmp(job, "install");
    if (gInstall) {
        if (strlen(arg) >= sizeof(gDest) || gRemote[0] == '\0')
            return luaL_error(L, "System.updateStart: no check result or path too long");
        strcpy(gDest, arg);
    } else {
        if (strlen(arg) >= sizeof(gLocal))
            return luaL_error(L, "System.updateStart: version too long");
        strcpy(gLocal, arg);
        gRemote[0] = '\0';
    }
    gState = 1;
    gResult = UP_BUSY;
    ee_thread_t t;
    memset(&t, 0, sizeof(t));
    t.func = reinterpret_cast<void *>(worker);
    t.stack = gStack;
    t.stack_size = STACK;
    t.gp_reg = &_gp;
    t.initial_priority = 40; /* the Lua thread polls below this: it keeps drawing while TLS works */
    int id = CreateThread(&t);
    if (id < 0 || StartThread(id, NULL) < 0) {
        if (id >= 0)
            DeleteThread(id);
        gState = 0;
        lua_pushboolean(L, 0);
        return 1;
    }
    lua_pushboolean(L, 1);
    return 1;
}

/* System.updateStatus() -> running (bool), result, doneBytes, totalBytes, remoteVersion */
extern "C" int lua_updateStatus(lua_State *L)
{
    int running = gState == 1;

    lua_pushboolean(L, running);
    lua_pushinteger(L, gResult);
    lua_pushinteger(L, gDone);
    lua_pushinteger(L, gTotal);
    lua_pushstring(L, running ? "" : gRemote); /* the worker writes gRemote until it finishes */
    return 5;
}

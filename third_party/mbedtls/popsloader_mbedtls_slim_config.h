/*
 * POPSLoader Korium and IncebtIon editions: the slim mbedTLS configuration for Check for Updates.
 *
 * One job: a TLS 1.2 client that fetches POPSLoader's own release files from github.com and its
 * download host, with full certificate verification against the embedded roots. It is
 * popsloader_mbedtls_config.h (the RA editions' file, unchanged) without TLS 1.3, the PSA crypto
 * layer TLS 1.3 needs, ChaCha20-Poly1305, X25519, SHA-224 and RSA-PSS: about 69 KB less code (34 KB packed).
 * TLS 1.2 with ECDHE and AES-GCM is what both hosts offer every client. RSA PKCS#1 v1.5 stays:
 * ISRG Root X1, the download host's root, is an RSA key. Client only; POPSLoader supplies the BIO,
 * the clock and the entropy (src/sources/ratls_ps2.cpp).
 */
#ifndef POPSLOADER_MBEDTLS_SLIM_CONFIG_H
#define POPSLOADER_MBEDTLS_SLIM_CONFIG_H

/* Platform: time and entropy come from POPSLoader. */
#define MBEDTLS_PLATFORM_C
#define MBEDTLS_HAVE_TIME
#define MBEDTLS_HAVE_TIME_DATE
#define MBEDTLS_PLATFORM_TIME_ALT    /* mbedtls_platform_set_time(): console RTC as UTC */
#define MBEDTLS_PLATFORM_MS_TIME_ALT /* mbedtls_ms_time() supplied by POPSLoader */
#define MBEDTLS_NO_PLATFORM_ENTROPY
#define MBEDTLS_ENTROPY_HARDWARE_ALT /* mbedtls_hardware_poll() supplied by POPSLoader */
#define MBEDTLS_ENTROPY_C
#define MBEDTLS_CTR_DRBG_C

/* TLS client, 1.2 only. */
#define MBEDTLS_SSL_TLS_C
#define MBEDTLS_SSL_CLI_C
#define MBEDTLS_SSL_PROTO_TLS1_2
#define MBEDTLS_SSL_SERVER_NAME_INDICATION
#define MBEDTLS_SSL_ENCRYPT_THEN_MAC
#define MBEDTLS_SSL_EXTENDED_MASTER_SECRET
#define MBEDTLS_KEY_EXCHANGE_ECDHE_ECDSA_ENABLED
#define MBEDTLS_KEY_EXCHANGE_ECDHE_RSA_ENABLED
#define MBEDTLS_SSL_IN_CONTENT_LEN  16384 /* a server may send full-size records */
#define MBEDTLS_SSL_OUT_CONTENT_LEN 4096  /* one GET request */

/* Ciphers and hashes. */
#define MBEDTLS_CIPHER_C
#define MBEDTLS_AES_C
#define MBEDTLS_GCM_C
#define MBEDTLS_MD_C
#define MBEDTLS_SHA256_C
#define MBEDTLS_SHA384_C
#define MBEDTLS_SHA512_C

/* Key exchange and signatures. */
#define MBEDTLS_BIGNUM_C
#define MBEDTLS_ECP_C
#define MBEDTLS_ECDH_C
#define MBEDTLS_ECDSA_C
#define MBEDTLS_ECP_DP_SECP256R1_ENABLED
#define MBEDTLS_ECP_DP_SECP384R1_ENABLED
#define MBEDTLS_ECP_NIST_OPTIM
#define MBEDTLS_RSA_C
#define MBEDTLS_PKCS1_V15

/* Certificates (DER only). */
#define MBEDTLS_ASN1_PARSE_C
#define MBEDTLS_ASN1_WRITE_C
#define MBEDTLS_OID_C
#define MBEDTLS_PK_C
#define MBEDTLS_PK_PARSE_C
#define MBEDTLS_X509_USE_C
#define MBEDTLS_X509_CRT_PARSE_C
#define MBEDTLS_X509_CHECK_KEY_USAGE
#define MBEDTLS_X509_CHECK_EXTENDED_KEY_USAGE
/* The PS2 libc defines AF_INET6 but has no inet_pton(): use mbedTLS's own
   parser for IP-address names in certificates (x509_crt.c). */
#define MBEDTLS_TEST_SW_INET_PTON

#endif /* POPSLOADER_MBEDTLS_SLIM_CONFIG_H */

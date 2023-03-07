module xxhash.binding;

import core.stdc.config;

extern (C):
@nogc:
nothrow:

enum XXHASH_H_5627135585666179 = 1;

enum XXH_VERSION_MAJOR = 0;
enum XXH_VERSION_MINOR = 8;
enum XXH_VERSION_RELEASE = 0;
enum XXH_VERSION_NUMBER = XXH_VERSION_MAJOR * 100 * 100 + XXH_VERSION_MINOR
    * 100 + XXH_VERSION_RELEASE;
uint XXH_versionNumber();

enum XXH_errorcode
{
    ok = 0,
    error = 1
}

alias XXH32_hash_t = uint;

XXH32_hash_t XXH32(const(void)* input, size_t length, XXH32_hash_t seed);

struct XXH32_state_s;
alias XXH32_state_t = XXH32_state_s;
XXH32_state_t* XXH32_createState();
XXH_errorcode XXH32_freeState(XXH32_state_t* statePtr);
void XXH32_copyState(XXH32_state_t* dst_state, const(XXH32_state_t)* src_state);

XXH_errorcode XXH32_reset(XXH32_state_t* statePtr, XXH32_hash_t seed);
XXH_errorcode XXH32_update(XXH32_state_t* statePtr, const(void)* input, size_t length);
XXH32_hash_t XXH32_digest(const(XXH32_state_t)* statePtr);

struct XXH32_canonical_t
{
    ubyte[4] digest;
}

void XXH32_canonicalFromHash(XXH32_canonical_t* dst, XXH32_hash_t hash);
XXH32_hash_t XXH32_hashFromCanonical(const(XXH32_canonical_t)* src);

alias XXH64_hash_t = c_ulong;

XXH64_hash_t XXH64(const(void)* input, size_t length, XXH64_hash_t seed);

struct XXH64_state_s;
alias XXH64_state_t = XXH64_state_s;
XXH64_state_t* XXH64_createState();
XXH_errorcode XXH64_freeState(XXH64_state_t* statePtr);
void XXH64_copyState(XXH64_state_t* dst_state, const(XXH64_state_t)* src_state);

XXH_errorcode XXH64_reset(XXH64_state_t* statePtr, XXH64_hash_t seed);
XXH_errorcode XXH64_update(XXH64_state_t* statePtr, const(void)* input, size_t length);
XXH64_hash_t XXH64_digest(const(XXH64_state_t)* statePtr);

struct XXH64_canonical_t
{
    ubyte[8] digest;
}

void XXH64_canonicalFromHash(XXH64_canonical_t* dst, XXH64_hash_t hash);
XXH64_hash_t XXH64_hashFromCanonical(const(XXH64_canonical_t)* src);

XXH64_hash_t XXH3_64bits(const(void)* data, size_t len);

XXH64_hash_t XXH3_64bits_withSeed(const(void)* data, size_t len, XXH64_hash_t seed);

enum XXH3_SECRET_SIZE_MIN = 136;
XXH64_hash_t XXH3_64bits_withSecret(const(void)* data, size_t len,
        const(void)* secret, size_t secretSize);

struct XXH3_state_s;
alias XXH3_state_t = XXH3_state_s;
XXH3_state_t* XXH3_createState();
XXH_errorcode XXH3_freeState(XXH3_state_t* statePtr);
void XXH3_copyState(XXH3_state_t* dst_state, const(XXH3_state_t)* src_state);

XXH_errorcode XXH3_64bits_reset(XXH3_state_t* statePtr);

XXH_errorcode XXH3_64bits_reset_withSeed(XXH3_state_t* statePtr, XXH64_hash_t seed);

XXH_errorcode XXH3_64bits_reset_withSecret(XXH3_state_t* statePtr,
        const(void)* secret, size_t secretSize);

XXH_errorcode XXH3_64bits_update(XXH3_state_t* statePtr, const(void)* input, size_t length);
XXH64_hash_t XXH3_64bits_digest(const(XXH3_state_t)* statePtr);

struct XXH128_hash_t
{
    XXH64_hash_t low64;
    XXH64_hash_t high64;
}

XXH128_hash_t XXH3_128bits(const(void)* data, size_t len);
XXH128_hash_t XXH3_128bits_withSeed(const(void)* data, size_t len, XXH64_hash_t seed);
XXH128_hash_t XXH3_128bits_withSecret(const(void)* data, size_t len,
        const(void)* secret, size_t secretSize);

XXH_errorcode XXH3_128bits_reset(XXH3_state_t* statePtr);
XXH_errorcode XXH3_128bits_reset_withSeed(XXH3_state_t* statePtr, XXH64_hash_t seed);
XXH_errorcode XXH3_128bits_reset_withSecret(XXH3_state_t* statePtr,
        const(void)* secret, size_t secretSize);

XXH_errorcode XXH3_128bits_update(XXH3_state_t* statePtr, const(void)* input, size_t length);
XXH128_hash_t XXH3_128bits_digest(const(XXH3_state_t)* statePtr);

int XXH128_isEqual(XXH128_hash_t h1, XXH128_hash_t h2);

int XXH128_cmp(const(void)* h128_1, const(void)* h128_2);

struct XXH128_canonical_t
{
    ubyte[16] digest;
}

void XXH128_canonicalFromHash(XXH128_canonical_t* dst, XXH128_hash_t hash);
XXH128_hash_t XXH128_hashFromCanonical(const(XXH128_canonical_t)* src);

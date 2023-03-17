ntlm_srcs = files(
    'ntlm.c',
    'ntlm.h',
    'util.c',
    'util.h',
    'unicode_builtin.c',
    'unicode_builtin.h',
    'crypt_openssl.c',
    'crypt_openssl.h',
)

ntlm_defs = [
    '-DNTLM_STATIC=1',
    '-DUNICODE_BUILTIN=1',
    '-DCRYPT_OPENSSL',
    '-DOPENSSL_API_COMPAT=0x10100000L',
]
ntlm_deps = [openssl]

ntlmclient = library(
    'ntlmclient',
    ntlm_srcs,
    dependencies: ntlm_deps,
    c_args: ntlm_defs,
    include_directories: include_directories('.')
)

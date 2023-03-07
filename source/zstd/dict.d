module zstd.dict;

import std.stdint;

import zstd.c.symbols;
import zstd.common;

/**
 * Wraps [ZSTD_CDict_s]. Resorces are managed internally and are automatically freed.
 */
class CompressionDict
{
    /**
     * Wraps [ZSTD_createCDict].
     */
    this(const void[] dictBuffer, CompressionLevel lvl)
    {
        ptr = ZSTD_createCDict(dictBuffer.ptr, dictBuffer.length, lvl);
    }

    ~this()
    {
        ZSTD_freeCDict(ptr);
    }

    /**
     * Wraps [ZSTD_getDictID_fromCDict].
     */
    uint32_t getDictID()
    {
        return ZSTD_getDictID_fromCDict(ptr);
    }

    /**
     * Wraps [ZSTD_sizeof_CDict].
     */
    size_t sizeOf()
    {
        return ZSTD_sizeof_CDict(ptr);
    }

package:
    ZSTD_CDict* ptr;
}

unittest
{
    assert(new CompressionDict(null, 1).getDictID() == 0);
}

unittest
{
    assert(new CompressionDict(null, 1).sizeOf() > 0);
}

/**
 * Wraps [ZSTD_DDict]. Resorces are managed internally and are automatically freed.
 */
class DecompressionDict
{
    /**
     * Wraps [ZSTD_createDDict].
     */
    this(const void[] dictBuffer)
    {
        ptr = ZSTD_createDDict(dictBuffer.ptr, dictBuffer.length);
    }

    ~this()
    {
        ZSTD_freeDDict(ptr);
    }

    /**
     * Wraps [ZSTD_getDictID_fromDDict].
     */
    uint32_t getDictID()
    {
        return ZSTD_getDictID_fromDDict(ptr);
    }

    /**
     * Wraps [ZSTD_sizeof_DDict].
     */
    size_t sizeOf()
    {
        return ZSTD_sizeof_DDict(ptr);
    }

package:
    ZSTD_DDict* ptr;
}

unittest
{
    assert(new DecompressionDict(null).getDictID() == 0);
}

unittest
{
    assert(new DecompressionDict(null).sizeOf() > 0);
}

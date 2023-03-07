module zstd.func;

import std.format;
import std.stdint;
import std.string;
import std.typecons : tuple, Tuple;

import zstd.c.symbols;
public import zstd.c.typedefs : Bounds,
    CompressionParameter,
    DecompressionParameter;
import zstd.common;

/**
 * Wraps [ZSTD_versionNumber].
 */
uint32_t versionNumber() @trusted
{
    return ZSTD_versionNumber();
}

unittest
{
    assert(versionNumber() > 0);
}

/**
 * Wraps [ZSTD_versionString].
 */
string versionString() @trusted
{
    return cast(string) ZSTD_versionString().fromStringz();
}

unittest
{
    assert(versionString().length > 0);
}

/**
 * Wraps [ZSTD_minCLevel].
 */
CompressionLevel minCompressionLevel()
{
    return ZSTD_minCLevel();
}

unittest
{
    assert(minCompressionLevel() < 0);
}

/**
 * Wraps [ZSTD_defaultCLevel].
 */
CompressionLevel defaultCompressionLevel() @trusted
{
    return ZSTD_defaultCLevel();
}

unittest
{
    const auto lvl = defaultCompressionLevel();
    assert(lvl >= minCompressionLevel() && lvl <= maxCompressionLevel());
}

/**
 * Wraps [ZSTD_maxCLevel].
 */
CompressionLevel maxCompressionLevel() @trusted
{
    return ZSTD_maxCLevel();
}

unittest
{
    immutable auto v150MaxLevel = 22; /* May be subject to changes. */
    assert(maxCompressionLevel() >= v150MaxLevel);
}

/**
 * Wraps [ZSTD_compress].
 */
size_t compress(void[] dst, const void[] src, CompressionLevel lvl) @trusted
{
    const auto size = ZSTD_compress(dst.ptr, dst.length, src.ptr, src.length, lvl);
    ZSTDException.throwIfError(size);
    return size;
}

unittest
{
    import std.algorithm.comparison : equal;
    import std.exception : assertNotThrown;

    ubyte[] src = [1, 2, 3];
    ubyte[] dst;
    dst.length = compressBound(src.length);
    assertNotThrown(compress(dst, src, 1));
    assert(!equal(dst, new ubyte[dst.length]));
}

/**
 * Wraps [ZSTD_decompress].
 */
size_t decompress(void[] dst, const void[] src) @trusted
{
    const auto size = ZSTD_decompress(dst.ptr, dst.length, src.ptr, src.length);
    ZSTDException.throwIfError(size);
    return size;
}

unittest
{
    import std.algorithm.comparison : equal;
    import std.exception : assertNotThrown;

    /* This is the dst of the compression test. */
    ubyte[] src = [40, 181, 47, 253, 32, 3, 25, 0, 0, 1, 2, 3];
    ubyte[] dst;
    dst.length = src.length;
    assertNotThrown(decompress(dst, src));
    assert(!equal(dst, new ubyte[dst.length]));
}

/**
 * This exception is thrown when a failure occured while reading a zstd frame.
 */
class FrameContentSizeException : ZSTDException
{
private:
    this(Kind kind, string filename = __FILE__, size_t line = __LINE__) @safe
    {
        super(kindToString(kind), filename, line);
    }

    enum Kind : uint64_t
    {
        SizeUnknown = -1,
        SizeError = -2,
    }

    static bool isError(uint64_t size) @safe
    {
        return size >= Kind.min && size <= Kind.max;
    }

    static string kindToString(Kind kind) @safe
    {
        final switch (kind)
        {
        case Kind.SizeUnknown:
            {
                return "size cannot be determined (code %d)".format(kind);
            }
        case Kind.SizeError:
            {
                return "one of the arguments is invalid (code %d)".format(kind);
            }
        }
    }

    /**
     * Convenience method to throw this exception in the event size is an error code.
     */
    static void throwIfError(uint64_t size) @safe
    {
        if (!isError(size))
        {
            return;
        }
        throw new FrameContentSizeException(cast(Kind) size);
    }
}

/**
 * Wraps [ZSTD_getFrameContentSize].
 */
uint64_t getFrameContentSize(const void[] src) @trusted
{
    const auto size = ZSTD_getFrameContentSize(src.ptr, src.length);
    FrameContentSizeException.throwIfError(size);
    return size;
}

unittest
{
    import std.exception : assertNotThrown, assertThrown;

    /* This is the dst of the compression test. */
    ubyte[] src = [40, 181, 47, 253, 32, 3, 25, 0, 0, 1, 2, 3];
    assertNotThrown(getFrameContentSize(src));
    assertThrown!FrameContentSizeException(getFrameContentSize(null));
}

/**
 * Wraps [ZSTD_findFrameCompressedSize].
 */
size_t findFrameCompressedSize(const void[] src) @trusted
{
    const auto size = ZSTD_findFrameCompressedSize(src.ptr, src.length);
    ZSTDException.throwIfError(size);
    return size;
}

unittest
{
    import std.exception : assertThrown;

    /* This is the dst of the compression test. */
    ubyte[] src = [40, 181, 47, 253, 32, 3, 25, 0, 0, 1, 2, 3];
    assert(findFrameCompressedSize(src) > 0);
    assertThrown!ZSTDException(findFrameCompressedSize(null));
}

/**
 * Wraps [ZSTD_compressBound].
 */
size_t compressBound(size_t srcSize) @trusted
{
    return ZSTD_compressBound(srcSize);
}

unittest
{
    assert(compressBound(1) > 0);
}

/**
 * Wraps [ZSTD_decompressBound].
 */
uint64_t decompressBound(const void[] src) @trusted
{
    const auto size = ZSTD_decompressBound(src.ptr, src.length);
    FrameContentSizeException.throwIfError(size);
    return size;
}

unittest
{
    import std.exception : assertThrown;

    /* This is the dst of the compression test. */
    ubyte[] src = [40, 181, 47, 253, 32, 3, 25, 0, 0, 1, 2, 3];
    assert(decompressBound(src) > 0);
    assertThrown!FrameContentSizeException(decompressBound(new ubyte[1]));
}

/**
 * Wraps [ZSTD_getDictID_fromDict].
 */
uint32_t getDictIDFromDict(const void[] dict)
{
    return ZSTD_getDictID_fromDict(dict.ptr, dict.length);
}

unittest
{
    /* Because it's an invalid dict technically. */
    assert(getDictIDFromDict(null) == 0);
}

/**
 * Wraps [ZSTD_getDictID_fromFrame].
 */
uint32_t getDictIDFromFrame(const void[] src)
{
    return ZSTD_getDictID_fromFrame(src.ptr, src.length);
}

unittest
{
    /* Because it's an invalid frame technically. */
    assert(getDictIDFromFrame(null) == 0);
}

/**
 * Wraps [ZSTD_cParam_getBounds].
 */
Bounds getBounds(CompressionParameter cp)
{
    return ZSTD_cParam_getBounds(cp);
}

unittest
{
    const auto bounds = getBounds(CompressionParameter.CompressionLevel);
    assert(bounds.lowerBound < 0);
}

/**
 * Wraps [ZSTD_dParam_getBounds].
 */
Bounds getBounds(DecompressionParameter dp)
{
    return ZSTD_dParam_getBounds(dp);
}

unittest
{
    const auto bounds = getBounds(DecompressionParameter.WindowLogMax);
    assert(bounds.lowerBound > 0);
}

/**
 * Wraps [ZSTD_isSkippableFrame].
 */
bool isSkippableFrame(const void[] buffer)
{
    return cast(bool) ZSTD_isSkippableFrame(buffer.ptr, buffer.length);
}

unittest
{
    assert(isSkippableFrame(null) == false);
}

/**
 * Wraps [ZSTD_isSkippableFrame].
 *
 * Returns: A tuple where the first element is the size of the frame,
 * and the second item is the magic variant. While the magic variant can
 * be optionally queried to [ZSTD_isSkippableFrame], here it is always returned.
 */
Tuple!(size_t, uint32_t) readSkippableFrame(void[] dst, const void[] src)
{
    uint32_t magicVariant;
    auto nBytes = ZSTD_readSkippableFrame(
        dst.ptr,
        dst.length,
        &magicVariant,
        src.ptr,
        src.length);
    ZSTDException.throwIfError(nBytes);
    return tuple(nBytes, magicVariant);
}

unittest
{
    import std.exception : assertThrown;

    assertThrown!ZSTDException(readSkippableFrame(new ubyte[1], new ubyte[1]));
}

module zstd.c.typedefs;

import std.stdint;

extern (C)
{
    /**
     * Note: New strategies _might_ be added in the future.
     * Only the order (from fast to strong) is guaranteed.
     */
    enum Strategy
    {
        Fast = 1,
        DFast = 2,
        Greedy = 3,
        Lazy = 4,
        Lazy2 = 5,
        BTLazy2 = 6,
        BTOpt = 7,
        BTUltra = 8,
        BTUltra2 = 9,
    }

    enum CompressionParameter
    {
        CompressionLevel = 100,
        WindowLog = 101,
        HashLog = 102,
        ChainLog = 103,
        SearchLog = 104,
        MinMatch = 105,
        TargetLength = 106,
        Strategy = 107,

        EnableLongDistanceMatching = 160,
        LDMHashLog = 161,
        LDMMinMatch = 162,
        LDMBucketSizeLog = 163,
        LDMHashRateLog = 164,

        ContentSizeFlag = 200,
        ChecksumFlag = 201,
        DictIDFlag = 202,

        NbWorkers = 400,
        JobSize = 401,
        OverlapLog = 402,

        ExperimentalParam1 = 500,
        ExperimentalParam2 = 10,
        ExperimentalParam3 = 1000,
        ExperimentalParam4 = 1001,
        ExperimentalParam5 = 1002,
        ExperimentalParam6 = 1003,
        ExperimentalParam7 = 1004,
        ExperimentalParam8 = 1005,
        ExperimentalParam9 = 1006,
        ExperimentalParam10 = 1007,
        ExperimentalParam11 = 1008,
        ExperimentalParam12 = 1009,
        ExperimentalParam13 = 1010,
        ExperimentalParam14 = 1011,
        ExperimentalParam15 = 1012,
    }

    struct Bounds
    {
        size_t error;
        int32_t lowerBound;
        int32_t upperBound;
    }

    enum ResetDirective
    {
        Session_only = 1,
        Parameters = 2,
        SessionAndParameters = 3
    }

    enum DecompressionParameter
    {
        WindowLogMax = 100,

        ExperimentalParam1 = 1000,
        ExperimentalParam2 = 1001,
        ExperimentalParam3 = 1002,
        ExperimentalParam4 = 1003
    }

    struct InBuffer
    {
        const void* src;
        size_t size;
        size_t pos;
    }

    struct OutBuffer
    {
        void* dst;
        size_t size;
        size_t pos;
    }

    enum EndDirective
    {
        Continue = 0,
        Flush = 1,
        End = 2,
    }
}

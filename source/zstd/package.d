/**
 * This module ports the zstandard ABI to the D language.
 *
 * The content of the root module provides a thin wrapper over
 * the original zstandard ABI, so please refer to the upstream
 * [documentation](https://raw.githack.com/facebook/zstd/release/doc/zstd_manual.html)
 * to learn how to use it. Albeit being nearly identical to upstream, these bindings
 * modernize the code, so that there is no need to pass the usual (pointer,length) pair
 * when dealing with arrays, nor there is the need to check the returned value when a function
 * may error out. [ZSTDException] will be thrown in such cases.
 *
 * The [highlevel] submodule automatically performs some checks you were going to perform anyway
 * when using contexts and/or streams, and manages internal memory buffers on its own.
 * It tries to avoid memory allocations as much as possible, still the [highlevel] submodule
 * should be considered a collection of conveniences. When flexibility is a must, use the root module.
 *
 * Finally, the [c] submodule maps the C ABI 1:1. Do not use it, and if you do, you agree to deal with
 * the usual C shenanigans. It is reasonable to use it when porting a code base from C to D gradually,
 * but no more than this.
 */
module zstd;

public import zstd.common;
public import zstd.context;
public import zstd.dict;
public import zstd.func;

/* Meson doesn't automatically add a main function, unlike dub. */
version (unittest)
{
    debug (meson)
    {
        void main()
        {
        }
    }
}

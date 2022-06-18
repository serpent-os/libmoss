/* SPDX-License-Identifier: Zlib */

/**
 * moss.core.platform
 *
 * Contains platform definitions for x86_64 (AMD64), x86 (IA32) and AArch64.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.core.platform;

/**
 * Type of the platform, helps to wrap up various version defines into
 * a simpler struct.
 */
final enum PlatformType
{
    /** Fatal issue: Platform is not ported */
    Unsupported = 0,

    /** x86 with 64-bit extensions, i.e. AMD64 / IA */
    x86_64,

    /** x86, i.e. i686 */
    x86,

    /** ARMv8 64-bit */
    AArch64,
}

/**
 * We use the Platform type to wrap system features and specifics,
 * ensuring we don't need to perform lots of conditional compilation
 * which may go wrong, without tracking.
 */
struct Platform
{
    /** Primary architecture type */
    PlatformType type;

    /** Field is set to true if emul32 is supported here */
    bool emul32 = false;

    /** Constant string ID for the platform */
    const string name;
}

/**
 * Return a Platform struct for the current configuration.
 */
Platform platform() @safe @nogc nothrow
{
    version (X86_64)
    {
        /* x86_64 platform */
        return Platform(PlatformType.x86_64, true, "x86_64");
    }
    else version (X86)
    {
        /* x86 platform */
        return Platform(PlatformType.x86, false, "x86");
    }
    else version (AArch64)
    {
        /* aarch64 platform */
        return Platform(PlatformType.AArch64, true, "aarch64");
    }
    else
    {
        /* unknown/unsupported platform */
        return Platform(PlatformType.Unsupported, false, "unknown");
    }
}

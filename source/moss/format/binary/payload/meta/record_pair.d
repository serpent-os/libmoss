/*
 * This file is part of moss-format.
 *
 * Copyright © 2020-2021 Serpent OS Developers
 *
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

module moss.format.binary.payload.meta.record_pair;

public import std.stdint;
public import moss.format.binary.payload.meta.record;

/**
 * A RecordPair is used internally for encoding/decoding purposes with
 * the MetaPayload and each Record.
 */
extern (C) package struct RecordPair
{
    /**
     * Fixed tag for the Record key
     */
    RecordTag tag;

    /**
     * Fixed type for the Record value *type*
     */
    RecordTag type;

    /**
     * Anonynous union containing all potential values so
     * that we can store a RecordPair in memory with its
     * associated value
     */
    union
    {
        uint8_t val_u8;
        uint16_t val_u16;
        uint32_t val_u32;
        uint64_t val_u64;
        int8_t val_i8;
        int16_t val_i16;
        int32_t val_i32;
        int64_t val_i64;
        string val_string;
    };
}

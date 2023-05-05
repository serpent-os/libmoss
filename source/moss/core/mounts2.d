/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.core.mounts
 *
 * Mount specific functionality for moss.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */
module moss.core.mounts2;

import moss.core.c.mounts;

struct FSConfigValue
{
    FSCONFIG type;
    void* value;
}

struct FSMount
{
    string filesystem;
    string target;
    FSConfigValue[string] config;
    MS mountFlags;

    void open()
    {
        this.pid = fsopen(filesystem);
    }

    void configure()
    {
        foreach (key, val; this.config)
        {
            fsconfig(this.fd, val.type, key, val.value);
        }
    }

private:
    int pid;
    int mountPID;
}

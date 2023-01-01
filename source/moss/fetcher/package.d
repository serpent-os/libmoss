/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.fetcher
 *
 * Module namespace imports for the threaded moss fetch functionality.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.fetcher;

public import moss.fetcher.controller;

public import moss.core.fetchcontext : Fetchable;
public import std.typecons : Nullable;

/**
 * Internally we handle work allocation so must know if the work is no
 * longer available.
 */
package alias NullableFetchable = Nullable!(Fetchable, Fetchable.init);

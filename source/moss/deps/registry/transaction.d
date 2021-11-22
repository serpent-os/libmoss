/*
 * This file is part of moss-deps.
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

module moss.deps.registry.transaction;

public import moss.deps.registry.item;

/**
 * A Transaction is created by the RegistryManager to track the changes needed
 * to go from one state to another. Stricly speaking moss only requires the
 * knowledge of *fully applied state*, however users are interested in mutations
 * and it helps us to ensure no name duplication across IDs.
 */
public final class Transaction
{

    @disable this();

    /**
     * Construct a new Transaction object with the input base state
     */
    this(RegistryItem[] baseState)
    {
        this.baseState = baseState;
        installPackages(baseState);
    }

    /**
     * Compute the final state. This is needed by moss to know what selections
     * form the new state to apply it.
     */
    RegistryItem[] finalState() @safe
    {
        return null;
    }

    /**
     * TODO: Make this install packages!
     */
    void installPackages(in RegistryItem[] items)
    {
    }

    /**
     * TODO: Make this remove packages!
     */
    void removePackages(in RegistryItem[] items)
    {

    }

private:

    string[] added;
    string[] removed;
    RegistryItem[] baseState;
}

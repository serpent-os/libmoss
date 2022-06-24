/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.source.upstream_definition
 *
 * Defines supported upstream types.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.format.source.upstream_definition;

public import moss.format.source.schema;

/**
 * Currently supported upstream types
 */
enum UpstreamType
{
    Plain = 0,
    Git,
}

/**
 * A Plain Upstream is a simple URI, such as a tarball.
 * By default a plain upstream is unpacked and retains the
 * same path as the URI dictates.
 */
struct PlainUpstreamDefinition
{
    /** Checksum for the origin */
    @YamlSchema("hash", true) string hash;

    /** New name for the source in case of conflicts */
    @YamlSchema("rename") string rename = null;

    /** Number of directories to strip from tarball */
    @YamlSchema("stripdirs") string stripdirs = "0";

    /** Whether to automatically unpack the source. */
    @YamlSchema("unpack") bool unpack = true;

    /** Where to extract source file to */
    @YamlSchema("unpackdir") string unpackdir = ".";
}

/**
 * A Git upstream points to a remote git repository, which
 * by default will attempt a shallow clone.
 */
struct GitUpstreamDefinition
{
    /** The ref to clone (i.e. branch, commit) */
    @YamlSchema("ref", true) string refID;

    /** Directory to clone the git source to */
    @YamlSchema("clonedir") string clonedir;
}

/**
 * UpstreamDefinition is a tagged union making it easier to manage
 * various upstream specific properties.
 */
struct UpstreamDefinition
{
    /**
     * Set to the relevant _type_ of upstream, i.e. git, plain, etc.
     */
    UpstreamType type = UpstreamType.Plain;

    /** Origin URI, set from the YAML key automatically */
    string uri;

    union
    {
        /** Plain upstream within the union */
        PlainUpstreamDefinition plain;

        /** Git upstream within the union */
        GitUpstreamDefinition git;
    }
}

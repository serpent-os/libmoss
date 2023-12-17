/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.source.spec
 *
 * Defines the notion of a Spec, which is the parsed, in-memory representation
 * of a "stone.yml" package recipe along with the steps necessary for realising
 * a binary moss .stone package.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.format.source.spec;

public import std.stdint;
public import std.stdio : File;
public import moss.format.source.build_definition;
public import moss.format.source.build_options;
public import moss.format.source.package_definition;
public import moss.format.source.path_definition;
public import moss.format.source.schema;
public import moss.format.source.source_definition;
public import moss.format.source.upstream_definition;

import dyaml;
import moss.format.source.yml_helper;
import moss.format.source.script;
import std.conv : to;
import std.exception : enforce;
import std.experimental.logger;
import std.format : format;

/**
 * A Spec is a stone specification file. It is used to parse a "stone.yml"
 * formatted file with the relevant meta-data and steps to produce a binary
 * package.
 */
struct Spec
{

public:

    /**
     * Source definition
     */
    SourceDefinition source;

    /**
     * Root context build steps
     */
    BuildDefinition rootBuild;

    /**
     * Build options
     */
    BuildOptions options;

    /**
     * Profile specific build steps
     */
    BuildDefinition[string] profileBuilds;

    /**
     * Root context package definition
     */
    PackageDefinition rootPackage;

    /**
     * Per package definitions
     */
    PackageDefinition[string] subPackages;

    /**
     * Set of upstream definitions
     */
    UpstreamDefinition[string] upstreams;

    /**
     * Architectures supported within the build
     */
    string[] architectures;

    /**
     * Construct a Spec from the given file
     */
    this(File _file) @safe
    {
        this._file = _file;
    }

    ~this()
    {
        if (_file.isOpen())
        {
            _file.close();
        }
    }

    /**
     * Attempt to parse the input file
     */
    void parse() @system
    {
        //trace(__FUNCTION__, ": ", _file);

        enforce(_file.isOpen(), "Spec.parse(): File is not open");

        auto loader = Loader.fromFile(_file);
        auto root = loader.load();

        /* Parse the rootContext source */
        debug
        {
            //trace("# spec.d/parse/parseSection(root, source)");
        }
        parseSection(root, source);
        debug
        {
            //trace("# spec.d/parse/parseSection(root, rootBuild)");
        }
        parseSection(root, rootBuild);
        debug
        {
            //trace("# spec.d/parse/parseSection(root, rootPackage)");
        }
        parseSection(root, rootPackage);
        debug
        {
            //trace("# spec.d/parse/parseSection(root, options)");
        }
        parseSection(root, options);

        debug
        {
            //trace("# spec.d/parse/parsePackages(root)");
        }
        parsePackages(root);
        rootPackage.name = source.name;
        debug
        {
            //trace("# spec.d/parse/parseBuilds(root)");
        }
        parseBuilds(root);
        debug
        {
            //trace("# spec.d/parse/parseUpstreams(root)");
        }
        parseUpstreams(root);
        debug
        {
            //trace("# spec.d/parse/parseArchitectures(root)");
        }
        parseArchitectures(root);
        debug
        {
            //trace("# spec.d/parse/parseTuningOptions(root)");
        }
        parseTuningOptions(root);

        /* Used for expansion when requested */
        _sbuilder = ScriptBuilder();

        _sbuilder.addDefinition("name", source.name);
        _sbuilder.addDefinition("version", source.versionIdentifier);
        _sbuilder.addDefinition("release", to!string(source.release));
        _sbuilder.bake();
    }

    /**
     * Return true if emul32 is enabled for the given architecture or
     * indeed all emul32 builds.
     */
    @property bool emul32() const
    {
        import moss.core : platform;

        immutable auto plat = platform();
        return plat.emul32 && (supportedArchitecture(format!"emul32/%s"(plat.name))
                || supportedArchitecture("emul32"));
    }

    /**
     * Returns true if the architecture is supported by this spec
     */
    pure bool supportedArchitecture(string architecture) const
    {
        import std.algorithm : canFind;

        return architectures.canFind(architecture);
    }

    /**
     * Expand an UpstreamDefinition with our basic known variable set
     */
    UpstreamDefinition expand(UpstreamDefinition up) @trusted
    {
        final switch (up.type)
        {
        case UpstreamType.Git:
            up.uri = _sbuilder.process(up.uri);
            up.git.refID = _sbuilder.process(up.git.refID);
            break;
        case UpstreamType.Plain:
            up.uri = _sbuilder.process(up.uri);
            break;
        }
        return up;
    }

    /**
     * Return an expanded version of the PackageDefinition
     */
    PackageDefinition expand(PackageDefinition pkd) @safe
    {
        import std.algorithm : map, uniq;
        import std.array : array;

        pkd.name = _sbuilder.process(pkd.name);
        debug
        {
            //trace(format!"# spec.d/expand: PackageDefinition %s"(pkd.name));
        }
        pkd.summary = _sbuilder.process(pkd.summary);
        pkd.description = _sbuilder.process(pkd.description);
        pkd.runtimeDependencies = pkd.runtimeDependencies.map!((r) => _sbuilder.process(r))
            .uniq.array;
        pkd.conflicts = pkd.conflicts.map!((r) => _sbuilder.process(r)).uniq.array;
        /* this expands the raw paths, but doesn't touch the type information */
        foreach (pd; pkd.paths)
        {
            pd.path = _sbuilder.process(pd.path);
        }
        debug
        {
            //trace(format!"## Expanded pkd.paths:\n%s"(pkd.paths));
        }
        return pkd;
    }

private:

    /**
     * Parse all tuning options
     */
    void parseTuningOptions(ref Node node)
    {
        if (!node.containsKey("tuning"))
        {
            return;
        }

        Node root = node["tuning"];
        enforce(root.nodeID == NodeID.sequence,
                "LINT: parseTuningOptions(): tuning key should be a sequence of tuning options");

        /* Step through all items in root */
        foreach (ref Node k; root)
        {
            TuningSelection sel;

            if (k.nodeID == NodeID.scalar)
            {
                sel.type = TuningSelectionType.Enable;
                sel.name = k.as!string;
            }
            else if (k.nodeID == NodeID.mapping)
            {
                auto keys = k.mappingKeys;
                auto vals = k.mappingValues;
                enforce(keys.length == 1,
                        "LINT: parseTuningOptions(): Each tuning option has 1 key only");
                enforce(vals.length == 1,
                        "LINT: parseTuningOptions(): Each tuning option has 1 value only");

                auto name = keys[0].as!string;
                enforce(vals[0].nodeID == NodeID.scalar,
                        "LINT: parseTuningOptions(): Each tuning option must have 1 scalar value");
                const auto val = vals[0];
                try
                {
                    const auto bval = val.as!bool;
                    if (bval)
                    {
                        sel.type = TuningSelectionType.Enable;
                    }
                    else
                    {
                        sel.type = TuningSelectionType.Disable;
                    }
                }
                catch (Exception ex)
                {
                    sel.type = TuningSelectionType.Config;
                    sel.configValue = val.as!string;
                }
                sel.name = name;
            }
            else
            {
                enforce(0, "LINT: parseTuningOptions(): Unsupported value in tuning");
            }

            options.tuneSelections ~= sel;
        }
    }

    /**
     * Find all PackageDefinition instances and set them up
     */
    void parsePackages(ref Node node)
    {
        if (!node.containsKey("packages"))
        {
            debug
            {
                //trace("## spec.d/parsePackages: No 'packages' key found for node: ", node);
            }
            return;
        }

        Node root = node["packages"];
        enforce(root.nodeID == NodeID.sequence,
                "LINT: parsePackages(): packages key should be a sequence of package definitions");

        /* Step through all items in root */
        foreach (ref Node k; root)
        {
            assert(k.nodeID == NodeID.mapping,
                    "LINT: parsePackages(): Each item in packages must be a mapping");
            foreach (ref Node c, ref Node v; k)
            {
                PackageDefinition pkd;
                auto name = c.as!string;
                debug
                {
                    //trace(format!"## spec.d/parse/parsePackages: %s"(name));
                }
                parseSection(v, pkd);
                if (v.containsKey("paths"))
                {
                    parsePaths(v["paths"], pkd);
                }
                pkd.name = name;
                subPackages[name] = pkd;
            }
        }
    }

    /**
     * Find all PathDefinition instances and set them up
     */
    void parsePaths(ref Node paths, ref PackageDefinition pkd)
    {
        import std.algorithm.searching : canFind;
        import std.array : split;
        import std.string : strip;

        /* It is an error if a subpackage does not have a paths key! */
        if (paths.length == 0)
        {
            debug
            {
                //trace("### spec.d/parse/parsePackages/parsePaths: paths.length == 0, no paths to parse.");
            }
            return;
        }

        debug
        {
            //trace("### spec.d/parse/parsePackages/parsePaths: ");
        }
        foreach (Node path; paths)
        {
            enforce(path.nodeID == NodeID.scalar || path.nodeID == NodeID.mapping,
                    "LINT: parsePaths(): path '%s' is improperly formatted. The format is '- <path> : <type>'");

            PathDefinition pd;
            /* scalar path, which is of implicit type "any" */
            if (path.nodeID == NodeID.scalar)
            {
                pd = PathDefinition(path.as!string);
                debug
                {
                    //trace(format!"    '- PathDefinition('%s')"(pd));
                }
                pkd.paths ~= pd;
                continue;
            }
            else /* (path.nodeID == NodeID.mapping) */
            {
                auto keys = path.mappingKeys;
                auto vals = path.mappingValues;

                enforce(keys.length == 1, "LINT: parsePaths(): Each item in paths must have 1 key");
                enforce(vals.length == 1,
                        "LINT: parsePaths(): Each item in paths must have 1 value");

                Node _path = keys[0];
                Node _type = vals[0];

                pd = PathDefinition(_path.as!string, _type.as!string);
                debug
                {
                    //trace(format!"    '- PathDefinition('%s')"(pd));
                }
                pkd.paths ~= pd;
            }
        }
    }

    void parseArchitectures(ref Node node)
    {
        if (!node.containsKey("architectures"))
        {
            import moss.core.platform : platform;

            auto plat = platform();
            auto emul32name = "emul32/" ~ plat.name;

            /* If "emul32" is enabled, add the emul32 architecture */
            if (node.containsKey("emul32"))
            {
                Node emul32n = node["emul32"];
                enforce(emul32n.nodeID == NodeID.scalar,
                        "LINT: parseArchitectures(): emul32 must be a boolean scalar value");

                /* Enable the host architecture + emul32 */
                if (emul32n.as!bool == true)
                {
                    architectures ~= emul32name;
                }
            }

            /* Add native architecture */
            architectures ~= plat.name;
            return;
        }

        /* Fine grained control, requiring "emul32/x86_64", etc */
        setValueArray(node["architectures"], architectures);
    }

    /**
     * Find all BuildDefinition instances and set them up
     */
    void parseBuilds(ref Node node)
    {
        import std.string : startsWith;

        if (!node.containsKey("profiles"))
        {
            return;
        }

        Node root = node["profiles"];
        enforce(root.nodeID == NodeID.sequence,
                "LINT: parseBuilds(): profiles key should be a sequence of build definitions");

        /* Step through all items in root */
        foreach (ref Node k; root)
        {
            assert(k.nodeID == NodeID.mapping,
                    "LINT: parseBuilds(): Each item in profiles must be a mapping");
            foreach (ref Node c, ref Node v; k)
            {
                BuildDefinition bd;
                auto name = c.as!string;
                parseSection(v, bd);
                profileBuilds[name] = bd;
            }
        }

        /* Find emul32 definition if it exists */
        BuildDefinition* emul32 = null;
        if ("emul32" in profileBuilds)
        {
            emul32 = &profileBuilds["emul32"];
        }

        /* Automatically parent profiles now */
        foreach (const string k; profileBuilds.keys)
        {
            auto v = &profileBuilds[k];
            if (k.startsWith("emul32/") && emul32 !is null)
            {
                v.parent = emul32;
            }
            else
            {
                v.parent = &rootBuild;
            }
        }
    }

    /**
     * Find all UpstreamDefinition instances and set them up
     */
    void parseUpstreams(ref Node node)
    {
        import std.algorithm : startsWith;

        if (!node.containsKey("upstreams"))
        {
            return;
        }

        Node root = node["upstreams"];
        enforce(root.nodeID == NodeID.sequence,
                "LINT: parseUpstreams(): upstreams key should be a sequence of upstream definitions");

        foreach (ref Node k; root)
        {
            foreach (ref Node c, ref Node v; k)
            {
                UpstreamDefinition ups;
                ups.uri = c.as!string;

                if (ups.uri.startsWith("git|"))
                {
                    ups.uri = ups.uri[4 .. $];
                    ups.type = UpstreamType.Git;
                }

                enforce(v.nodeID == NodeID.scalar || v.nodeID == NodeID.mapping,
                        "LINT: parseUpstreams(): upstream definition should be a single value or mapping");
                final switch (ups.type)
                {
                case UpstreamType.Plain:
                    if (v.nodeID == NodeID.scalar)
                    {
                        ups.plain.hash = v.as!string;
                    }
                    else
                    {
                        parseSection(v, ups.plain);
                    }
                    break;
                case UpstreamType.Git:
                    if (v.nodeID == NodeID.scalar)
                    {
                        ups.git.refID = v.as!string;
                    }
                    else
                    {
                        parseSection(v, ups.git);
                    }
                    break;
                }

                upstreams[ups.uri] = ups;
            }
        }
    }

    File _file;
    ScriptBuilder _sbuilder;
}

/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.source.macros
 *
 * Defines how to parse various macros used in package recipes.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.format.source.macros;

public import std.stdio : File;
import dyaml;
import moss.format.source.yml_helper;
import moss.format.source.package_definition;
import moss.format.source.path_definition;
import moss.format.source.tuning_flag;
import moss.format.source.tuning_group;
import std.exception : enforce;
import std.experimental.logger;
import std.string : format;

/**
 * An Action encompasses behaviour defined in the `actions`
 * section of a macro YML file, allowing substitution to be
 * performed and automatic dependencies added to the build.
 */
struct Action
{
    /**
     * The command to run (required) when invoked
     */
    @YamlSchema("command", true, YamlType.Array, null)
    string command = null;

    /**
     * Optional list of dependencies to add to build
     */
    @YamlSchema("dependencies", false, YamlType.Array, null)
    string[] dependencies = null;
}

/**
 * A MacroFile can contain a set of macro definitions, actions and otherwise
 * to form the basis of the ScriptBuilder context. All MacroFiles are loaded
 * at builder initialisation and cached in memory.
 *
 * The root BuilderContext contains all MacroFiles in memory.
 */
struct MacroFile
{

public:

    /** A mapping of string (key) to string (value) actions */
    Action[string] actions;

    /** A mapping of string (key) to string (value) global definitions */
    string[string] definitions;

    /** A mapping of string (key) to TuningFlag combinations */
    TuningFlag[string] flags;

    /** A mapping of string (key) to TuningGroup group definitions */
    TuningGroup[string] groups;

    /** A list of packages predefined in the macros file */
    PackageDefinition[] packages;

    /** Default tuning groups to enable */
    string[] defaultGroups;

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
        enforce(_file.isOpen(), "MacroFile.parse(): File is not open");

        scope (exit)
        {
            _file.close();
        }

        auto loader = Loader.fromFile(_file);
        try
        {
            auto root = loader.load();
            debug
            {
                //trace("# macros.d/parse/parseActions(root)");
            }
            parseActions(root);
            debug
            {
                //trace("# macros.d/parse/parseDefinitions(root)");
            }
            parseDefinitions(root);
            debug
            {
                //trace("# macros.d/parse/parseFlags(root)");
            }
            parseFlags(root);
            debug
            {
                //trace("# macros.d/parse/parseTuning(root)");
            }
            parseTuning(root);
            debug
            {
                //trace("# macros.d/parse/parsePackages(root)");
            }
            parsePackages(root);
            debug
            {
                //trace("# macros.d/parse/parseDefaults(root)");
            }
            parseDefaults(root);
        }
        catch (Exception ex)
        {
            error(format!"Failed to parse: %s"(_file.name));
            throw ex;
        }
    }

private:

    /**
     * Parse all package entries
     */
    void parsePackages(ref Node root)
    {
        if (!root.containsKey("packages"))
        {
            return;
        }

        /* Grab root sequence */
        Node node = root["packages"];
        enforce(node.nodeID == NodeID.sequence,
                "LINT: parsePackages(): Expected sequence for packages");

        foreach (ref Node k; node)
        {
            enforce(k.nodeID == NodeID.mapping,
                    "LINT: parsePackages(): Each item in packages must be a mapping");

            auto keys = k.mappingKeys;
            auto vals = k.mappingValues;

            enforce(keys.length == 1,
                    "LINT: parsePackages(): Each item in packages must have 1 key");
            enforce(vals.length == 1,
                    "LINT: parsePackages(): Each item in packages must have 1 value");

            auto key = keys[0];
            Node val = vals[0];

            enforce(key.nodeID == NodeID.scalar,
                    "LINT: parsePackages(): Each item key in packages must be a scalar string");
            auto name = key.as!string;
            debug
            {
                //trace(format!"## macros.d/parse/parsePackages: %s"(name));
            }
            enforce(val.nodeID == NodeID.mapping,
                    "LINT: parsePackages(): Each item value in packages must be a mapping");

            PackageDefinition pkd;
            parseSection(val, pkd);
            pkd.name = name;

            if (val.containsKey("paths"))
            {
                parsePaths(val["paths"], pkd);
            }

            /* Merge unbaked package description */
            packages ~= pkd;
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

        if (paths.length == 0)
        {
            debug
            {
                //trace("### macros.d/parse/parsePackages/parsePaths: paths.length == 0, no paths to parse.");
            }
            return;
        }

        debug
        {
            //trace("### macros.d/parse/parsePackages/parsePaths:");
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

    /**
     * Parse all Flag types.
     */
    void parseFlags(ref Node root)
    {
        if (!root.containsKey("flags"))
        {
            return;
        }

        /* Grab root sequence */
        Node node = root["flags"];
        enforce(node.nodeID == NodeID.sequence, "LINT: parseFlags(): Expected sequence for flags");

        foreach (ref Node k; node)
        {
            assert(k.nodeID == NodeID.mapping,
                    "LINT: parseFlags(): Each item in flags must be a mapping");
            foreach (ref Node c, ref Node v; k)
            {
                enforce(v.nodeID == NodeID.mapping,
                        "LINT: parseFlags(): Expected map for each item");
                TuningFlag tf;
                auto name = c.as!string;
                debug
                {
                    //trace(format!"## TuningFlag: %s"(name));
                }
                parseSection(v, tf);
                parseSection(v, tf.root);

                /* Handle GNU key */
                if (v.containsKey("gnu"))
                {
                    Node gnu = v["gnu"];
                    enforce(gnu.nodeID == NodeID.mapping,
                            "LINT: parseFlags(): expected gnu section to be a mapping");
                    debug
                    {
                        //trace("### Toolchain: gnu");
                    }
                    parseSection(gnu, tf.gnu);
                }

                /* Handle LLVM key */
                if (v.containsKey("llvm"))
                {
                    Node llvm = v["llvm"];
                    enforce(llvm.nodeID == NodeID.mapping,
                            "LINT: parseFlags(): expected llvm section to be a mapping");
                    debug
                    {
                        //trace("### Toolchain: llvm");
                    }
                    parseSection(llvm, tf.llvm);
                }

                /* Store flags now */
                flags[name] = tf;
            }
        }
    }

    /**
     * Parse a set of actions into a usable mapping
     */
    void parseActions(ref Node root)
    {
        /* Only interested in Actions */
        if (!root.containsKey("actions"))
        {
            return;
        }

        Node node = root["actions"];
        enforce(node.nodeID == NodeID.sequence,
                "LINT: parseActions(): Expected sequence for actions");

        /**
         * Walk each node and unmarshal as Action struct
         */
        foreach (ref Node k; node)
        {
            assert(k.nodeID == NodeID.mapping,
                    "LINT: parseActions(): Each item in actions must be a mapping");
            foreach (ref Node c, ref Node v; k)
            {
                enforce(v.nodeID == NodeID.mapping,
                        "LINT: parseActions(): Expected map for each item");
                auto name = c.as!string;
                debug
                {
                    //trace(format!"## Actions: %s"(name));
                }
                Action candidateAction;
                parseSection(v, candidateAction);

                actions[name] = candidateAction;
            }
        }
    }

    void parseTuning(ref Node root)
    {
        if (!root.containsKey("tuning"))
        {
            return;
        }

        /* Grab root sequence */
        Node node = root["tuning"];
        enforce(node.nodeID == NodeID.sequence, "LINT: parseTuning(): Expected sequence for tuning");

        foreach (ref Node k; node)
        {
            assert(k.nodeID == NodeID.mapping,
                    "LINT: parseTuning(): Each item in tuning must be a mapping");
            foreach (ref Node c, ref Node v; k)
            {
                enforce(v.nodeID == NodeID.mapping,
                        "LINT: parseTuning(): Expected map for each item");
                TuningGroup group;
                auto name = c.as!string;
                debug
                {
                    //trace(format!"## TuningGroup: %s"(name));
                }
                parseSection(v, group);
                parseSection(v, group.root);

                /* Handle all options */
                if (v.containsKey("options"))
                {
                    auto options = v["options"];
                    enforce(options.nodeID == NodeID.sequence,
                            "LINT: parseTuning(): Expected sequence for options");

                    /* Grab each option key now */
                    foreach (ref Node kk; options)
                    {
                        assert(kk.nodeID == NodeID.mapping,
                                "LINT: parseTuning(): Each item in tuning options must be a mapping");
                        foreach (ref Node cc, ref Node vv; kk)
                        {
                            TuningOption to;

                            /* Disallow duplicates */
                            auto childName = cc.as!string;
                            enforce(!(childName in group.choices),
                                    "LINT: parseTuning(): Duplicate option found in " ~ name);
                            debug
                            {
                                //trace(format!"### TuningOption: %s"(childName));
                            }
                            /* Parse the option and store it */
                            parseSection(vv, to);
                            group.choices[childName] = to;
                        }
                    }
                }

                /* If we have options, a default MUST be set */
                if (group.choices !is null && group.choices.length > 0)
                {
                    enforce(group.defaultChoice !is null,
                            "LINT: parseTuning(): default value missing for option set " ~ name);
                }
                else if (group.choices is null || group.choices.length < 1)
                {
                    enforce(group.defaultChoice is null,
                            "LINT: parseTuning(): default value unsupported for option set " ~ name);
                }
                groups[name] = group;
            }
        }
    }

    void parseDefinitions(ref Node root)
    {
        import std.string : strip, endsWith;

        if (!root.containsKey("definitions"))
        {
            return;
        }

        /* Grab root sequence */
        Node node = root["definitions"];
        enforce(node.nodeID == NodeID.sequence, "LINT: parseDefinitions(): Expected sequence");

        /* Grab each map */
        foreach (ref Node k; node)
        {
            enforce(k.nodeID == NodeID.mapping,
                    "LINT: parseDefinitions(): Expected mapping in sequence");

            auto mappingKeys = k.mappingKeys;
            auto mappingValues = k.mappingValues;

            enforce(mappingKeys.length == 1, "LINT: parseDefinitions(): Expect only ONE key");
            enforce(mappingValues.length == 1, "LINT: parseDefinitions(): Expect only ONE value");

            Node key = mappingKeys[0];
            Node val = mappingValues[0];

            enforce(key.nodeID == NodeID.scalar, "LINT: parseDefinitions(): Expected scalar key");
            enforce(val.nodeID == NodeID.scalar, "LINT: parseDefinitions(): Expected scalar key");

            auto skey = key.as!string;
            auto sval = val.as!string;

            sval = sval.strip();
            if (sval.endsWith('\n'))
            {
                sval = sval[0 .. $ - 1];
            }
            definitions[skey] = sval;
        }
    }

    /**
     * Parse the defaults (tuning group)
     */
    void parseDefaults(ref Node root)
    {
        if (!root.containsKey("defaultTuningGroups"))
        {
            return;
        }

        /* Grab root sequence */
        Node node = root["defaultTuningGroups"];
        enforce(node.nodeID == NodeID.sequence, "LINT: parseDefaults(): Expected sequence");

        /* Grab each scalar */
        foreach (ref Node k; node)
        {
            enforce(k.nodeID == NodeID.scalar, "LINT: parseDefaults(): Expected scalar in sequence");
            defaultGroups ~= k.get!string;
        }
    }

    File _file;
}

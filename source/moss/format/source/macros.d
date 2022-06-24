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
import moss.format.source.tuning_flag;
import moss.format.source.tuning_group;

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

    /** A tmapping of string (key) to TuningGroup group definitions */
    TuningGroup[string] groups;

    /** A list of packages predefined in the macros file */
    PackageDefinition[] packages;

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
        import std.exception : enforce;

        enforce(_file.isOpen(), "MacroFile.parse(): File is not open");

        scope (exit)
        {
            _file.close();
        }

        auto loader = Loader.fromFile(_file);
        try
        {
            auto root = loader.load();
            parseActions(root);
            parseDefinitions(root);
            parseFlags(root);
            parseTuning(root);
            parsePackages(root);
        }
        catch (Exception ex)
        {
            import std.stdio : stderr, writefln;

            stderr.writefln("Failed to parse: %s", _file.name);
            throw ex;
        }
    }

private:

    /**
     * Parse all package entries
     */
    void parsePackages(ref Node root)
    {
        import std.exception : enforce;

        if (!root.containsKey("packages"))
        {
            return;
        }

        /* Grab root sequence */
        Node node = root["packages"];
        enforce(node.nodeID == NodeID.sequence, "parsePackages(): Expected sequence for packages");

        foreach (ref Node k; node)
        {
            enforce(k.nodeID == NodeID.mapping, "Each item in packages must be a mapping");

            auto keys = k.mappingKeys;
            auto vals = k.mappingValues;

            enforce(keys.length == 1, "Each item in packages must have 1 key");
            enforce(vals.length == 1, "Each item in packages must have 1 value");

            auto key = keys[0];
            Node val = vals[0];

            enforce(key.nodeID == NodeID.scalar,
                    "Each item key in packages must be a scalar string");
            auto name = key.as!string;
            enforce(val.nodeID == NodeID.mapping, "Each item value in packages must be a mapping");

            PackageDefinition pd;
            parseSection(val, pd);
            pd.name = name;

            /* Merge unbaked package description */
            packages ~= pd;
        }
    }

    /**
     * Parse all Flag types.
     */
    void parseFlags(ref Node root)
    {
        import std.exception : enforce;

        if (!root.containsKey("flags"))
        {
            return;
        }

        /* Grab root sequence */
        Node node = root["flags"];
        enforce(node.nodeID == NodeID.sequence, "parseFlags(): Expected sequence for flags");

        foreach (ref Node k; node)
        {
            assert(k.nodeID == NodeID.mapping, "Each item in flags must be a mapping");
            foreach (ref Node c, ref Node v; k)
            {
                enforce(v.nodeID == NodeID.mapping, "parseFlags: Expected map for each item");
                TuningFlag tf;
                auto name = c.as!string;
                parseSection(v, tf);
                parseSection(v, tf.root);

                /* Handle GNU key */
                if (v.containsKey("gnu"))
                {
                    Node gnu = v["gnu"];
                    enforce(gnu.nodeID == NodeID.mapping,
                            "parseFlags(): expected gnu section to be a mapping");
                    parseSection(gnu, tf.gnu);
                }

                /* Handle LLVM key */
                if (v.containsKey("llvm"))
                {
                    Node llvm = v["llvm"];
                    enforce(llvm.nodeID == NodeID.mapping,
                            "parseFlags(): expected llvm section to be a mapping");
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
        import std.exception : enforce;

        /* Only interested in Actions */
        if (!root.containsKey("actions"))
        {
            return;
        }

        Node node = root["actions"];
        enforce(node.nodeID == NodeID.sequence, "parseActions(): Expected sequence for actions");

        /**
         * Walk each node and unmarshal as Action struct
         */
        foreach (ref Node k; node)
        {
            assert(k.nodeID == NodeID.mapping, "Each item in actions must be a mapping");
            foreach (ref Node c, ref Node v; k)
            {
                enforce(v.nodeID == NodeID.mapping, "parseActions: Expected map for each item");
                auto name = c.as!string;
                Action candidateAction;
                parseSection(v, candidateAction);

                actions[name] = candidateAction;
            }
        }
    }

    void parseTuning(ref Node root)
    {
        import std.exception : enforce;

        if (!root.containsKey("tuning"))
        {
            return;
        }

        /* Grab root sequence */
        Node node = root["tuning"];
        enforce(node.nodeID == NodeID.sequence, "parseTuning(): Expected sequence for tuning");

        foreach (ref Node k; node)
        {
            assert(k.nodeID == NodeID.mapping, "Each item in tuning must be a mapping");
            foreach (ref Node c, ref Node v; k)
            {
                enforce(v.nodeID == NodeID.mapping, "parseTuning: Expected map for each item");
                TuningGroup group;
                auto name = c.as!string;
                parseSection(v, group);
                parseSection(v, group.root);

                /* Handle all options */
                if (v.containsKey("options"))
                {
                    auto options = v["options"];
                    enforce(options.nodeID == NodeID.sequence,
                            "parseTuning(): Expected sequence for options");

                    /* Grab each option key now */
                    foreach (ref Node kk; options)
                    {
                        assert(kk.nodeID == NodeID.mapping,
                                "Each item in tuning options must be a mapping");
                        foreach (ref Node cc, ref Node vv; kk)
                        {
                            TuningOption to;

                            /* Disallow duplicates */
                            auto childName = cc.as!string;
                            enforce(!(childName in group.choices),
                                    "parseTuning: Duplicate option found in " ~ name);

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
                            "parseTuning: default value missing for option set " ~ name);
                }
                else if (group.choices is null || group.choices.length < 1)
                {
                    enforce(group.defaultChoice is null,
                            "parseTuning: default value unsupported for option set " ~ name);
                }
                groups[name] = group;
            }
        }
    }

    void parseDefinitions(ref Node root)
    {
        import std.exception : enforce;
        import std.string : strip, endsWith;

        if (!root.containsKey("definitions"))
        {
            return;
        }

        /* Grab root sequence */
        Node node = root["definitions"];
        enforce(node.nodeID == NodeID.sequence, "parseDefinitions(): Expected sequence");

        /* Grab each map */
        foreach (ref Node k; node)
        {
            enforce(k.nodeID == NodeID.mapping, "parseDefinitions(): Expected mapping in sequence");

            auto mappingKeys = k.mappingKeys;
            auto mappingValues = k.mappingValues;

            enforce(mappingKeys.length == 1, "parseDefinitions(): Expect only ONE key");
            enforce(mappingValues.length == 1, "parseDefinitions(): Expect only ONE value");

            Node key = mappingKeys[0];
            Node val = mappingValues[0];

            enforce(key.nodeID == NodeID.scalar, "parseDefinitions: Expected scalar key");
            enforce(val.nodeID == NodeID.scalar, "parseDefinitions: Expected scalar key");

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

    File _file;
}

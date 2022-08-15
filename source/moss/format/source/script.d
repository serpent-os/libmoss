/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.format.source.script
 *
 * Defines the notion of a ScriptBuilder, which parses and expands
 * macros to their actual values to be used in the build process.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.format.source.script;

import std.string : format, splitLines, startsWith, endsWith;
import std.exception : enforce;
import moss.format.source.package_definition;
import moss.format.source.macros : Action, MacroFile;
import moss.format.source.tuning_flag;
import moss.format.source.tuning_group;
import std.string : strip;
import std.container.rbtree;

/**
 * The private ParseContext is used by the ScriptBuilder to step
 * through scripts and replace macros with their equivalent data.
 */
static package struct ParseContext
{
    ulong macroStart;
    ulong macroEnd;
    ulong braceStart;
    ulong braceEnd;

    bool inMacro = false;
    bool hasMacro = false;

    /**
     * Reset the current context completely.
     */
    void reset() @safe @nogc nothrow
    {
        inMacro = false;
        macroStart = 0;
        macroEnd = 0;
        braceStart = 0;
        braceEnd = 0;
        hasMacro = false;
    }
}

/**
 * A ScriptBuilder must be populated for the current build context
 * completely, which means all current source information should be
 * present before baking.
 *
 * The ScriptBuilder must also be populated with system macros before
 * it is in any way usable, otherwise macro expansion is not possible.
 *
 * Once fully populated, a ScriptBuilder can replace (recursively) all
 * instances of macros + variables with their correct text, allowing
 * smart build scripts to be created.
 *
 * Each build *type* should have a ScriptBuilder baked for it, i.e.
 * for each architecture and profile.
 */
struct ScriptBuilder
{

public:

    /**
     * Add an action to the builder by its ID.
     *
     * An action starts with the % character, and is deemed an actionable
     * task, such as %configure. The text is replaced with the action
     * text and will be recursively resolved.
     */
    void addAction(in string id, in Action action) @trusted
    {
        enforce(!baked, "Cannot addAction to baked ScriptBuilder");
        mapping["%s%s".format(macroStart, id)] = action.command.strip();
        Action newAction = Action.init;
        newAction = cast(Action) action;
        actionMap[id] = newAction;
    }

    /**
     * Add a definition to the builder by its ID
     *
     * A definition is enclosed in `%(` and `)`. It provides a variable
     * that is available at "compile time", rather than run time.
     */
    void addDefinition(string id, string define) @safe
    {
        enforce(!baked, "Cannot addDefinition to baked ScriptBuilder");
        mapping["%s%s%s".format(defineStart, id, defineEnd)] = define.strip();
    }

    /**
     * Add an export to the builder by its ID.
     *
     * An export is provided for runtime, and is mapped to a pre-baked
     * value from addDefinition.
     *
     * This allows manipulating certain macros at runtime with the shell.
     */
    void addExport(string id, string altName = null) @safe
    {
        enforce(baked, "Cannot addExport to unbaked ScriptBuilder");
        auto realID = "%s%s%s".format(defineStart, id, defineEnd);
        enforce(realID in mapping, "addExport: Unknown macro: " ~ realID);
        if (altName !is null)
        {
            exports[altName.strip()] = mapping[realID.strip()];
        }
        else
        {
            exports[id.strip()] = mapping[realID.strip()];
        }
    }

    /**
     * Add a TuningFlag to the set
     */
    void addFlag(string name, TuningFlag flag) @safe
    {
        flags[name] = flag;
    }

    /**
     * Add a TuningGroup to the set
     */
    void addGroup(string name, TuningGroup group) @safe
    {
        groups[name] = group;
    }

    /**
     * Add a PackageDefinition to the group
     */
    void addPackage(string name, PackageDefinition pkg) @safe
    {
        packages[name] = pkg;
    }

    /**
     * Insert definitions, exports + actions from a macro file.
     */
    void addFrom(in MacroFile* f) @system
    {
        /* Add all definitions */
        foreach (ref k, v; f.definitions)
        {
            addDefinition(k, v);
        }

        /* Add all actions */
        foreach (ref k, v; f.actions)
        {
            addAction(k, v);
        }

        /* Add all tuning flags */
        foreach (ref k, v; f.flags)
        {
            addFlag(k, v);
        }

        /* Add all tuning groups */
        foreach (ref k, v; f.groups)
        {
            addGroup(k, cast(TuningGroup) v);
        }

        /* And now all the packages */
        foreach (ref v; f.packages)
        {
            addPackage(v.name, cast(PackageDefinition) v);
        }
    }

    /**
     * Recursively evaluate every action + definition until they
     * are completely processed and validated.
     *
     * This vastly simplifies substitution in the next set of script
     * evaluation.
     */
    void bake() @safe
    {
        if (baked)
        {
            return;
        }
        foreach (ref k, v; mapping)
        {
            mapping[k] = process(v).strip();
        }
        baked = true;
    }

    /**
     * Enable a specific tuning group
     */
    void enableGroup(string name, string value = null) @safe
    {
        import std.string : format;
        import std.algorithm : canFind, remove;

        enforce(name in groups, "enableGroup(): Unknown group: %s".format(name));

        if (!enabledGroups.canFind(name))
        {
            enabledGroups ~= name;
        }

        disabledGroups = disabledGroups.remove!((a) => a == name);

        /* Fallback to default value */
        auto group = groups[name];
        if (value is null)
        {
            value = group.defaultChoice;
        }

        /* Validate value is permitted */
        if (value !is null)
        {
            enforce(group.choices !is null && group.choices.length > 0,
                    "enableGroup(): Non-value option %s".format(name));
            enforce(value in group.choices,
                    "enableGroup(): Unknown value '%s' for '%s'".format(name, value));
            optionSets[name] = value;
        }
    }

    /**
     * Disable a specific tuning group
     */
    void disableGroup(string name) @safe
    {
        import std.string : format;
        import std.algorithm : canFind, remove;

        enforce(name in groups, "disableGroup(): Unknown group: %s".format(name));

        if (!disabledGroups.canFind(name))
        {
            disabledGroups ~= name;
        }

        enabledGroups = enabledGroups.remove!((a) => a == name);

        if (name in optionSets)
        {
            optionSets.remove(name);
        }
    }

    /**
     * Build the final TuningFlag set
     */
    TuningFlag[] buildFlags() @safe
    {
        import std.algorithm : filter, canFind, uniq, map, each;
        import std.array : array;
        import std.range : chain;

        string[] enabledFlags = [];
        string[] disabledFlags = [];

        /* Build sets of enablings */
        foreach (enabled; enabledGroups)
        {
            TuningGroup group = groups[enabled];
            TuningOption to = group.root;

            if (enabled in optionSets)
            {
                to = group.choices[optionSets[enabled]];
            }

            if (to.onEnabled !is null)
            {
                enabledFlags ~= to.onEnabled.filter!((e) => !enabledFlags.canFind(e)).array;
            }
        }

        /* Build sets of disablings */
        foreach (disabled; disabledGroups)
        {
            TuningGroup group = groups[disabled];
            if (group.root.onDisabled !is null)
            {
                disabledFlags ~= group.root.onDisabled.filter!((e) => !disabledFlags.canFind(e))
                    .array;
            }
        }

        /* Ensure all flags are known and valid */
        enabledFlags.chain(disabledFlags).each!((e) => enforce(e in flags,
                "buildFlags: Unknown flag: '%s'".format(e)));

        return enabledFlags.chain(disabledFlags).uniq.map!((n) => flags[n]).array;
    }

    /**
     * Return an automatic set of extra dependencies due to the use of macros
     */
    auto extraDependencies()
    {
        import std.algorithm : map, each;
        import std.array : array;

        auto tree = new RedBlackTree!(string, "a < b", false);
        usedMacros.map!((const s) => actionMap[s].dependencies)
            .each!((const d) { tree.insert(d); });
        return tree[].array;
    }

    /**
     * Begin tokenisation of the file, line by line
     */
    string process(const(string) input) @safe
    {
        auto context = ParseContext();
        import std.string : format;

        string lastLine;
        char lastChar = '\0';
        /// TODO: Candidate for an Appender for efficiency?
        string ret = "";

        if (input.length < 3)
        {
            return input;
        }

        void handleMacro()
        {
            if (!context.hasMacro)
            {
                return;
            }

            if (context.braceStart > 0)
            {
                enforce(context.braceEnd > context.braceStart,
                        "Macro definition MUST end with a ')'");
            }

            if (context.macroStart >= context.macroEnd)
            {
                return;
            }
            if (context.macroEnd >= input.length)
            {
                return;
            }

            /* Grab macro now */
            string macroName = lastLine[context.macroStart .. context.macroEnd + 1];

            enforce(!macroName.endsWith("%"),
                    "Legacy style macro unsupported: %s".format(macroName));
            enforce(macroName in mapping, "Unknown macro: %s".format(macroName));

            /* Store used actions */
            if (baked && context.braceEnd < 1)
            {
                usedMacros ~= macroName;
            }

            auto newval = process(mapping[macroName]);
            ret ~= newval;
            context.reset();
        }

        auto lines = input.splitLines();

        foreach (const ref line; lines)
        {
            lastLine = line;
            immutable size_t len = line.length;
            foreach (size_t i, const char c; line)
            {
                switch (c)
                {
                case '%':
                    context.inMacro = !context.inMacro;
                    if (i < len && i + 1 < len && line[i + 1] == '%')
                    {
                        ret ~= "%";
                        context.reset();
                        break;
                    }
                    if (lastChar == '%')
                    {
                        ret ~= "%";
                        context.inMacro = false;
                        context.reset();
                        break;
                    }
                    if (context.inMacro)
                    {
                        context.macroStart = i;
                    }
                    else
                    {
                        context.macroEnd = i;
                    }
                    break;
                case '(':
                    if (context.inMacro)
                    {
                        context.braceStart = i;
                    }
                    else
                    {
                        context.reset();
                        ret ~= c;
                    }
                    break;
                case ')':
                    if (context.inMacro)
                    {
                        context.braceEnd = i;
                        context.macroEnd = i;
                        context.hasMacro = true;
                        handleMacro();
                    }
                    else
                    {
                        context.reset();
                        ret ~= c;
                    }
                    break;
                default:
                    if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
                            || c == '_' || (c >= '0' && c <= '9'))
                    {
                        if (context.inMacro)
                        {
                            context.hasMacro = true;
                            context.macroEnd = i;
                        }
                        else
                        {
                            ret ~= c;
                        }
                        break;
                    }
                    else
                    {
                        if (context.hasMacro)
                        {
                            handleMacro();
                        }
                        ret ~= c;
                        context.reset();
                    }
                    break;
                }
                lastChar = c;
            }
            if (context.hasMacro)
            {
                handleMacro();
            }
            context.reset();
            if (lines.length > 1)
            {
                ret ~= "\n";
            }
        }
        if (ret.endsWith('\n'))
        {
            ret = ret[0 .. $ - 1];
        }
        return ret;
    }

private:

    char macroStart = '%';

    string defineStart = "%(";
    string defineEnd = ")";
    string commentStart = "#";

    string[string] mapping;
    string[string] exports;
    TuningFlag[string] flags;
    TuningGroup[string] groups;
    PackageDefinition[string] packages;

    string[] enabledGroups = [];
    string[] disabledGroups = [];
    string[string] optionSets;

    bool baked = false;
    string[] usedMacros;
    Action[string] actionMap;
}

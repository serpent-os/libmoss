/*
 * This file is part of moss-core.
 *
 * Copyright © 2020 Serpent OS Developers
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

module moss.core.cli;

import std.stdio;
import std.getopt;

/**
 * Generate the command name
 */
struct CommandName
{
    string name;
}

struct CommandHelp
{
    string blurb;
    string help;
}

struct CommandUsage
{
    string usage;
}

/**
 * Special UDA for any root command.
 */
struct RootCommand
{
}

/**
 * Generate a command alias
 */
struct CommandAlias
{
    string name;
}

/**
 * UDA to identify main entry point into a command
 */
struct CommandEntry
{
}

/**
 * UDA for options
 */
struct Option
{
    string name = null;
    string longName = null;
    string help = null;
}

/**
 * Generate a getopt template string at compile time to
 * have proper getopt functionality using the stdlib.
 */
static string genGetOpt(T)(string passText = "std.getopt.config.passThrough")
{
    import std.conv : text;
    import std.getopt;
    import std.traits;

    mixin("import " ~ moduleName!T ~ ";");

    auto gtext = text("auto optResult = getopt(args, " ~ passText
            ~ ", std.getopt.config.caseSensitive, std.getopt.config.bundling,");

    static foreach (member; __traits(allMembers, T))
    {
        {
            mixin("enum optionID = getUDAs!(" ~ T.stringof ~ "." ~ member ~ ", Option);");
            static if (optionID.length == 1)
            {
                static if (optionID[0].name !is null && optionID[0].longName !is null)
                {
                    gtext ~= text("\"" ~ optionID[0].name ~ "|" ~ optionID[0].longName
                            ~ "\", \"" ~ optionID[0].help ~ "\", &com." ~ member ~ ",");
                }
                else
                {
                    gtext ~= text(
                            "\"" ~ optionID[0].name ~ "\", \"" ~ optionID[0].help
                            ~ "\", &com." ~ member ~ ",");
                }
            }
        }
    }
    gtext ~= text(");");
    return gtext;
}

/**
 * Construct a new BaseCommand
 */
static T* newCommand(T : BaseCommand)()
{
    import std.traits;
    import std.string : format;
    import std.exception : enforce;
    import std.conv : text;

    /* Construct a new instance of the command */
    auto com = new T();
    /* Stash type name for ancestor retrieval */
    com.typeName = moduleName!T ~ "." ~ T.stringof;
    enum haveMember = false;

    /* Grab the primary command */
    auto udaName = getUDAs!(T, CommandName);
    static if (udaName.length == 1)
    {
        com.name = udaName[0].name;
    }

    /* Grab an alias if we have one */
    auto udaAlias = getUDAs!(T, CommandAlias);
    static if (udaAlias.length == 1)
    {
        com.shortName = udaAlias[0].name;
    }

    /* Usage text */
    auto udaUsage = getUDAs!(T, CommandUsage);
    static if (udaUsage.length == 1)
    {
        com.usage = udaUsage[0].usage;
    }

    /* Help text */
    auto udaHelp = getUDAs!(T, CommandHelp);
    static if (udaHelp.length == 1)
    {
        com.blurb = udaHelp[0].blurb;
        com.help = udaHelp[0].help;
    }

    /**
     * Generate a templated function for the given Command so that
     * getopt works
     */
    GetoptResult hgetoptHaPass(ref string[] args)
    {
        mixin(genGetOpt!T);
        return optResult;
    }

    com.hgetopt = &hgetoptHaPass;

    /* Search for the main entry point and set the function up */
    static foreach (member; __traits(allMembers, T))
    {
        mixin("import " ~ moduleName!T ~ ";");

        {
            mixin("enum entryID = getUDAs!(" ~ T.stringof ~ "." ~ member ~ ", CommandEntry);");
            static if (entryID.length == 1)
            {
                mixin("com.exec = &com." ~ member ~ ";");
            }
        }
    }

    return com;
}

/**
 * To implement a command, ensure you extend the BaseCommand
 * to satisfy storage constraints
 */
struct BaseCommand
{

public:

    /**
     * Return the fullname (required) for this command
     */
    pragma(inline, true) pure @property const string name() @safe @nogc nothrow
    {
        return _name;
    }

    /**
     * Return the short name (alias) for this command
     */
    pragma(inline, true) pure @property const string shortName() @safe @nogc nothrow
    {
        return _shortName;
    }

    /**
     * Return the type name (encoded for lookups)
     */
    pragma(inline, true) pure @property const string typeName() @safe @nogc nothrow
    {
        return _typeName;
    }

    /**
     * Return the usage text
     */
    pragma(inline, true) pure @property const string usage() @safe @nogc nothrow
    {
        return _usage;
    }

    /**
     * Return the help text
     */
    pragma(inline, true) pure @property const string help() @safe @nogc nothrow
    {
        return _help;
    }

    /**
     * Return the short blurb help
     */
    pragma(inline, true) pure @property const string blurb() @safe @nogc nothrow
    {
        return _blurb;
    }

    /**
     * Proper execution entry
     */
    int process(ref string[] argv)
    {
        return execMain(&this, argv);
    }

    /**
     * Add a command to our known commands
     */
    BaseCommand* addCommand(T : BaseCommand)()
    {
        auto com = newCommand!T();
        com.parentCommand = &this;
        commands ~= cast(BaseCommand*) com;
        return cast(BaseCommand*) com;
    }

    /**
     * Walk back the parents to find a Command matching the type
     */
    T* findAncestor(T)()
    {
        import std.exception : enforce;
        import std.traits;

        BaseCommand* pr = parentCommand;
        static auto cmpName = moduleName!T ~ "." ~ T.stringof;

        while (pr !is null)
        {
            if (pr.typeName == cmpName)
            {
                break;
            }
            pr = pr.parentCommand;
        }
        enforce(pr !is null, "Unknown ancestor: " ~ typeName);
        enforce(pr.typeName == cmpName, "Unknown ancestor: " ~ typeName);
        return cast(T*) pr;
    }

package:

    /* Executor.. */
    int delegate(ref string[] argv) exec;
    GetoptResult delegate(ref string[] args) hgetopt;

    /**
     * Set the name property
     */
    pragma(inline, true) pure @property void name(const(string) s) @safe @nogc nothrow
    {
        _name = s;
    }

    /**
     * Set the shortName property
     */
    pragma(inline, true) pure @property void shortName(const(string) s) @safe @nogc nothrow
    {
        _shortName = s;
    }

    /**
     * Set the typeName property
     */
    pragma(inline, true) pure @property void typeName(const(string) s) @safe @nogc nothrow
    {
        _typeName = s;
    }

    /**
     * Set the usage text for this command
     */
    pragma(inline, true) pure @property void usage(const(string) s) @safe @nogc nothrow
    {
        _usage = s;
    }

    /**
     * Set the help text for this command
     */
    pragma(inline, true) pure @property void help(const(string) s) @safe @nogc nothrow
    {
        _help = s;
    }

    pragma(inline, true) pure @property void blurb(const(string) s) @safe @nogc nothrow
    {
        _blurb = s;
    }

    /**
     * Find the relevant base command
     */
    BaseCommand* findCommand(string name)
    {
        foreach (ref c; commands)
        {
            if (name == c.name || name == c.shortName)
            {
                return c;
            }
        }
        return null;
    }

    BaseCommand* rootCommand()
    {
        BaseCommand* p = &this;
        while (p)
        {
            if (p.parentCommand !is null)
            {
                p = parentCommand;
            }
            else
            {
                break;
            }
        }
        return p;
    }

    /**
     * Print the usage for this command
     *
     * Used in conjunction with help to emit nice messages.
     */
    void printUsage()
    {
        writefln("usage: %s %s", fullName, usage);
    }

    /**
     * Print help for this command
     */
    void printHelp(scope BaseCommand* root)
    {
        writeln(blurb);

        if (help !is null)
        {
            writeln(help);
        }

        writeln();
        printUsage();
        writeln();
        import std.string : format;

        import std.algorithm;

        static auto pad = 4;
        auto longestName = commands.length > 0 ? commands.map!((c) => c.name.length).maxElement : 0;
        auto longestAlias = commands.length > 0
            ? commands.map!((c) => c.shortName.length).maxElement : 0;
        auto longestFlagLong = root.goptions.length > 0
            ? root.goptions.map!((o) => o.optLong.length).maxElement : 0;
        auto longestFlagShort = root.goptions.length > 0
            ? root.goptions.map!((o) => o.optShort.length).maxElement : 0;

        auto widenessFactor = [
            longestName + longestAlias, longestFlagLong + longestFlagShort
        ].maxElement;
        auto wideness = widenessFactor + pad;

        /* Helpful printer
         */
        void printItem(scope BaseCommand* c)
        {
            string itemLeft;
            if (c.shortName !is null)
            {
                itemLeft = " %s (%s)".format(c.name, c.shortName);
            }
            else
            {
                itemLeft = c.name;
            }

            writefln("    %*+s\t%s", wideness, itemLeft, c.blurb);
        }

        if (commands.length > 0)
        {
            writeln("Commands:");
            commands.each!((c) => printItem(c));
        }

        void printFlag(ref std.getopt.Option opt)
        {
            string itemLeft;
            if (opt.optShort !is null)
            {
                itemLeft ~= opt.optShort;
                if (opt.optLong !is null)
                {
                    itemLeft ~= ",";
                }
            }
            if (opt.optLong !is null)
            {
                itemLeft ~= opt.optLong;
            }
            writefln("    %*+s\t%s", wideness, itemLeft, opt.help);
        }

        static std.getopt.Option helpOption;
        helpOption.help = "Display help message";
        helpOption.optShort = "-h";
        helpOption.optLong = "--help";

        if (root.goptions.length > 0)
        {
            writeln("\nFlags:");
            root.goptions
                .filter!((o) => o.optShort != "-h")
                .each!((ref o) => printFlag(o));
            printFlag(helpOption);
        }
    }

    /**
     * Obtain the fully qualified command path by reversing the list
     * of names in this path
     */
    string fullName()
    {
        string[] names;
        BaseCommand* p = &this;
        while (p !is null)
        {
            names ~= p.name;
            p = p.parentCommand;
        }

        import std.array : join;
        import std.algorithm;

        return names.reverse.join(" ");
    }

private:

    int execMain(scope BaseCommand* root, ref string[] argv)
    {
        GetoptResult optResult;
        try
        {
            optResult = hgetopt(argv);
        }
        catch (Exception ex)
        {
            writefln("Error: %s", ex.message);
            printUsage();
            return 1;
        }
        root.goptions ~= optResult.options;
        if (optResult.helpWanted)
        {
            argv ~= "-h";
        }

        /**
         * Return true if getopt handling interrupted execution
         */
        bool getoptInterrupt()
        {
            try
            {
                getopt(argv, std.getopt.config.noPassThrough);
            }
            catch (Exception ex)
            {
                writefln("Error: %s", ex.message);
                printUsage();
                return true;
            }
            return false;
        }

        /* Ensure no flags remain */
        if (exec !is null && getoptInterrupt())
        {
            return 1;
        }

        /* Always passed, drop from processing */
        string[] origArgv = argv;
        string progName = argv[0];
        argv = argv[1 .. $];

        /* Possible option now */
        string opt = null;
        if (argv.length > 0)
        {
            opt = argv[0];
        }

        /* Find handler for the argument if we can */
        if (opt !is null && commands.length > 0)
        {
            auto cmd = findCommand(opt);
            if (cmd)
            {
                return cmd.execMain(root, argv);
            }
            if (optResult.helpWanted)
            {
                printHelp(root);
                return 0;
            }
            argv = origArgv;
            if (getoptInterrupt())
            {
                return 1;
            }
            writefln("Unknown command: %s", opt);
            printUsage();
            return 1;
        }

        /* Got so far */
        if (optResult.helpWanted)
        {
            printHelp(root);
            return 0;
        }

        /* Execute now */
        if (exec !is null)
        {
            return exec(argv);
        }
        else
        {
            writefln("Try with '-h' for help with commands + options");
            printUsage();
            return 1;
        }
    }

    string _name = null;
    string _shortName = null;
    string _typeName = null;
    string _usage = null;
    string _help = null;
    string _blurb = null;

    /* Our commands */
    BaseCommand*[] commands = [];
    BaseCommand* parentCommand = null;
    std.getopt.Option[] goptions;
}

/**
 * Return root command with processing abilities
 */
T* cliProcessor(T : BaseCommand)(ref string[] args)
{
    import std.traits;

    static assert(hasUDA!(T, RootCommand), "Cannot create cliProcessor for non-root command");
    auto com = newCommand!T;
    com.name = args[0];
    return com;
}

/**
 * The HelpCommand should be manually added by the user should they wish
 * to have such functionality.
 *
 * Notice is does access package-level members which is why it has been
 * exposed as a reusable type.
 */
@CommandName("help")
@CommandAlias("?")
@CommandUsage("[topic]")
@CommandHelp("Display help topics")
final struct HelpCommand
{
    BaseCommand pt;
    alias pt this;

    /**
     * Main entry into the help command
     */
    @CommandEntry() int run(ref string[] args)
    {
        auto root = rootCommand;
        string[] argvN = ["help"];
        argvN ~= args;
        argvN ~= "-h";
        rootCommand.goptions = [];
        return rootCommand.execMain(rootCommand, argvN);
    }
}

# Usage:
# find -name *.d -type f | xargs gawk -f serpent-style/test-commit-hook-patterns.awk
# 

# we need this for exit status
BEGIN { matches = 0; }

function error(msg) {
    print FILENAME ":" FNR ":";
    print ">" $0 "<";
    print ">> " msg "\n";
    matches += 1;
}

# Illegal patterns
# only match lines that are not commented out (we use 4 space indents)
# each line of Dlang code is matched against all the patterns below in the order listed
#
# Use a "where, what, how-to-fix (why)" format for usability

# disallow writefln run-time format strings
/^[ ]*writefln\(/ {
    error("Use writefln! instead of writefln() (compile time format string check)");
}

# disallow logger run-time format strings
/^[ ]*(log|trace|info|warning|error|critical|fatal)f/ {
    error("Use e.g. info(format! instead (compile time format string check)");
}

# buildPath has been shown to be slow
/^[ ]*buildPath/ {
    error("Use .join or joinPath instead of buildPath (speedup)");
}

# exit 1 on illegal patterns found
END {
    if (matches != 0) {
        print "Found " matches " illegal Dlang patterns.";
        exit (matches != 0)
    }
}

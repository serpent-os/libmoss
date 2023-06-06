/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.deps.dag
 *
 * Define a directed graph data structure with nodes for use in dependency
 * resolution.
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */
module moss.deps.dag;

import std.algorithm : each, find, remove, any;
import std.conv : to;
import std.range : empty, front;
import std.stdio : File, stdout;

/**
 * Validate **basic** topological sorting.
 */
unittest
{
    import std.array : array;

    static struct Pkg
    {
        string name;
        string[] dependencies;
    }

    Pkg[] pkgs = [
        Pkg("baselayout"), Pkg("glibc", ["baselayout"]),
        Pkg("nano", ["libtinfo", "ncurses", "glibc"]), Pkg("libtinfo",
                ["glibc"]), Pkg("ncurses", ["libtinfo", "glibc"]),
    ];
    auto dag = Dag!string();
    pkgs.each!(p => dag.addNode(p.name));
    pkgs.each!(p => p.dependencies.each!(d => dag.addEdge(p.name, d)));

    immutable auto expectedOrder = [
        "baselayout", "glibc", "libtinfo", "ncurses", "nano"
    ];
    const auto computedOrder = dag.topologicalSort().array;
    assert(computedOrder == expectedOrder, "Wrong ordering of dependencies");

    dag.emitGraph();
}

@safe unittest
{
    import std.algorithm : map;
    import std.array : array;

    auto dag = Dag!int();
    assert(dag.addNode(0));
    assert(dag.addNode(1));
    assert(dag.addNode(2));
    assert(dag.addNode(3));
    assert(dag.addNode(4));
    assert(dag.addNode(5));
    assert(dag.addNode(6));
    // Can't add duplicate node
    assert(!dag.addNode(0));

    assert(dag.addEdge(0, 1));
    assert(dag.addEdge(0, 2));
    assert(dag.addEdge(1, 2));
    assert(dag.addEdge(2, 3));
    assert(dag.addEdge(0, 4));
    assert(dag.addEdge(4, 5));
    assert(dag.addEdge(5, 6));
    assert(dag.addEdge(1, 6));
    // Can't add duplicate edge
    assert(!dag.addEdge(0, 1));
    // Can't add cyclic connections
    assert(!dag.addEdge(6, 1));
    assert(!dag.addEdge(0, 0));

    // Manually verified since ordering can be partially arbitrary
    assert(dag.topologicalSort().array == [3, 2, 6, 1, 5, 4, 0]);

    assert(dag.dfs(0).map!(n => n.data).array == [1, 2, 3, 6, 2, 3, 4, 5, 6]);
    assert(dag.subGraph(1).nodes.map!(n => n.data).array == [1, 2, 3, 6]);

    assert(dag.removeEdge(0, 1));
    // Can't remove edge that doesn't exist
    assert(!dag.removeEdge(0, 1));

    assert(dag.dfs(0).map!(n => n.data).array == [2, 3, 4, 5, 6]);

    assert(dag.removeNode(4));
    // Can't remove node that doesn't exist
    assert(!dag.removeNode(4));

    assert(dag.dfs(0).map!(n => n.data).array == [2, 3]);
}

/**
 * The Directed Acyclical Graoh is used for ordering information and ensuring completeness, whilst
 * detecting dependency cycles.
 */
public struct Dag(T)
{
    /**
     * Add a new node to the tree.
     *
     * Returns true if node was added.
     */
    bool addNode(T data) @safe
    {
        // Ensure node doesn't already exist
        if (!getNode(data))
        {
            nodes ~= new Node!T(data);
            return true;
        }
        else
        {
            return false;
        }
    }

    /**
     * Remove a node from the tree and remove it from all edges.
     *
     * Returns true if node existed and was removed.
     */
    bool removeNode(T data) @safe
    {
        auto old = nodes.length;

        // Remove node as edge from other nodes
        foreach (node; nodes)
        {
            node.edges = node.edges.remove!(n => n == data);
        }

        // Remove node
        nodes = nodes.remove!(n => n == data);

        return nodes.length != old;
    }

    /**
     * Add an edge between the two nodes
     *
     * Returns true if the edge was added (both nodes exist & not cyclical)
     */
    bool addEdge(T parent, T child) @safe
    {
        // Ensure parent & child aren't equal
        if (parent is child)
            return false;

        auto p = getNode(parent);
        auto c = getNode(child);
        if (p && c)
        {
            // Ensure child isn't already an edge
            if (!p.edges.find(child).empty)
                return false;

            // Check if cycle exists 
            foreach (node; DfsRange!T(c))
            {
                if (node == parent)
                {
                    return false;
                }
            }

            // Check passed, add it
            p.edges ~= c;
            return true;
        }
        else
        {
            return false;
        }
    }

    /**
     * Remove an edge between two nodes.
     *
     * Returns true if the edge was removed (both nodes exist & edge existed between them).
     */
    bool removeEdge(T parent, T child) @safe
    {
        auto p = getNode(parent);
        if (p)
        {
            auto old = p.edges.length;

            p.edges = p.edges.remove!(n => n == child);

            return p.edges.length != old;
        }
        else
        {
            return false;
        }
    }

    /**
     * Perform depth first search based topological sort.
     * 
     * Note: Order is technically reversed.
     */
    T[] topologicalSort() @safe
    {
        T[] terminated;

        auto visit(Node!T node) @safe
        {
            if (terminated.any!(d => d == node))
                return;

            DfsRange!T(node).each!(visit);

            terminated ~= node.data;
        }

        nodes.each!(visit);

        return terminated;
    }

    /**
     * Returns a new Dag that is a transposed version of this one.
     */
    Dag!T reversed() @safe
    {
        auto dag = Dag!T();

        // Add nodes
        nodes.each!(n => dag.addNode(n.data));

        // Add edges in reversed order (child -> parent)
        nodes.each!(p => p.edges.each!(c => dag.addEdge(c.data, p.data)));

        return dag;
    }

    /**
     * Return a new graph that is a subgraph starting with only the root node.
     */
    Dag!T subGraph(T root) @safe
    {
        auto dag = Dag!T();

        auto n = getNode(root);
        if (n)
        {
            // Add root
            dag.addNode(n.data);

            // Add each child and connect
            dfs(n.data).each!((c) {
                dag.addNode(c.data);
                dag.addEdge(n.data, c.data);
            });
        }

        return dag;
    }

    /**
     * Emit the graph to the given output stream.
     * Highly simplistic
     */
    void emitGraph(File output = stdout) @system
    {
        output.writeln("dag G {");
        foreach (n; nodes)
        {
            if (n.edges.empty)
            {
                output.writefln!"%s;"(n.data.to!string);
                continue;
            }
            foreach (edge; n.edges)
            {
                output.writefln!"%s -> %s;"(n.data.to!string, edge.data.to!string);
            }
        }
        output.writeln("}");
    }

private:
    DfsRange!T dfs(T root) @safe
    {
        auto r = getNode(root);
        if (r)
        {
            return DfsRange!T(r);
        }
        else
        {
            return DfsRange!T.init;
        }
    }

    Node!T getNode(T data) @safe
    {
        auto n = nodes.find(data);
        return n.empty ? null : n[0];
    }

    Node!T[] nodes;
}

private:

class Node(T)
{
    bool opEquals(T rhs) const @safe
    {
        return this.data is rhs;
    }

    this(T data)
    {
        this.data = data;
    }

    T data;
    Node!T[] edges;
}

struct DfsRange(T)
{
    Node!T front() @safe
    {
        return remaining.front;
    }

    bool empty() const @safe
    {
        return remaining.empty;
    }

    void popFront() @safe
    {
        remaining = remaining[0].edges ~ remaining[1 .. $];
    }

    this(Node!T root) @safe
    {
        this.remaining = root.edges;
    }

    Node!T[] remaining;
}

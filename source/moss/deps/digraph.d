/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.deps.digraph
 *
 * Define a directed graph data structure with vertices for use in dependency
 * resolution.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.deps.digraph;

import std.container.rbtree;
import std.exception : enforce;
import std.string : format;
import std.stdio : File, stdout;
import std.traits : Unconst;

/**
 * Validate **basic** topological sorting. We achieve this by passing a closure
 * to the depth-first search functions.
 */
unittest
{
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
    auto g = new DirectedAcyclicalGraph!string();
    foreach (p; pkgs)
    {
        g.addVertex(p.name);
        foreach (d; p.dependencies)
        {
            g.addEdge(p.name, d);
        }
    }
    immutable auto expectedOrder = [
        "baselayout", "glibc", "libtinfo", "ncurses", "nano"
    ];
    string[] computedOrder;
    g.topologicalSort((n) { computedOrder ~= n; });
    assert(computedOrder == expectedOrder, "Wrong ordering of dependencies");

    g.emitGraph();
}

/**
 * Track status of vertex visits
 */
private enum VertexStatus
{
    /**
     * Not yet discovered
     */
    Undiscovered = 0,

    /**
     * Currently within the vertex
     */
    Discovered,

    /**
     * We're done with this vertex
     */
    Explored,
}

/**
 * We use heap and stack Vertex cobjects to maintain each vertex, or node, in our
 * graph structure. Additionally each Vertex may contain a set of edges that
 * connect it to another Vertex in a single direction.
 */
private class Vertex(L)
{
    alias LabelType = Unconst!L;
    alias EdgeStorage = RedBlackTree!(LabelType, "a < b", false);

    @disable this();

    /**
     * Construct a new Labeled Vertex
     */
    this(LabelType label, bool initStore = false) @safe
    {
        this.label = label;
        if (initStore)
        {
            edges = new EdgeStorage();
        }
    }

    /**
     * Label is used for sorting the vertices and referencing it
     */
    LabelType label;

    /**
     * Store any edge references
     */
    EdgeStorage edges;

    /**
     * Return true if both vertices are equal
     */
    bool opEquals()(auto ref const Vertex!(LabelType) other) const
    {
        return other.label == this.label;
    }

    /**
     * Compare two vertices with the same type
     */
    int opCmp(ref const Vertex!(LabelType) other) const
    {
        if (this.label < other.label)
        {
            return -1;
        }
        else if (this.label > other.label)
        {
            return 1;
        }
        return 0;
    }

    /**
     * Return the hash code for the label
     */
    override ulong toHash() @safe nothrow const
    {
        return typeid(LabelType).getHash(&label);
    }

    /**
     * Visitation status of the node
     */
    VertexStatus status = VertexStatus.Undiscovered;
}

/**
 * The Directed Acyclical Graoh is used for ordering information and ensuring completeness, whilst
 * detecting dependency cycles.
 *
 * The use of DependencyGraph will be expanded upon in future to permit more
 * intelligent use than a simple Depth-First Search, so that we can support
 * multiple candidate scenarios.
 */
public final class DirectedAcyclicalGraph(B)
{
    alias LabelType = Unconst!B;
    alias VertexDescriptor = Vertex!(LabelType);
    alias VertexTree = RedBlackTree!(VertexDescriptor, "a.label < b.label", false);
    alias DfsClosure = void delegate(LabelType l) @safe;

    /**
     * Construct a new DependencyGraph
     */
    this() @safe
    {
        vertices = new VertexTree();
    }

    /**
     * Return true if we already have this node
     */
    bool hasVertex(LabelType label) @safe const
    {
        scope desc = new VertexDescriptor(label);
        return () @trusted { return !vertices.equalRange(desc).empty; }();
    }

    /**
     * Add a new node to the tree.
     */
    void addVertex(LabelType label) @safe
    {
        enforce(!hasVertex(label), "Cannot add duplicate node");
        () @trusted { vertices.insert(new VertexDescriptor(label, true)); }();
    }

    /**
     * Add an edge between the two named vertices
     */
    void addEdge(LabelType u, LabelType v) @safe
    {
        scope desc = new VertexDescriptor(u);
        auto match = () @trusted { return vertices.equalRange(desc); }();
        enforce(!match.empty, "Cannot find node: ");

        () @trusted { match.front.edges.insert(v); }();

    }

    /**
     * Perform depth first search and execute closure on encountered nodes
     */
    void topologicalSort(DfsClosure cb) @safe
    {
        enforce(cb !is null, "Cannot perform search without a closure");
        /* Discolour/reset each vertex */
        foreach (vertex; vertices)
        {
            vertex.status = VertexStatus.Undiscovered;
        }

        /* For every unvisited vertex, begin search */
        foreach (vertex; vertices)
        {
            if (vertex.status == VertexStatus.Undiscovered)
            {
                dfsVisit(vertex, cb);
            }
        }
    }

    /**
     * Emit the graph to the given output stream.
     * Highly simplistic
     */
    void emitGraph(File output = stdout) @system
    {
        import std.conv : to;

        output.writeln("digraph G {");
        foreach (v; vertices)
        {
            if (v.edges.empty)
            {
                output.writefln!"%s;"(v.label.to!string);
                continue;
            }
            foreach (edge; v.edges)
            {
                output.writefln!"%s -> %s;"(v.label.to!string, getVertex(edge).label.to!string);
            }
        }
        output.writeln("}");
    }

    /**
     * Automatically break U->V->U cycle dependencies
     */
    void breakCycles() @safe
    {
        foreach (v; vertices)
        {
            restart: foreach (edge; v.edges)
            {
                auto lookupNode = getVertex(edge);
                auto matches = () @trusted {
                    return lookupNode.edges.equalRange(v.label);
                }();
                if (!matches.empty)
                {
                    () @trusted { lookupNode.edges.removeKey(matches); }();
                    goto restart;
                }
            }
        }
    }

    /**
     * Returns a new DAG that is a transposed version of this one.
     */
    DirectedAcyclicalGraph!LabelType reversed() @safe
    {
        auto ret = new DirectedAcyclicalGraph!LabelType();

        foreach (vertex; vertices)
        {
            auto u = vertex.label;
            if (!ret.hasVertex(u))
            {
                ret.addVertex(u);
            }
            foreach (v; vertex.edges)
            {
                if (!ret.hasVertex(v))
                {
                    ret.addVertex(v);
                }
                /* Swap V with U */
                ret.addEdge(v, u);
            }
        }

        return ret;
    }

    /**
     * Return a new graph that is a subgraph starting with only the rootVertex.
     */
    DirectedAcyclicalGraph!LabelType subgraph(LabelType rootVertex) @safe
    {
        auto match = getVertex(rootVertex);
        auto dag = new DirectedAcyclicalGraph!LabelType();

        void addClone(VertexDescriptor vd)
        {
            if (!dag.hasVertex(vd.label))
            {
                dag.addVertex(vd.label);
            }
            foreach (edge; vd.edges)
            {
                addClone(getVertex(edge));
                dag.addEdge(vd.label, edge);
            }
        }

        addClone(match);

        return dag;
    }

private:

    /**
     * Helper to return a node
     */
    auto getVertex(LabelType v) @safe
    {
        scope desc = new VertexDescriptor(v);
        auto match = () @trusted { return vertices.equalRange(desc); }();
        enforce(!match.empty, "Cannot find node");
        return match.front;
    }

    /**
     * Internal depth first search visit logic
     */
    void dfsVisit(VertexDescriptor vertex, DfsClosure cb) @safe
    {
        vertex.status = VertexStatus.Discovered;
        foreach (edge; vertex.edges)
        {
            auto edgeNode = getVertex(edge);

            /* Not yet visited, go take a looksie */
            if (edgeNode.status == VertexStatus.Undiscovered)
            {
                dfsVisit(edgeNode, cb);
            }
            /* Dun dun dun, cycle. */
            else if (edgeNode.status == VertexStatus.Discovered)
            {
                auto cycleString = () @trusted {
                    return format!"Encountered dependency cycle between %s and %s"(edgeNode.label,
                            vertex.label);
                }();
                throw new Exception(cycleString);
            }
        }

        /* Done, yield the result */
        vertex.status = VertexStatus.Explored;
        cb(vertex.label);
    }

    VertexTree vertices;
}

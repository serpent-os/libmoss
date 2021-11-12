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

module moss.deps.depgraph;

import std.container.rbtree;
import std.exception : enforce;
import std.string : format;
import std.stdio : File, stdout;

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
    g.topologicalSort((n) => { computedOrder ~= n; }());
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
 * We use allocated Vertex structs to maintain each vertex, or node, in our
 * graph structure. Additionally each Vertex may contain a set of edges that
 * connect it to another Vertex in a single direction.
 */
private struct Vertex(L)
{
    alias LabelType = L;
    alias EdgeStorage = RedBlackTree!(LabelType, "a < b", false);

    /**
     * Label is used for sorting the vertices and referencing it
     */
    immutable(LabelType) label;

    /**
     * Store any edge references
     */
    EdgeStorage edges;

    /**
     * Factory to create a new Vertex
     */
    static Vertex!(LabelType)* create(in LabelType label)
    {
        return new Vertex!(LabelType)(label, new EdgeStorage());
    }

    /**
     * Factory to create a comparator Vertex
     */
    static Vertex!(LabelType) refConstruct(in LabelType label)
    {
        return Vertex!(LabelType)(label);
    }

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
    ulong toHash() @safe nothrow const
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
public final class DirectedAcyclicalGraph(L)
{
    alias LabelType = L;
    alias VertexDescriptor = Vertex!(LabelType);
    alias VertexTree = RedBlackTree!(VertexDescriptor*, "a.label < b.label", false);
    alias DfsClosure = void delegate(LabelType l);

    /**
     * Construct a new DependencyGraph
     */
    this()
    {
        vertices = new VertexTree();
    }

    /**
     * Return true if we already have this node
     */
    bool hasVertex(in LabelType label)
    {
        auto desc = VertexDescriptor.refConstruct(label);
        return !vertices.equalRange(&desc).empty;
    }

    /**
     * Add a new node to the tree.
     */
    void addVertex(in LabelType label)
    {
        enforce(!hasVertex(label), "Cannot add duplicate node");
        vertices.insert(VertexDescriptor.create(label));
    }

    /**
     * Add an edge between the two named vertices
     */
    void addEdge(in LabelType u, in LabelType v)
    {
        auto desc = VertexDescriptor.refConstruct(u);
        auto match = vertices.equalRange(&desc);
        enforce(!match.empty, "Cannot find node: %s".format(u));

        match.front.edges.insert(v);

    }

    /**
     * Perform depth first search and execute closure on encountered nodes
     */
    void topologicalSort(DfsClosure cb)
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
    void emitGraph(File output = stdout)
    {
        output.writeln("digraph G {");
        foreach (v; vertices)
        {
            foreach (edge; v.edges)
            {
                output.writefln("%s -> %s;", v.label, getVertex(edge).label);
            }
        }
        output.writeln("}");
    }

private:

    /**
     * Helper to return a node
     */
    auto getVertex(in LabelType v)
    {
        auto desc = VertexDescriptor.refConstruct(v);
        auto match = vertices.equalRange(&desc);
        enforce(!match.empty, "Cannot find node: %s".format(v));

        return match.front;
    }

    /**
     * Internal depth first search visit logic
     */
    void dfsVisit(VertexDescriptor* vertex, DfsClosure cb)
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
                throw new Exception("Encountered dependency cycle between %s and %s".format(edgeNode.label,
                        vertex.label));
            }
        }

        /* Done, yield the result */
        vertex.status = VertexStatus.Explored;
        cb(vertex.label);
    }

    VertexTree vertices;
}

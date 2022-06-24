/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.db.interfaces
 *
 * Define moss database interfaces.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.db.interfaces;
public import std.typecons : Tuple;
public import moss.db.entry : DatabaseEntry;
public import moss.core : Datum;

public alias DatabaseEntryPair = Tuple!(DatabaseEntry, "entry", Datum, "value");

/**
 * Simple iteration API for buckets.
 */
public interface IIterable
{
    /**
     * Returns true if iteration is no longer possible or has ended
     */
    bool empty();

    /**
     * Return the entry pair at the front of the iterator
     */
    DatabaseEntryPair front();

    /**
     * Pop the current entry pair from the front of the iterator and seek to the
     * next one, if possible.
     */
    void popFront();
}

/**
 * Implementations should support reading within the current scope
 */
public interface IReadable
{
    /**
     * Retrieve a single value from the current namespace/scope
     */
    Datum getDatum(scope Datum key);

    /**
     * Implementations must return a new iterator for reading through the
     * data.
     */
    @property IIterable iterator();
}

/**
 * Implementations should support writing within the current scope
 */
public interface IWritable
{
    /**
     * Set a single value within the current namespace/scope
     */
    void setDatum(scope Datum key, scope Datum value);
}

/**
 * Specify the mutability of a connection to a database
 */
public enum DatabaseMutability
{
    ReadOnly = 0,
    ReadWrite = 1,
}

/**
 * The implementation is both readable and writable.
 */
public interface IReadWritable : IReadable, IWritable
{
}

/**
 * The Database interface specifies a contract to which our database
 * implementations should implement. By default they will have to implement
 * the Readable and Writeable interfaces for basic read/write functionality
 * but may also support batch operations.
 */
public abstract class Database : IReadWritable
{

    @disable this();

    /**
     * Property constructor for IDatabase to set the pathURI and mutability
     * properties internally prior to any connection attempt.
     */
    this(const(string) pathURI, DatabaseMutability mut = DatabaseMutability.ReadOnly)
    {
        _pathURI = pathURI;
        _mutability = mut;
    }

    /**
     * Ensure closure on GC
     */
    ~this()
    {
        close();
    }

    /**
     * Return a subset of the primary database that is namespaced with
     * a special bucket prefix or key.
     */
    abstract IReadWritable bucketByDatum(scope Datum prefix);

    /**
     * The path URI is set at construction time. This property returns the current value
     */
    pure @property const(string) pathURI() @safe @nogc nothrow
    {
        return _pathURI;
    }

    /**
     * Mutability is set at construction time. This property returns the current value
     */
    pure @property DatabaseMutability mutability() @safe @nogc nothrow
    {
        return _mutability;
    }

    /**
     * Implementations should close themselves.
     */
    abstract void close();

private:

    string _pathURI = null;
    DatabaseMutability _mutability = DatabaseMutability.ReadOnly;
}

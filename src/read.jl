mutable struct ResultSet
    columns::AbstractVector{AbstractVector}
    names::Vector{Symbol}
    description::String
    metadata::String
    data::Vector{UInt8}   # backing buffer the columns read through
    mmapped::Bool         # whether `data` is a memory mapping that `close!` should release
    closed::Bool
end

"""
    featherread(source; use_mmap=true)

Read a Feather V1 file. `source` may be a filename, any `IO`, or a `Vector{UInt8}` holding
the contents of a feather file.

Columns are read lazily: they refer back into the file's bytes rather than copying. When
`source` is a filename and `use_mmap` is true (the default) those bytes are a memory
mapping, which on Windows keeps the file locked against deletion or overwriting until the
mapping is released. Call [`close!`](@ref) when done, or pass `use_mmap=false`.
"""
function featherread(source::FilenameOrIO; use_mmap::Bool=true)
    data, mmapped = loaddata(source, use_mmap=use_mmap)
    try
        ctable = getctable(data)
        ncols = length(ctable.columns)
        colnames = [Symbol(col.name) for col in ctable.columns]
        coltypes = [juliatype(col) for col in ctable.columns]
        columns = ArrowVector[constructcolumn(coltypes[i], data, ctable.columns[i].metadata, ctable.columns[i]) for i in 1:ncols]
        return ResultSet(columns, colnames, ctable.description, ctable.metadata, data, mmapped, false)
    catch
        # A malformed file can fail after the mapping exists but before there is a
        # ResultSet to close!, which would leave it locked on Windows.
        mmapped && _unmap!(data)
        rethrow()
    end
end

"""
    ClosedColumn

Stand-in left behind by [`close!`](@ref) where a column used to be, so that reading from a
closed `ResultSet` raises a clear error instead of touching an unmapped address.
"""
struct ClosedColumn <: AbstractVector{Union{}} end

_closed() = throw(ArgumentError("this column belongs to a ResultSet that has been closed with " *
                                "`close!`; re-read the file to access it again."))
Base.size(::ClosedColumn) = _closed()
Base.getindex(::ClosedColumn, ::Any) = _closed()
Base.IndexStyle(::Type{ClosedColumn}) = IndexLinear()

"""
    close!(rs::ResultSet)

Release the memory mapping backing `rs`, so that the underlying file can be deleted or
overwritten. Idempotent, and a no-op for a `ResultSet` that was not memory mapped.

Every column of `rs` is replaced with a placeholder that throws on access. Note the one
hazard this cannot guard: a column taken out of `rs` *before* the call, as in
`col = rs.columns[1]`, still refers into the mapping, and reading it afterwards is
undefined behaviour rather than an error. Drop such references before closing.
"""
function close!(rs::ResultSet)
    rs.closed && return rs
    rs.closed = true
    for i in eachindex(rs.columns)
        rs.columns[i] = ClosedColumn()
    end
    rs.mmapped && _unmap!(rs.data)
    rs.data = UInt8[]
    return rs
end

#=====================================================================================================
    new column construction stuff
=====================================================================================================#
Base.length(p::Metadata.PrimitiveArray) = p.length

startloc(p::Metadata.PrimitiveArray) = p.offset+1

ArrowCompat.nullcount(p::Metadata.PrimitiveArray) = p.null_count

function bitmasklength(p::Metadata.PrimitiveArray)
    nullcount(p) == 0 ? 0 : padding(bytesforbits(length(p)))
end

function offsetslength(p::Metadata.PrimitiveArray)
    isprimitivetype(p.dtype) ? 0 : padding((length(p)+1)*sizeof(Int32))
end

valueslength(p::Metadata.PrimitiveArray) = p.total_bytes - offsetslength(p) - bitmasklength(p)

function offsetsloc(p::Metadata.PrimitiveArray)
    if isprimitivetype(p.dtype)
        throw(ErrorException("Trying to obtain offset values for primitive array."))
    end
    startloc(p) + bitmasklength(p)
end

# override default offset type
Locate.Offsets(col::Metadata.PrimitiveArray) = Locate.Offsets{Int32}(offsetsloc(col))

Locate.length(col::Metadata.PrimitiveArray) = length(col)
Locate.values(col::Metadata.PrimitiveArray) = startloc(col) + bitmasklength(col) + offsetslength(col)
# this is only relevant for lists, values type must be UInt8
Locate.valueslength(col::Metadata.PrimitiveArray) = valueslength(col)
Locate.bitmask(col::Metadata.PrimitiveArray) = startloc(col)

function constructcolumn(::Type{T}, data::Vector{UInt8}, meta::Metadata.CategoryMetadata, col::Metadata.Column) where T
    reftype = juliatype(col.values.dtype)
    DictEncoding{T}(locate(data, reftype, col.values), locate(data, T, col.metadata.levels))
end

function constructcolumn(::Type{Union{T,Missing}}, data::Vector{UInt8}, meta::Metadata.CategoryMetadata, col::Metadata.Column) where T
    reftype = Union{juliatype(col.values.dtype),Missing}
    DictEncoding{Union{T,Missing}}(locate(data, reftype, col.values), locate(data, T, col.metadata.levels))
end

function constructcolumn(::Type{T}, data::Vector{UInt8}, meta, col::Metadata.Column) where T
    locate(data, T, col.values)
end

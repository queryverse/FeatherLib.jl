struct ResultSet
    columns::AbstractVector{AbstractVector}
    names::Vector{Symbol}
    description::String
    metadata::String
end

function featherread(filename::AbstractString; use_mmap=true)
    data = loadfile(filename, use_mmap=use_mmap)
    ctable = getctable(data)
    ncols = length(ctable.columns)
    colnames = [Symbol(col.name) for col in ctable.columns]
    coltypes = [juliatype(col) for col in ctable.columns]
    columns = ArrowVector[constructcolumn(coltypes[i], data, ctable.columns[i]) for i in 1:ncols]
    return ResultSet(columns, colnames, ctable.description, ctable.metadata)
end

#=====================================================================================================
    new column construction stuff
=====================================================================================================#
length(p::Metadata.PrimitiveArray) = p.length

startloc(p::Metadata.PrimitiveArray) = p.offset+1

nullcount(p::Metadata.PrimitiveArray) = p.null_count

function bitmasklength(p::Metadata.PrimitiveArray)
    nullcount(p) == 0 ? 0 : padding(bytesforbits(length(p)))
end

function offsetslength(p::Metadata.PrimitiveArray)
    isprimitivetype(p.dtype) ? 0 : padding((length(p)+1)*sizeof(Int32))
end

valueslength(p::Metadata.PrimitiveArray) = p.total_bytes - offsetslength(p) - bitmasklength(p)

valuesloc(p::Metadata.PrimitiveArray) = startloc(p) + bitmasklength(p) + offsetslength(p)

# only makes sense for nullable arrays
bitmaskloc(p::Metadata.PrimitiveArray) = startloc(p)

function offsetsloc(p::Metadata.PrimitiveArray)
    if isprimitivetype(p.dtype)
        throw(ErrorException("Trying to obtain offset values for primitive array."))
    end
    startloc(p) + bitmasklength(p)
end


function Arrow.Primitive(::Type{T}, data::Vector{UInt8}, p::Metadata.PrimitiveArray) where T
    Primitive{T}(data, valuesloc(p), length(p))
end
function Arrow.NullablePrimitive(::Type{T}, data::Vector{UInt8}, p::Metadata.PrimitiveArray) where T
    NullablePrimitive{T}(data, bitmaskloc(p), valuesloc(p), length(p))
end
function Arrow.List(::Type{T}, data::Vector{UInt8}, p::Metadata.PrimitiveArray) where T<:AbstractString
    q = Primitive{UInt8}(data, valuesloc(p), valueslength(p))
    List{T}(data, offsetsloc(p), length(p), q)
end
function Arrow.NullableList(::Type{T}, data::Vector{UInt8}, p::Metadata.PrimitiveArray
                           ) where T<:AbstractString
    q = Primitive{UInt8}(data, valuesloc(p), valueslength(p))
    NullableList{T}(data, bitmaskloc(p), offsetsloc(p), length(p), q)
end
function Arrow.BitPrimitive(data::Vector{UInt8}, p::Metadata.PrimitiveArray)
    BitPrimitive(data, valuesloc(p), length(p))
end
function Arrow.NullableBitPrimitive(data::Vector{UInt8}, p::Metadata.PrimitiveArray)
    NullableBitPrimitive(data, bitmaskloc(p), valuesloc(p), length(p))
end

function Arrow.DictEncoding(::Type{J}, data::Vector{UInt8}, col::Metadata.Column) where J
    refs = arrowvector(juliatype(col.values.dtype), data, col.values)
    lvls = arrowvector(J, data, col.metadata.levels)
    DictEncoding{J}(refs, lvls)
end
function Arrow.DictEncoding(::Type{Union{J,Missing}}, data::Vector{UInt8}, col::Metadata.Column) where J
    refs = arrowvector(Union{juliatype(col.values.dtype),Missing}, data, col.values)
    lvls = arrowvector(J, data, col.metadata.levels)
    DictEncoding{Union{J,Missing}}(refs, lvls)
end


arrowvector(::Type{T}, data::Vector{UInt8}, p::Metadata.PrimitiveArray) where T = Primitive(T, data, p)
function arrowvector(::Type{Union{T,Missing}}, data::Vector{UInt8}, p::Metadata.PrimitiveArray) where T
    NullablePrimitive(T, data, p)
end
function arrowvector(::Type{T}, data::Vector{UInt8}, p::Metadata.PrimitiveArray) where T<:AbstractString
    List(T, data, p)
end
function arrowvector(::Type{Union{T,Missing}}, data::Vector{UInt8}, p::Metadata.PrimitiveArray
                    ) where T<:AbstractString
    NullableList(T, data, p)
end
arrowvector(::Type{Bool}, data::Vector{UInt8}, p::Metadata.PrimitiveArray) = BitPrimitive(data, p)
function arrowvector(::Type{Union{Bool,Missing}}, data::Vector{UInt8}, p::Metadata.PrimitiveArray)
    NullableBitPrimitive(data, p)
end



function constructcolumn(::Type{T}, data::Vector{UInt8}, meta::K, col::Metadata.Column) where {T,K}
    arrowvector(T, data, col.values)
end
function constructcolumn(::Type{T}, data::Vector{UInt8}, meta::Metadata.CategoryMetadata,
                         col::Metadata.Column) where T
    DictEncoding(T, data, col)
end
function constructcolumn(::Type{T}, data::Vector{UInt8}, col::Metadata.Column) where T
    constructcolumn(T, data, col.metadata, col)
end

"""
    featherwrite(dest, columns, colnames; description="", metadata="")

Write `columns` as a Feather V1 file. `dest` may be a filename or any `IO`. `columns` is a
vector of column vectors and `colnames` a vector of `Symbol`s.
"""
function featherwrite(io::IO, columns, colnames; description::AbstractString="",
                      metadata::AbstractString="")
    ncol = length(columns)
    cols = ArrowVector[arrowformat(_first_col_convert_pass(col)) for col in columns]

    writepadded(io, FEATHER_MAGIC_BYTES)
    # Derive the row count inside the loop rather than from `columns[1]`, so that a table
    # with no columns at all still writes a valid (empty) file.
    nrows = 0
    colmetadata = Metadata.Column[]
    for i in 1:ncol
        nrows = length(cols[i])
        push!(colmetadata, writecolumn(io, string(colnames[i]), cols[i]))
    end
    ctable = Metadata.CTable(description, nrows, colmetadata, FEATHER_VERSION, metadata)
    len = writemetadata(io, ctable)
    write(io, Int32(len))  # these two writes combined are properly aligned
    write(io, FEATHER_MAGIC_BYTES)
    return io
end

function featherwrite(filename::AbstractString, columns, colnames;
                      description::AbstractString="", metadata::AbstractString="")
    open(filename, "w+") do io
        featherwrite(io, columns, colnames, description=description, metadata=metadata)
    end
    return nothing
end

# NOTE: the below is very inefficient, but we are forced to do it by the Feather format
# Feather requires us to encode any vector that doesn't have a missing value
# as a normal list.
_first_col_convert_pass(col) = col
function _first_col_convert_pass(col::AbstractVector{Union{T,Missing}}) where T
    hasmissing = findfirst(ismissing, col)
    return hasmissing == nothing ? convert(AbstractVector{T}, col) : col
end
# An all-`Missing` column has no type to write, and would otherwise fail deep inside
# `arrowformat` with an ambiguous-method error.
function _first_col_convert_pass(col::AbstractVector{Missing})
    throw(ArgumentError("the Feather format cannot represent a column of eltype `Missing`. " *
                        "Convert it to `AbstractVector{Union{T,Missing}}` for some supported " *
                        "element type `T` first."))
end

function Metadata.PrimitiveArray(A::ArrowVector{J}, off::Integer, nbytes::Integer) where J
    Metadata.PrimitiveArray(feathertype(J), Metadata.PLAIN, off, length(A), nullcount(A), nbytes)
end
function Metadata.PrimitiveArray(A::DictEncoding, off::Integer, nbytes::Integer)
    Metadata.PrimitiveArray(feathertype(eltype(references(A))), Metadata.PLAIN, off, length(A),
                            nullcount(A), nbytes)
end


writecontents(io::IO, A::Primitive) = writepadded(io, A)
writecontents(io::IO, A::NullablePrimitive) = writepadded(io, A, bitmask, values)
writecontents(io::IO, A::List) = writepadded(io, A, offsets, values)
writecontents(io::IO, A::NullableList) = writepadded(io, A, bitmask, offsets, values)
writecontents(io::IO, A::BitPrimitive) = writepadded(io, A, values)
writecontents(io::IO, A::NullableBitPrimitive) = writepadded(io, A, bitmask, values)
writecontents(io::IO, A::DictEncoding) = writecontents(io, references(A))
function writecontents(::Type{Metadata.PrimitiveArray}, io::IO, A::ArrowVector)
    a = position(io)
    writecontents(io, A)
    b = position(io)
    Metadata.PrimitiveArray(A, a, b-a)
end


function writecolumn(io::IO, name::AbstractString, A::ArrowVector{J}) where J
    vals = writecontents(Metadata.PrimitiveArray, io, A)
    Metadata.Column(String(name), vals, getmetadata(io, J, A), "")
end


function writemetadata(io::IO, ctable::Metadata.CTable)
    meta = FlatBuffers.build!(ctable)
    rng = (meta.head+1):length(meta.bytes)
    writepadded(io, view(meta.bytes, rng))
    # Report the padded length, i.e. what was actually written. The reader locates the
    # metadata by counting back from the end of the file, so the recorded length has to
    # match the bytes on disk. FlatBuffers usually emits an 8-aligned buffer and the two
    # coincide -- every file in test/data has a metadata length divisible by 8 -- but a
    # degenerate table (no columns) does not, and then the file was unreadable.
    Int32(padding(length(rng)))
end

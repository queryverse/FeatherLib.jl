function featherwrite(filename::AbstractString, columns, colnames; description::AbstractString="", metadata::AbstractString="")
    ncol = length(columns)
    nrows = length(columns[1])
    cols = ArrowVector[arrowformat(col) for col in columns]
    
    open(filename, "w+") do io
        writepadded(io, FEATHER_MAGIC_BYTES)
        colmetadata = Metadata.Column[writecolumn(io, string(colnames[i]), cols[i]) for i in 1:ncol]
        ctable = Metadata.CTable(description, nrows, colmetadata, FEATHER_VERSION, metadata)
        len = writemetadata(io, ctable)
        write(io, Int32(len))  # these two writes combined are properly aligned
        write(io, FEATHER_MAGIC_BYTES)
    end
    return nothing
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
    Int32(length(rng))
end


getoutputlength(version::Int32, x::Integer) = version < FEATHER_VERSION ? x : padding(x)

"""
    validatedata(data, src="data")

Check that `data` looks like a feather file: long enough, and carrying the `FEA1` magic
bytes at both ends. `src` names the source in error messages -- a filename when the data
came from disk, and the default otherwise.
"""
function validatedata(data::AbstractVector{UInt8}, src::AbstractString="data")
    if length(data) < MIN_FILE_LENGTH
        throw(ArgumentError("'$src' is not in feather format: total length is $(length(data)), " *
                            "the minimum is $MIN_FILE_LENGTH."))
    end
    header = data[1:4]
    footer = data[(end-3):end]
    if header ≠ FEATHER_MAGIC_BYTES || footer ≠ FEATHER_MAGIC_BYTES
        throw(ArgumentError(string("'$src' is not in feather format: header = $header, ",
            "footer = $footer.")))
    end
    data
end

# `loaddata` returns the raw bytes of a feather file, along with whether those bytes are a
# memory mapping (which only `featherread` on a filename can produce) so that `close!` knows
# whether there is anything to unmap.
loaddata(data::AbstractVector{UInt8}; use_mmap::Bool=true) = convert(Vector{UInt8}, validatedata(data)), false

loaddata(io::IO; use_mmap::Bool=true) = validatedata(read(io)), false

# Mmap attaches its unmapping finalizer to the array's underlying memory. Before Julia 1.11
# that was the array itself; from 1.11 on it is `A.ref.mem`, and finalizing the array does
# nothing at all.
function _unmap!(A::Vector{UInt8})
    @static if VERSION >= v"1.11"
        finalize(A.ref.mem)
    else
        finalize(A)
    end
    nothing
end

function loaddata(filename::AbstractString; use_mmap::Bool=true)
    isfile(filename) || throw(ArgumentError("'$filename' is not a valid file."))
    data = use_mmap ? Mmap.mmap(filename) : read(filename)
    try
        validatedata(data, filename)
    catch
        # Nothing owns the mapping yet, so release it here rather than leave the file
        # locked with no ResultSet for the caller to close!.
        use_mmap && _unmap!(data)
        rethrow()
    end
    data, use_mmap
end

function metalength(data::AbstractVector{UInt8})
    read(IOBuffer(data[(length(data)-7):(length(data)-4)]), Int32)
end

function metaposition(data::AbstractVector{UInt8}, metalen::Integer=metalength(data))
    length(data) - (metalen+7)
end

function rootposition(data::AbstractVector{UInt8}, mpos::Integer=metaposition(data))
    read(IOBuffer(data[mpos:(mpos+4)]), Int32)
end

function getctable(data::AbstractVector{UInt8})
    metapos = metaposition(data)
    rootpos = rootposition(data, metapos)
    ctable = FlatBuffers.read(Metadata.CTable, data, metapos + rootpos - 1)
    if ctable.version < FEATHER_VERSION
        @warn("This feather file is old and may not be readable.")
    end
    ctable
end

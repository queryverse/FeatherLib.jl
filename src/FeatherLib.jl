__precompile__(true)
module FeatherLib

using Arrow, Compat, Compat.Mmap
using FlatBuffers, CategoricalArrays

using Compat.Sys: iswindows

export featherread, featherwrite

if Base.VERSION < v"0.7.0-DEV.2575"
    const Dates = Base.Dates
    using Missings
    using Compat: @warn
else
    import Dates
end

const FEATHER_VERSION = 2
# wesm/feather/cpp/src/common.h
const FEATHER_MAGIC_BYTES = Vector{UInt8}(codeunits("FEA1"))
const MIN_FILE_LENGTH = 12


include("metadata.jl")  # flatbuffer defintions
include("loadfile.jl")
include("read.jl")
include("write.jl")


end # module

__precompile__(true)
module FeatherLib

using Arrow, Compat
using FlatBuffers, CategoricalArrays

using Compat.Sys: iswindows

export featherread

if Base.VERSION < v"0.7.0-DEV.2575"
    const Dates = Base.Dates
    using Missings
    using Compat: @warn
else
    import Dates
end
if Base.VERSION ≥ v"0.7.0-DEV.2009"
    using Mmap
end

import Base: length, size, read, write
import Arrow.nullcount


const FEATHER_VERSION = 2
# wesm/feather/cpp/src/common.h
const FEATHER_MAGIC_BYTES = Vector{UInt8}(codeunits("FEA1"))
const ALIGNMENT = 8


include("metadata.jl")  # flatbuffer defintions
include("utils.jl")
include("read.jl")


end # module

"""
    ArrowCompat

Vendored subset of the original Arrow.jl (v0.2.4) by ExpandingMan, which provided the
columnar array types the Feather V1 reader and writer are built on.

That package is no longer obtainable: its registry entry (UUID
69666777-d1a9-59fb-9406-91d4454c9d45) was taken over at version 0.3.0 by the unrelated
Apache Arrow.jl implementation, so `Arrow = "0.2.x"` can never be resolved alongside a
modern dependency tree again. The code is vendored here under its original MIT licence
(see LICENSE.md); the only substantive change is the port to CategoricalArrays 1.x.

This module is an implementation detail of FeatherLib. It implements the Arrow *memory*
layout only, which is what Feather V1 stores; it has nothing to do with the Arrow IPC
file format (Feather V2). Use Arrow.jl for that.
"""
module ArrowCompat

using CategoricalArrays, Dates

const BITMASK = UInt8[1, 2, 4, 8, 16, 32, 64, 128]
const ALIGNMENT = 8

abstract type ArrowVector{T} <: AbstractVector{T} end

include("utils.jl")
include("primitives.jl")
include("lists.jl")
include("arrowvectors.jl")
include("datetime.jl")
include("dictencoding.jl")
include("bitprimitives.jl")
include("locate.jl")

export ArrowVector
export padding, writepadded, bytesforbits, bitpack, bitpackpadded, unbitpack
export Primitive, NullablePrimitive, valuesbytes, bitmaskbytes, totalbytes, arrowview
export List, NullableList, offsetsbytes, offsets, getoffset
export values, bitmask, offsets, rawvalues, nullcount, isnull, arrowformat, writepadded,
    rawpadded
export Timestamp, TimeOfDay, Datestamp
export DictEncoding, referencetype, references
export BitPrimitive, NullableBitPrimitive
export Locate, locate
export unsafe_isnull, unsafe_getvalue

end  # module ArrowCompat

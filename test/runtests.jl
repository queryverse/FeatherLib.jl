using TestItemRunner

include("test_readwrite.jl")
include("test_arrow.jl")
include("test_io.jl")

@run_package_tests

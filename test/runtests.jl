using TestItemRunner

include("test_readwrite.jl")
include("test_arrow.jl")

@run_package_tests

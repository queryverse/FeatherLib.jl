@testitem "Read and write via IO" begin
    columns, names = Any[[1, 2, 3], ["x", "y", "z"]], [:a, :b]
    vals(rs) = [collect(c) for c in rs.columns]

    filename = tempname() * ".feather"
    featherwrite(filename, columns, names)
    reference = vals(featherread(filename, use_mmap=false))

    @test vals(featherread(read(filename))) == reference
    @test open(io -> vals(featherread(io)), filename) == reference

    # Writing to an IOBuffer must produce exactly the bytes a file would hold. Reading
    # those bytes back has to go through `read(io)` rather than an IOBuffer's `.data`
    # field, which is the larger backing array and carries slack past `io.size`.
    buffer = IOBuffer()
    featherwrite(buffer, columns, names)
    bytes = take!(buffer)
    @test bytes == read(filename)
    @test vals(featherread(bytes)) == reference
    @test vals(featherread(IOBuffer(bytes))) == reference

    rm(filename)
end

@testitem "close! releases the file" begin
    columns, names = Any[[1, 2, 3]], [:a]

    filename = tempname() * ".feather"
    featherwrite(filename, columns, names)
    rs = featherread(filename)              # memory mapped by default
    @test collect(rs.columns[1]) == [1, 2, 3]

    close!(rs)

    # The point of close!: on Windows a live mapping keeps the file locked, so this rm is
    # the real assertion. It also guards the Julia-version branch in `_unmap!` -- if a
    # future release moves the Mmap finalizer again, this fails loudly on Windows CI.
    @test (rm(filename); !isfile(filename))

    @test_throws ArgumentError rs.columns[1][1]
    @test close!(rs) === rs                 # idempotent

    # A ResultSet that never mapped anything has nothing to release, and closing it is
    # still safe.
    filename2 = tempname() * ".feather"
    featherwrite(filename2, columns, names)
    rs2 = featherread(filename2, use_mmap=false)
    close!(rs2)
    @test_throws ArgumentError rs2.columns[1][1]
    @test (rm(filename2); !isfile(filename2))

    # Same for a ResultSet read straight out of a byte buffer.
    filename3 = tempname() * ".feather"
    featherwrite(filename3, columns, names)
    rs3 = featherread(read(filename3))
    close!(rs3)
    @test (rm(filename3); !isfile(filename3))
end

@testitem "Malformed and degenerate files" begin
    # Shorter than MIN_FILE_LENGTH: this used to interpolate an undefined variable and
    # throw UndefVarError instead of reporting the problem.
    short = tempname() * ".feather"
    write(short, "FEA1")
    err = try; featherread(short); nothing catch e; e end
    @test err isa ArgumentError
    @test occursin(basename(short), sprint(showerror, err))
    rm(short)

    # Right length, wrong magic.
    bogus = tempname() * ".feather"
    write(bogus, repeat("!", 64))
    @test_throws ArgumentError featherread(bogus)
    rm(bogus)

    @test_throws ArgumentError featherread(tempname() * ".feather")

    # A table with no columns at all. Writing used to hit columns[1]; the file it now
    # produces has a metadata block that is not 8-aligned, which the reader could not
    # locate until writemetadata started recording the padded length.
    empty = tempname() * ".feather"
    featherwrite(empty, Any[], Symbol[])
    rs = featherread(empty)
    @test length(rs.columns) == 0
    @test length(rs.names) == 0
    close!(rs)
    rm(empty)

    # An all-missing column has no element type to write; this used to fail deep inside
    # arrowformat with an ambiguous-method error.
    err2 = try
        featherwrite(tempname() * ".feather", Any[Vector{Missing}([missing, missing])], [:m])
        nothing
    catch e; e end
    @test err2 isa ArgumentError
    @test occursin("Missing", sprint(showerror, err2))
end

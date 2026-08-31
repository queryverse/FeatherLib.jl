@testitem "ReadWrite" begin
    testdir = joinpath(@__DIR__, "data")
    files = map(x -> joinpath(testdir, x), readdir(testdir))

    for f in files
         res = featherread(f)
         columns, headers = res.columns, res.names

        ncols = length(columns)
        nrows = length(columns[1])

        temp = tempname()

        featherwrite(temp, columns, headers, description=res.description, metadata=res.metadata)

         res2 = featherread(temp)
         columns2, headers2 = res2.columns, res2.names

        @test length(columns2) == ncols

        @test headers==headers2

        for (c1,c2) in zip(columns, columns2)
            @test length(c1)==nrows
            @test length(c2)==nrows
            for i = 1:nrows
                @test isequal(c1[i], c2[i])
            end
        end

    @test res.description == res2.description
    @test res.metadata == res2.metadata

        # Both ResultSets memory map their file, which on Windows keeps it locked. This
        # used to need a GC.gc() dance with nested try/catch to clean up; close! releases
        # the mappings deterministically instead.
        close!(res)
        close!(res2)
        rm(temp)
    end
end

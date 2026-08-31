# FeatherLib

[![Project Status: Active - The project has reached a stable, usable state and is being actively developed.](http://www.repostatus.org/badges/latest/active.svg)](http://www.repostatus.org/#active)
[![Build Status](https://github.com/queryverse/FeatherLib.jl/actions/workflows/juliaci.yml/badge.svg?branch=main)](https://github.com/queryverse/FeatherLib.jl/actions/workflows/juliaci.yml)
[![codecov](https://codecov.io/gh/queryverse/FeatherLib.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/queryverse/FeatherLib.jl)

## Overview

This is a low level package to read and write **Feather V1** files (the original `FEA1` format from [wesm/feather](https://github.com/wesm/feather)). It is not meant to be used by end users, but rather as a building block for other packages that expose user friendly APIs for file IO.

Note that Feather V1 is not the same format as Feather V2, which is exactly the Arrow IPC file format on disk and is what every current tool writes, whether the file is named `.feather` or `.arrow`. This package does not read V2 files; use [Arrow.jl](https://github.com/apache/arrow-julia) for those.

End users are encouraged to use either [FeatherFiles.jl](https://github.com/queryverse/FeatherFiles.jl) or [Feather.jl](https://github.com/JuliaData/Feather.jl) to interact with feather files.

## Getting Started

The package exports two functions: ``featherread`` and ``featherwrite``.

Use the ``featherread`` function to read a feather file:
````julia
data = featherread("testfile.feather")
````

``data`` will then be of type ``ResultSet``. The field ``columns`` is a vector of vectors and holds the actual data columns. The field ``names`` returns the names of the columns. The ``description`` and ``metadata`` fields return additional data from the feather file.

Use the ``featherwrite`` function to write a feather file:
````julia
featherwrite("testfile.feather", column_data, column_names)
````

``columns`` should be a vector of vectors that holds the data to be written. ``column_names`` should be a vector of ``Symbol``s with the column names.

## Acknowledgements

[Douglas Bates](https://github.com/dmbates), [ExpandingMan](https://github.com/ExpandingMan) and [Jacob Quinn](https://github.com/quinnj) deserve most of the credit for the code in this package: their code in the [Feather.jl](https://github.com/JuliaData/Feather.jl) package was the starting point for this package here. They are of course not responsible for any errors introduced by myself in this package here.

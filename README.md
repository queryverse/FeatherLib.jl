# FeatherLib

[![Project Status: Active - The project has reached a stable, usable state and is being actively developed.](http://www.repostatus.org/badges/latest/active.svg)](http://www.repostatus.org/#active)
[![Build Status](https://travis-ci.org/davidanthoff/FeatherLib.jl.svg?branch=master)](https://travis-ci.org/davidanthoff/FeatherLib.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/wnwl7a4fmy1osuqr/branch/master?svg=true)](https://ci.appveyor.com/project/davidanthoff/featherlib-jl/branch/master)
[![FeatherLib](http://pkg.julialang.org/badges/FeatherLib_0.6.svg)](http://pkg.julialang.org/?pkg=FeatherLib)
[![codecov](https://codecov.io/gh/davidanthoff/FeatherLib.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/davidanthoff/FeatherLib.jl)

## Overview

This is a low level package to read feather files. It is not meant to be
used by end users, but rather as a building block for other packages that
expose user friendly APIs for file IO.

End users are encouraged to use either [FeatherFiles.jl](https://github.com/davidanthoff/FeatherFiles.jl)
or [Feather.jl](https://github.com/JuliaData/Feather.jl) to interact
with feather files.

[ExpandingMan](https://github.com/ExpandingMan) deserves most of the credit
for the code in this package: his code in the [Feather.jl](https://github.com/JuliaData/Feather.jl)
package was the starting point for this package here.

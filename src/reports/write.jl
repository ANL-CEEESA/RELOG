# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using DataFrames
using CSV
import Base: write

function write(solution::AbstractDict, filename::AbstractString)
    @info "Writing solution: $filename"
    open(filename, "w") do file
        JSON.print(file, solution, 2)
    end
end

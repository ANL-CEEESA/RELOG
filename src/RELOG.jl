# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

module RELOG

include("instance/structs.jl")

include("graph/structs.jl")

include("graph/build.jl")
include("graph/csv.jl")
include("instance/compress.jl")
include("instance/parse.jl")
include("instance/validate.jl")
include("model/build.jl")
include("model/getsol.jl")
include("model/solve.jl")
include("reports/plant_emissions.jl")
include("reports/plant_outputs.jl")
include("reports/plants.jl")
include("reports/tr_emissions.jl")
include("reports/tr.jl")
include("reports/write.jl")
end

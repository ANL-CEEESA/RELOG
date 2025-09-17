module RELOG

_round(x::Number) = round(x, digits = 5)

include("instance/structs.jl")
include("instance/parse.jl")
include("model/jumpext.jl")
include("model/dist.jl")
include("model/build.jl")
include("reports/plants.jl")
include("reports/transportation.jl")
include("reports/centers.jl")

end # module RELOG

module RELOG

function _round(x::Number)
    if abs(x) < 1e-5
        return 0
    else
        return round(x, digits = 5)
    end
end

include("instance/structs.jl")
include("instance/parse.jl")
include("model/jumpext.jl")
include("model/dist.jl")
include("model/build.jl")
include("reports/plants.jl")
include("reports/transportation.jl")
include("reports/centers.jl")

end # module RELOG

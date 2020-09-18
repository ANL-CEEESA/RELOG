# Copyright (C) 2020 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using Test

@testset "RELOG" begin
    include("instance_test.jl")
    include("graph_test.jl")
    include("model_test.jl")
    include("reports_test.jl")
end
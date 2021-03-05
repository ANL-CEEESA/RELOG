# Copyright (C) 2020 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using Test

@testset "RELOG" begin
    @testset "Instance" begin
        include("instance/compress_test.jl")
        include("instance/geodb_test.jl")
        include("instance/parse_test.jl")
    end
    @testset "Graph" begin
        include("graph/build_test.jl")
    end
    @testset "Model" begin
        include("model/build_test.jl")
        include("model/solve_test.jl")
        include("model/resolve_test.jl")
    end
    include("reports_test.jl")
end

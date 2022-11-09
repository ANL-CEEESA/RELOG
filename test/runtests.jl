# Copyright (C) 2020 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using Test
using RELOG
using Revise

includet("instance/compress_test.jl")
includet("instance/geodb_test.jl")
includet("instance/parse_test.jl")
includet("graph/build_test.jl")
includet("model/build_test.jl")
includet("model/solve_test.jl")
includet("reports_test.jl")

function fixture(path)
    for candidate in [
        "fixtures/$path",
        "test/fixtures/$path"
    ]
        if isfile(candidate)
            return candidate
        end
    end
    error("Fixture not found: $path")
end

function runtests()
    @testset "RELOG" begin
        @testset "Instance" begin
            compress_test()
            geodb_test()
            parse_test()
        end
        @testset "Graph" begin
            graph_build_test()
        end
        @testset "Model" begin
            model_build_test()
            model_solve_test()
        end
        reports_test()
    end
    return
end

runtests()

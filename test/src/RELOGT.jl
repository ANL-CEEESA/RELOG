module RELOGT

using Test
using JuliaFormatter

include("instance/compress_test.jl")
include("instance/geodb_test.jl")
include("instance/parse_test.jl")
include("graph/build_test.jl")
include("graph/dist_test.jl")
include("model/build_test.jl")
include("model/solve_test.jl")
include("model/resolve_test.jl")
include("reports_test.jl")

basedir = dirname(@__FILE__)

function fixture(path::String)::String
    return "$basedir/../fixtures/$path"
end

function runtests()
    @testset "RELOG" begin
        @testset "instance" begin
            instance_compress_test()
            instance_geodb_test()
            instance_parse_test()
        end
        @testset "graph" begin
            graph_build_test()
            graph_dist_test()
        end
        @testset "model" begin
            model_build_test()
            model_solve_test()
            model_resolve_test()
        end
        reports_test()
    end
    return
end

function format()
    JuliaFormatter.format(basedir, verbose = true)
    JuliaFormatter.format("$basedir/../../src", verbose = true)
    return
end

export runtests, format

end # module RELOGT

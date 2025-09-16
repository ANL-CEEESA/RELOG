module RELOGT

using Test
using RELOG
using JuliaFormatter

include("instance/parse_test.jl")
include("model/build_test.jl")
include("model/dist_test.jl")
include("reports_test.jl")
include("../fixtures/boat_example.jl")

basedir = dirname(@__FILE__)

function fixture(path::String)::String
    return "$basedir/../fixtures/$path"
end

function runtests()
    @testset "RELOG" begin
        instance_parse_test_1()
        instance_parse_test_2()
        model_build_test()
        model_dist_test()
        report_tests()
    end
    return
end

function format()
    JuliaFormatter.format(basedir, verbose = true)
    JuliaFormatter.format("$basedir/../../src", verbose = true)
    JuliaFormatter.format("$basedir/../fixtures", verbose = true)
    return
end
end # module RELOGT

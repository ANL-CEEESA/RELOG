module RELOGT

using Test
using RELOG
using JuliaFormatter

include("instance/parse_test.jl")
include("model/build_test.jl")

basedir = dirname(@__FILE__)

function fixture(path::String)::String
    return "$basedir/../fixtures/$path"
end

function runtests()
    @testset "RELOG" begin
        instance_parse_test_1()
        instance_parse_test_2()
        model_build_test()
    end
end

function format()
    JuliaFormatter.format(basedir, verbose = true)
    JuliaFormatter.format("$basedir/../../src", verbose = true)
    return
end
end # module RELOGT

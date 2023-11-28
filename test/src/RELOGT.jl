module RELOGT

using Test
using RELOG
using JuliaFormatter

include("instance/parse_test.jl")

basedir = dirname(@__FILE__)

function fixture(path::String)::String
    return "$basedir/../fixtures/$path"
end

function runtests()
    @testset "RELOG" begin
        instance_parse_test()
    end
end

function format()
    JuliaFormatter.format(basedir, verbose = true)
    JuliaFormatter.format("$basedir/../../src", verbose = true)
    return
end
end # module RELOGT

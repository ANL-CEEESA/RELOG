# Copyright (C) 2020 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using Test

@testset "ReverseManufacturing" begin
    include("instance_test.jl")
    include("model_test.jl")
end
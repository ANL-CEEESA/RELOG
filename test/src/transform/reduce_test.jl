using RELOG
using Test
using HiGHS
using JuMP

function reduce_test()
    @testset "reduce_plants" begin
        instance = RELOG.parsefile(fixture("boat_example.json"))
        n_before = length(instance.plants)

        reduced = RELOG.reduce_plants(instance, max_plants = n_before - 1)
        @test length(reduced.plants) == n_before - 1

        model = RELOG.build_model(reduced, optimizer = HiGHS.Optimizer)
        set_silent(model)
        optimize!(model)
        @test termination_status(model) == OPTIMAL
    end
end

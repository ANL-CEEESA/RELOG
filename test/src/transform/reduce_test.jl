using RELOG
using Test
using HiGHS
using JuMP

function reduce_test()
    @testset "reduce_plants" begin
        instance = RELOG.parsefile(fixture("boat_example.json"))
        n_before = length(instance.plants)

        (reduced, merge_map) = RELOG.reduce_plants(instance, max_plants = n_before - 1)
        @test length(reduced.plants) == n_before - 1

        # Every original plant should appear in exactly one merge group
        all_originals = vcat(values(merge_map)...)
        @test sort(all_originals) == sort([p.name for p in instance.plants])

        # Every reduced plant should have a merge map entry
        @test sort(collect(keys(merge_map))) == sort([p.name for p in reduced.plants])

        model = RELOG.build_model(reduced, optimizer = HiGHS.Optimizer)
        set_silent(model)
        optimize!(model)
        @test termination_status(model) == OPTIMAL
    end
end

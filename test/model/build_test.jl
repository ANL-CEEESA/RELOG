# Copyright (C) 2020 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using RELOG, HiGHS, JuMP, Printf, JSON, MathOptInterface.FileFormats

function model_build_test()
    @testset "build" begin
        instance = RELOG.parsefile(fixture("instances/s1.json"))
        graph = RELOG.build_graph(instance)
        model = RELOG.build_model(instance, graph, HiGHS.Optimizer)

        process_node_by_location_name =
            Dict(n.location.location_name => n for n in graph.process_nodes)

        shipping_node_by_loc_and_prod_names = Dict(
            (n.location.location_name, n.product.name) => n for n in graph.plant_shipping_nodes
        )

        @test length(model[1, :open_plant]) == 12
        @test length(model[2, :flow]) == 76
        @test length(model[2, :plant_dispose]) == 16
        @test length(model[2, :capacity]) == 12
        @test length(model[2, :expansion]) == 12

        # l1 = process_node_by_location_name["L1"]
        # v = model[2, :capacity][l1.index, 1]
        # @test lower_bound(v) == 0.0
        # @test upper_bound(v) == 1000.0

        # v = model[2, :expansion][l1.index, 1]
        # @test lower_bound(v) == 0.0
        # @test upper_bound(v) == 750.0

        # v = model[2, :plant_dispose][shipping_node_by_loc_and_prod_names["L1", "P2"].index, 1]
        # @test lower_bound(v) == 0.0
        # @test upper_bound(v) == 1.0
    end
end
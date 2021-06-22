# Copyright (C) 2020 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using RELOG, Cbc, JuMP, Printf, JSON, MathOptInterface.FileFormats

@testset "build" begin
    basedir = dirname(@__FILE__)
    instance = RELOG.parsefile("$basedir/../../instances/s1.json")
    graph = RELOG.build_graph(instance)
    model = RELOG.build_model(instance, graph, Cbc.Optimizer)
    set_optimizer_attribute(model, "logLevel", 0)

    process_node_by_location_name =
        Dict(n.location.location_name => n for n in graph.process_nodes)

    shipping_node_by_loc_and_prod_names = Dict(
        (n.location.location_name, n.product.name) => n for n in graph.plant_shipping_nodes
    )

    @test length(model[:flow]) == 76
    @test length(model[:dispose]) == 16
    @test length(model[:open_plant]) == 12
    @test length(model[:capacity]) == 12
    @test length(model[:expansion]) == 12

    l1 = process_node_by_location_name["L1"]
    v = model[:capacity][l1, 1]
    @test lower_bound(v) == 0.0
    @test upper_bound(v) == 1000.0

    v = model[:expansion][l1, 1]
    @test lower_bound(v) == 0.0
    @test upper_bound(v) == 750.0

    v = model[:dispose][shipping_node_by_loc_and_prod_names["L1", "P2"], 1]
    @test lower_bound(v) == 0.0
    @test upper_bound(v) == 1.0
end

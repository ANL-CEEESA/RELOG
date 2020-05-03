# Copyright (C) 2020 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using ReverseManufacturing, Cbc, JuMP, Printf, JSON

@testset "Model" begin
    @testset "build" begin
        basedir = dirname(@__FILE__)
        instance = ReverseManufacturing.load("$basedir/../instances/samples/s1.json")
        graph = ReverseManufacturing.build_graph(instance)
        model = ReverseManufacturing.build_model(instance, graph, Cbc.Optimizer)

        process_node_by_location_name = Dict(n.plant.location_name => n
                                             for n in graph.process_nodes)

        shipping_node_by_location_and_product_names = Dict((n.location.location_name, n.product.name) => n
                                                           for n in graph.plant_shipping_nodes)
        
        
        @test length(model.vars.flow) == 38
        @test length(model.vars.dispose) == 8
        @test length(model.vars.open_plant) == 6
        @test length(model.vars.capacity) == 6
        @test length(model.vars.expansion) == 6

        l1 = process_node_by_location_name["L1"]
        v = model.vars.capacity[l1]
        @test lower_bound(v) == 0.0
        @test upper_bound(v) == 1000.0
        
        v = model.vars.expansion[l1]
        @test lower_bound(v) == 0.0
        @test upper_bound(v) == 750.0
        
        v = model.vars.dispose[shipping_node_by_location_and_product_names["L1", "P2"]]
        @test lower_bound(v) == 0.0
        @test upper_bound(v) == 1.0

    end

    @testset "build" begin
        solution = ReverseManufacturing.solve("$(pwd())/../instances/samples/s1.json")
#         println(JSON.print(solution, 2))

#         @test "plants" in keys(solution)
#         @test "F1" in keys(solution["plants"])
#         @test "F2" in keys(solution["plants"])
#         @test "F3" in keys(solution["plants"])
#         @test "F4" in keys(solution["plants"])
#         @test "L2" in keys(solution["plants"]["F1"])
#         @test "total output" in keys(solution["plants"]["F1"]["L2"])

#         @test "capacity" in keys(solution["plants"]["F1"]["L1"])
    end
end



# Copyright (C) 2020 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using RELOG, Cbc, JuMP, Printf, JSON, MathOptInterface.FileFormats

@testset "Model" begin
    @testset "build" begin
        basedir = dirname(@__FILE__)
        instance = RELOG.load("$basedir/../instances/s1.json")
        graph = RELOG.build_graph(instance)
        model = RELOG.build_model(instance, graph, Cbc.Optimizer)

        process_node_by_location_name = Dict(n.location.location_name => n
                                             for n in graph.process_nodes)

        shipping_node_by_location_and_product_names = Dict((n.location.location_name, n.product.name) => n
                                                           for n in graph.plant_shipping_nodes)
        
        
        @test length(model.vars.flow) == 76
        @test length(model.vars.dispose) == 16
        @test length(model.vars.open_plant) == 12
        @test length(model.vars.capacity) == 12
        @test length(model.vars.expansion) == 12

        l1 = process_node_by_location_name["L1"]
        v = model.vars.capacity[l1, 1]
        @test lower_bound(v) == 0.0
        @test upper_bound(v) == 1000.0
        
        v = model.vars.expansion[l1, 1]
        @test lower_bound(v) == 0.0
        @test upper_bound(v) == 750.0
        
        v = model.vars.dispose[shipping_node_by_location_and_product_names["L1", "P2"], 1]
        @test lower_bound(v) == 0.0
        @test upper_bound(v) == 1.0
        
        #dest = FileFormats.Model(format = FileFormats.FORMAT_LP)
        #MOI.copy_to(dest, model.mip)
        #MOI.write_to_file(dest, "model.lp")
    end

    @testset "solve" begin
        solution = RELOG.solve("$(pwd())/../instances/s1.json")
        JSON.print(stdout, solution, 4)
        
        @test "Costs" in keys(solution)
        @test "Fixed operating (\$)" in keys(solution["Costs"])
        @test "Transportation (\$)" in keys(solution["Costs"])
        @test "Variable operating (\$)" in keys(solution["Costs"])
        @test "Total (\$)" in keys(solution["Costs"])

        @test "Plants" in keys(solution)
        @test "F1" in keys(solution["Plants"])
        @test "F2" in keys(solution["Plants"])
        @test "F3" in keys(solution["Plants"])
        @test "F4" in keys(solution["Plants"])
    end
end



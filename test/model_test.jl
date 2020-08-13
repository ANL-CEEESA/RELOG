# Copyright (C) 2020 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using RELOG, Cbc, JuMP, Printf, JSON, MathOptInterface.FileFormats

@testset "Model" begin
    @testset "build" begin
        basedir = dirname(@__FILE__)
        instance = RELOG.parsefile("$basedir/../instances/s1.json")
        graph = RELOG.build_graph(instance)
        model = RELOG.build_model(instance, graph, Cbc.Optimizer)
        set_optimizer_attribute(model.mip, "logLevel", 0)

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
        solution = RELOG.solve("$(pwd())/../instances/s1.json",
                               output_filename="$(pwd())/../tmp/sol.json")
        
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

    @testset "infeasible solve" begin
        json = JSON.parsefile("$(pwd())/../instances/s1.json")
        for (location_name, location_dict) in json["products"]["P1"]["initial amounts"]
            location_dict["amount (tonne)"] *= 1000
        end
        RELOG.solve(RELOG.parse(json))
    end

end



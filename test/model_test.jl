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

        process_node_by_location_name =
            Dict(n.location.location_name => n for n in graph.process_nodes)

        shipping_node_by_location_and_product_names = Dict(
            (n.location.location_name, n.product.name) => n for
            n in graph.plant_shipping_nodes
        )

        @test length(model.mip[:flow]) == 76
        @test length(model.mip[:dispose]) == 16
        @test length(model.mip[:open_plant]) == 12
        @test length(model.mip[:capacity]) == 12
        @test length(model.mip[:expansion]) == 12

        l1 = process_node_by_location_name["L1"]
        v = model.mip[:capacity][l1, 1]
        @test lower_bound(v) == 0.0
        @test upper_bound(v) == 1000.0

        v = model.mip[:expansion][l1, 1]
        @test lower_bound(v) == 0.0
        @test upper_bound(v) == 750.0

        v = model.mip[:dispose][shipping_node_by_location_and_product_names["L1", "P2"], 1]
        @test lower_bound(v) == 0.0
        @test upper_bound(v) == 1.0

        # dest = FileFormats.Model(format = FileFormats.FORMAT_LP)
        # MOI.copy_to(dest, model.mip)
        # MOI.write_to_file(dest, "model.lp")
    end

    @testset "solve (exact)" begin
        solution_filename_a = tempname()
        solution_filename_b = tempname()
        solution =
            RELOG.solve("$(pwd())/../instances/s1.json", output = solution_filename_a)

        @test isfile(solution_filename_a)

        RELOG.write(solution, solution_filename_b)
        @test isfile(solution_filename_b)

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


    @testset "solve (heuristic)" begin
        # Should not crash
        solution = RELOG.solve("$(pwd())/../instances/s1.json", heuristic = true)
    end

    @testset "infeasible solve" begin
        json = JSON.parsefile("$(pwd())/../instances/s1.json")
        for (location_name, location_dict) in json["products"]["P1"]["initial amounts"]
            location_dict["amount (tonne)"] *= 1000
        end
        RELOG.solve(RELOG.parse(json))
    end

    @testset "storage" begin
        basedir = dirname(@__FILE__)
        filename = "$basedir/fixtures/storage.json"
        instance = RELOG.parsefile(filename)
        @test instance.plants[1].storage_limit == 50.0
        @test instance.plants[1].storage_cost == [2.0, 1.5, 1.0]

        solution = RELOG.solve(filename)
        plant_dict = solution["Plants"]["mega plant"]["Chicago"]
        @test plant_dict["Variable operating cost (\$)"] == [500.0, 0.0, 100.0]
        @test plant_dict["Process (tonne)"] == [50.0, 0.0, 50.0]
        @test plant_dict["Storage (tonne)"] == [50.0, 50.0, 0.0]
        @test plant_dict["Storage cost (\$)"] == [100.0, 75.0, 0.0]

        @test solution["Costs"]["Variable operating (\$)"] == [500.0, 0.0, 100.0]
        @test solution["Costs"]["Storage (\$)"] == [100.0, 75.0, 0.0]
        @test solution["Costs"]["Total (\$)"] == [600.0, 75.0, 100.0]
    end
end

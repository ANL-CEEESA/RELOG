# Copyright (C) 2020 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using RELOG, JuMP, Printf, JSON, MathOptInterface.FileFormats


function model_solve_test()
    @testset "solve (exact)" begin
        solution_filename_a = tempname()
        solution_filename_b = tempname()
        solution = RELOG.solve(fixture("s1.json"), output = solution_filename_a)

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

        @test "Products" in keys(solution)
        @test "P1" in keys(solution["Products"])
        @test "C1" in keys(solution["Products"]["P1"])
        @test "Dispose (tonne)" in keys(solution["Products"]["P1"]["C1"])

        total_disposal =
            sum([loc["Dispose (tonne)"] for loc in values(solution["Products"]["P1"])])
        @test total_disposal == [1.0, 1.0]
    end

    @testset "solve (heuristic)" begin
        # Should not crash
        solution = RELOG.solve(fixture("s1.json"), heuristic = true)
    end

    @testset "solve (infeasible)" begin
        json = JSON.parsefile(fixture("s1.json"))
        for (location_name, location_dict) in json["products"]["P1"]["initial amounts"]
            location_dict["amount (tonne)"] *= 1000
        end
        @test_throws ErrorException("No solution available") RELOG.solve(RELOG.parse(json))
    end

    @testset "solve (with storage)" begin
        filename = fixture("storage.json")
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

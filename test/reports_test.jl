# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using RELOG, JSON, GZip

load_json_gz(filename) = JSON.parse(GZip.gzopen(filename))

# function check(func, expected_csv_filename::String)
#     solution = load_json_gz("fixtures/nimh_solution.json.gz")
#     actual_csv_filename = tempname()
#     func(solution, actual_csv_filename)
#     @test isfile(actual_csv_filename)
#     if readlines(actual_csv_filename) != readlines(expected_csv_filename)
#         out_filename = replace(expected_csv_filename, ".csv" => "_actual.csv")
#         @error "$func: Unexpected CSV contents: $out_filename"
#         write(out_filename, read(actual_csv_filename))
#         @test false
#     end
# end

@testset "Reports" begin
    #     @testset "from fixture" begin
    #         check(RELOG.write_plants_report, "fixtures/nimh_plants.csv")
    #         check(RELOG.write_plant_outputs_report, "fixtures/nimh_plant_outputs.csv")
    #         check(RELOG.write_plant_emissions_report, "fixtures/nimh_plant_emissions.csv")
    #         check(RELOG.write_transportation_report, "fixtures/nimh_transportation.csv")
    #         check(RELOG.write_transportation_emissions_report, "fixtures/nimh_transportation_emissions.csv")
    #     end

    @testset "from solve" begin
        solution = RELOG.solve("$(pwd())/../instances/s1.json")
        tmp_filename = tempname()
        # The following should not crash
        RELOG.write_plants_report(solution, tmp_filename)
        RELOG.write_plant_outputs_report(solution, tmp_filename)
        RELOG.write_plant_emissions_report(solution, tmp_filename)
        RELOG.write_transportation_report(solution, tmp_filename)
        RELOG.write_transportation_emissions_report(solution, tmp_filename)
    end
end

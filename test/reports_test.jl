# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using RELOG, JSON, GZip

basedir = @__DIR__

function reports_test()
    @testset "Reports" begin
        @testset "from solve" begin
            solution = RELOG.solve(fixture("instances/s1.json"))
            tmp_filename = tempname()
            # The following should not crash
            RELOG.write_plant_emissions_report(solution, tmp_filename)
            RELOG.write_plant_outputs_report(solution, tmp_filename)
            RELOG.write_plants_report(solution, tmp_filename)
            RELOG.write_products_report(solution, tmp_filename)
            RELOG.write_transportation_emissions_report(solution, tmp_filename)
            RELOG.write_transportation_report(solution, tmp_filename)
        end
    end
end
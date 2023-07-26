# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using DataFrames
using CSV
import Base: write

function write(solution::AbstractDict, filename::AbstractString)
    @info "Writing solution: $filename"
    open(filename, "w") do file
        JSON.print(file, solution, 2)
    end
end

function write_reports(
    solution::AbstractDict,
    basename::AbstractString;
    marginal_costs = true,
)
    RELOG.write_products_report(solution, "$(basename)_products.csv"; marginal_costs)
    RELOG.write_plants_report(solution, "$(basename)_plants.csv")
    RELOG.write_plant_outputs_report(solution, "$(basename)_plant_outputs.csv")
    RELOG.write_plant_emissions_report(solution, "$(basename)_plant_emissions.csv")
    RELOG.write_transportation_report(solution, "$(basename)_tr.csv")
    RELOG.write_transportation_emissions_report(solution, "$(basename)_tr_emissions.csv")
    return
end

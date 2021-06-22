# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using DataFrames
using CSV

function plant_emissions_report(solution)::DataFrame
    df = DataFrame()
    df."plant type" = String[]
    df."location name" = String[]
    df."year" = Int[]
    df."emission type" = String[]
    df."emission amount (tonne)" = Float64[]
    T = length(solution["Energy"]["Plants (GJ)"])
    for (plant_name, plant_dict) in solution["Plants"]
        for (location_name, location_dict) in plant_dict
            for (emission_name, emission_amount) in location_dict["Emissions (tonne)"]
                for year = 1:T
                    push!(
                        df,
                        [
                            plant_name,
                            location_name,
                            year,
                            emission_name,
                            round(emission_amount[year], digits = 2),
                        ],
                    )
                end
            end
        end
    end
    return df
end

write_plant_emissions_report(solution, filename) =
    CSV.write(filename, plant_emissions_report(solution))

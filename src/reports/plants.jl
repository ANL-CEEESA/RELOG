# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using DataFrames
using CSV

function plants_report(solution)::DataFrame
    df = DataFrame()
    df."plant type" = String[]
    df."location name" = String[]
    df."year" = Int[]
    df."latitude (deg)" = Float64[]
    df."longitude (deg)" = Float64[]
    df."capacity (tonne)" = Float64[]
    df."amount processed (tonne)" = Float64[]
    df."amount received (tonne)" = Float64[]
    df."amount in storage (tonne)" = Float64[]
    df."utilization factor (%)" = Float64[]
    df."energy (GJ)" = Float64[]
    df."opening cost (\$)" = Float64[]
    df."expansion cost (\$)" = Float64[]
    df."fixed operating cost (\$)" = Float64[]
    df."variable operating cost (\$)" = Float64[]
    df."storage cost (\$)" = Float64[]
    df."total cost (\$)" = Float64[]
    T = length(solution["Energy"]["Plants (GJ)"])
    for (plant_name, plant_dict) in solution["Plants"]
        for (location_name, location_dict) in plant_dict
            for year = 1:T
                capacity = round(location_dict["Capacity (tonne)"][year], digits = 6)
                received = round(location_dict["Total input (tonne)"][year], digits = 6)
                processed = round(location_dict["Process (tonne)"][year], digits = 6)
                in_storage = round(location_dict["Storage (tonne)"][year], digits = 6)
                utilization_factor = round(processed / capacity * 100.0, digits = 6)
                energy = round(location_dict["Energy (GJ)"][year], digits = 6)
                latitude = round(location_dict["Latitude (deg)"], digits = 6)
                longitude = round(location_dict["Longitude (deg)"], digits = 6)
                opening_cost = round(location_dict["Opening cost (\$)"][year], digits = 6)
                expansion_cost =
                    round(location_dict["Expansion cost (\$)"][year], digits = 6)
                fixed_cost =
                    round(location_dict["Fixed operating cost (\$)"][year], digits = 6)
                var_cost =
                    round(location_dict["Variable operating cost (\$)"][year], digits = 6)
                storage_cost = round(location_dict["Storage cost (\$)"][year], digits = 6)
                total_cost = round(
                    opening_cost + expansion_cost + fixed_cost + var_cost + storage_cost,
                    digits = 6,
                )
                push!(
                    df,
                    [
                        plant_name,
                        location_name,
                        year,
                        latitude,
                        longitude,
                        capacity,
                        processed,
                        received,
                        in_storage,
                        utilization_factor,
                        energy,
                        opening_cost,
                        expansion_cost,
                        fixed_cost,
                        var_cost,
                        storage_cost,
                        total_cost,
                    ],
                )
            end
        end
    end
    return df
end

write_plants_report(solution, filename) = CSV.write(filename, plants_report(solution))

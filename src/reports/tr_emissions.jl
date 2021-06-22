# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using DataFrames
using CSV

function transportation_emissions_report(solution)::DataFrame
    df = DataFrame()
    df."source type" = String[]
    df."source location name" = String[]
    df."source latitude (deg)" = Float64[]
    df."source longitude (deg)" = Float64[]
    df."destination type" = String[]
    df."destination location name" = String[]
    df."destination latitude (deg)" = Float64[]
    df."destination longitude (deg)" = Float64[]
    df."product" = String[]
    df."year" = Int[]
    df."distance (km)" = Float64[]
    df."shipped amount (tonne)" = Float64[]
    df."shipped amount-distance (tonne-km)" = Float64[]
    df."emission type" = String[]
    df."emission amount (tonne)" = Float64[]

    T = length(solution["Energy"]["Plants (GJ)"])
    for (dst_plant_name, dst_plant_dict) in solution["Plants"]
        for (dst_location_name, dst_location_dict) in dst_plant_dict
            for (src_plant_name, src_plant_dict) in dst_location_dict["Input"]
                for (src_location_name, src_location_dict) in src_plant_dict
                    for (emission_name, emission_amount) in
                        src_location_dict["Emissions (tonne)"]
                        for year = 1:T
                            push!(
                                df,
                                [
                                    src_plant_name,
                                    src_location_name,
                                    round(src_location_dict["Latitude (deg)"], digits = 6),
                                    round(src_location_dict["Longitude (deg)"], digits = 6),
                                    dst_plant_name,
                                    dst_location_name,
                                    round(dst_location_dict["Latitude (deg)"], digits = 6),
                                    round(dst_location_dict["Longitude (deg)"], digits = 6),
                                    dst_location_dict["Input product"],
                                    year,
                                    round(src_location_dict["Distance (km)"], digits = 2),
                                    round(
                                        src_location_dict["Amount (tonne)"][year],
                                        digits = 2,
                                    ),
                                    round(
                                        src_location_dict["Amount (tonne)"][year] *
                                        src_location_dict["Distance (km)"],
                                        digits = 2,
                                    ),
                                    emission_name,
                                    round(emission_amount[year], digits = 2),
                                ],
                            )
                        end
                    end
                end
            end
        end
    end
    return df
end

write_transportation_emissions_report(solution, filename) =
    CSV.write(filename, transportation_emissions_report(solution))

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
    df."utilization factor (%)" = Float64[]
    df."energy (GJ)" = Float64[]
    df."opening cost (\$)" = Float64[]
    df."expansion cost (\$)" = Float64[]
    df."fixed operating cost (\$)" = Float64[]
    df."variable operating cost (\$)" = Float64[]
    df."total cost (\$)" = Float64[]
    T = length(solution["Energy"]["Plants (GJ)"])
    for (plant_name, plant_dict) in solution["Plants"]
        for (location_name, location_dict) in plant_dict
            var_cost = zeros(T)
            for (src_plant_name, src_plant_dict) in location_dict["Input"]
                for (src_location_name, src_location_dict) in src_plant_dict
                    var_cost += src_location_dict["Variable operating cost (\$)"]
                end
            end
            var_cost = round.(var_cost, digits=2)
            for year in 1:T
                opening_cost = round(location_dict["Opening cost (\$)"][year], digits=2)
                expansion_cost = round(location_dict["Expansion cost (\$)"][year], digits=2)
                fixed_cost = round(location_dict["Fixed operating cost (\$)"][year], digits=2)
                total_cost = round(var_cost[year] + opening_cost + expansion_cost + fixed_cost, digits=2)
                capacity = round(location_dict["Capacity (tonne)"][year], digits=2)
                processed = round(location_dict["Total input (tonne)"][year], digits=2)
                utilization_factor = round(processed / capacity * 100.0, digits=2)
                energy = round(location_dict["Energy (GJ)"][year], digits=2)
                latitude = round(location_dict["Latitude (deg)"], digits=6)
                longitude = round(location_dict["Longitude (deg)"], digits=6)
                push!(df, [
                    plant_name,
                    location_name,
                    year,
                    latitude,
                    longitude,
                    capacity,
                    processed,
                    utilization_factor,
                    energy,
                    opening_cost,
                    expansion_cost,
                    fixed_cost,
                    var_cost[year],
                    total_cost,
                ])
            end
        end
    end
    return df
end

function plant_outputs_report(solution)::DataFrame
    df = DataFrame()
    df."plant type" = String[]
    df."location name" = String[]
    df."year" = Int[]
    df."product name" = String[]
    df."amount produced (tonne)" = Float64[]
    df."amount sent (tonne)" = Float64[]
    df."amount disposed (tonne)" = Float64[]
    df."disposal cost (\$)" = Float64[]
    T = length(solution["Energy"]["Plants (GJ)"])
    for (plant_name, plant_dict) in solution["Plants"]
        for (location_name, location_dict) in plant_dict
            for (product_name, amount_produced) in location_dict["Total output"]
                send_dict = location_dict["Output"]["Send"]
                disposal_dict = location_dict["Output"]["Dispose"]
                
                sent = zeros(T)
                if product_name in keys(send_dict)
                    for (dst_plant_name, dst_plant_dict) in send_dict[product_name]
                        for (dst_location_name, dst_location_dict) in dst_plant_dict
                            sent += dst_location_dict["Amount (tonne)"]
                        end
                    end
                end
                sent = round.(sent, digits=2)
                
                disposal_amount = zeros(T)
                disposal_cost = zeros(T)
                if product_name in keys(disposal_dict)
                    disposal_amount += disposal_dict[product_name]["Amount (tonne)"]
                    disposal_cost += disposal_dict[product_name]["Cost (\$)"]
                end
                disposal_amount = round.(disposal_amount, digits=2)
                disposal_cost = round.(disposal_cost, digits=2)
                
                for year in 1:T
                    push!(df, [
                        plant_name,
                        location_name,
                        year,
                        product_name,
                        round(amount_produced[year], digits=2),
                        sent[year],
                        disposal_amount[year],
                        disposal_cost[year],
                    ])
                end
            end
        end
    end
    return df
end


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
                for year in 1:T
                    push!(df, [
                        plant_name,
                        location_name,
                        year,
                        emission_name,
                        round(emission_amount[year], digits=2),
                    ])
                end
            end
        end
    end
    return df
end


function transportation_report(solution)::DataFrame
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
    df."amount (tonne)" = Float64[]
    df."amount-distance (tonne-km)" = Float64[]
    df."transportation cost (\$)" = Float64[]    
    df."transportation energy (GJ)" = Float64[]    
    
    T = length(solution["Energy"]["Plants (GJ)"])
    for (dst_plant_name, dst_plant_dict) in solution["Plants"]
        for (dst_location_name, dst_location_dict) in dst_plant_dict
            for (src_plant_name, src_plant_dict) in dst_location_dict["Input"]
                for (src_location_name, src_location_dict) in src_plant_dict
                    for year in 1:T
                        push!(df, [
                            src_plant_name,
                            src_location_name,
                            round(src_location_dict["Latitude (deg)"], digits=6),
                            round(src_location_dict["Longitude (deg)"], digits=6),
                            dst_plant_name,
                            dst_location_name,
                            round(dst_location_dict["Latitude (deg)"], digits=6),
                            round(dst_location_dict["Longitude (deg)"], digits=6),
                            dst_location_dict["Input product"],
                            year,
                            round(src_location_dict["Distance (km)"][year], digits=2),
                            round(src_location_dict["Amount (tonne)"][year], digits=2),
                            round(src_location_dict["Amount (tonne)"][year] *
                                      src_location_dict["Distance (km)"][year],
                                  digits=2),
                            round(src_location_dict["Transportation cost (\$)"][year], digits=2),
                            round(src_location_dict["Transportation energy (J)"][year] / 1e9, digits=2),
                        ])
                    end
                end
            end
        end
    end
    return df
end


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
                    for (emission_name, emission_amount) in src_location_dict["Emissions (tonne)"]
                        for year in 1:T
                            push!(df, [
                                src_plant_name,
                                src_location_name,
                                round(src_location_dict["Latitude (deg)"], digits=6),
                                round(src_location_dict["Longitude (deg)"], digits=6),
                                dst_plant_name,
                                dst_location_name,
                                round(dst_location_dict["Latitude (deg)"], digits=6),
                                round(dst_location_dict["Longitude (deg)"], digits=6),
                                dst_location_dict["Input product"],
                                year,
                                round(src_location_dict["Distance (km)"][year], digits=2),
                                round(src_location_dict["Amount (tonne)"][year], digits=2),
                                round(src_location_dict["Amount (tonne)"][year] *
                                          src_location_dict["Distance (km)"][year],
                                      digits=2),
                                emission_name,
                                round(emission_amount[year], digits=2),
                            ])
                        end
                    end
                end
            end
        end
    end
    return df
end


write_plants_report(solution, filename) =
    CSV.write(filename, plants_report(solution))

write_plant_outputs_report(solution, filename) =
    CSV.write(filename, plant_outputs_report(solution))

write_plant_emissions_report(solution, filename) =
    CSV.write(filename, plant_emissions_report(solution))

write_transportation_report(solution, filename) =
    CSV.write(filename, transportation_report(solution))

write_transportation_emissions_report(solution, filename) =
    CSV.write(filename, transportation_emissions_report(solution))

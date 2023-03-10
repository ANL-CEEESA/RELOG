# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using DataFrames
using CSV

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
                sent = round.(sent, digits = 6)

                disposal_amount = zeros(T)
                disposal_cost = zeros(T)
                if product_name in keys(disposal_dict)
                    disposal_amount += disposal_dict[product_name]["Amount (tonne)"]
                    disposal_cost += disposal_dict[product_name]["Cost (\$)"]
                end
                disposal_amount = round.(disposal_amount, digits = 6)
                disposal_cost = round.(disposal_cost, digits = 6)

                for year = 1:T
                    push!(
                        df,
                        [
                            plant_name,
                            location_name,
                            year,
                            product_name,
                            round(amount_produced[year], digits = 6),
                            sent[year],
                            disposal_amount[year],
                            disposal_cost[year],
                        ],
                    )
                end
            end
        end
    end
    return df
end

write_plant_outputs_report(solution, filename) =
    CSV.write(filename, plant_outputs_report(solution))

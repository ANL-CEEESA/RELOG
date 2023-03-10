# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using DataFrames
using CSV

function products_report(solution; marginal_costs = true)::DataFrame
    df = DataFrame()
    df."product name" = String[]
    df."location name" = String[]
    df."latitude (deg)" = Float64[]
    df."longitude (deg)" = Float64[]
    df."year" = Int[]
    df."amount (tonne)" = Float64[]
    df."amount disposed (tonne)" = Float64[]
    df."marginal cost (\$/tonne)" = Float64[]
    df."acquisition cost (\$)" = Float64[]
    df."disposal cost (\$)" = Float64[]
    T = length(solution["Energy"]["Plants (GJ)"])
    for (prod_name, prod_dict) in solution["Products"]
        for (location_name, location_dict) in prod_dict
            for year = 1:T
                marginal_cost = location_dict["Marginal cost (\$/tonne)"][year]
                latitude = round(location_dict["Latitude (deg)"], digits = 6)
                longitude = round(location_dict["Longitude (deg)"], digits = 6)
                amount = location_dict["Amount (tonne)"][year]
                amount_disposed = location_dict["Dispose (tonne)"][year]
                acquisition_cost = location_dict["Acquisition cost (\$)"][year]
                disposal_cost = location_dict["Disposal cost (\$)"][year]
                push!(
                    df,
                    [
                        prod_name,
                        location_name,
                        latitude,
                        longitude,
                        year,
                        amount,
                        amount_disposed,
                        marginal_cost,
                        acquisition_cost,
                        disposal_cost,
                    ],
                )
            end
        end
    end
    return df
end

write_products_report(solution, filename) = CSV.write(filename, products_report(solution))

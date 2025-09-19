# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using DataFrames
using CSV

function transportation_report(model)::DataFrame
    df = DataFrame()
    df."source" = String[]
    df."destination" = String[]
    df."product" = String[]
    df."year" = Int[]
    df."amount sent (tonne)" = Float64[]
    df."distance (km)" = Float64[]
    df."transportation cost (\$)" = Float64[]
    df."center revenue (\$)" = Float64[]
    df."center collection cost (\$)" = Float64[]

    E = model.ext[:E]
    distances = model.ext[:distances]
    T = 1:model.ext[:instance].time_horizon

    for (p1, p2, m) in E, t in T
        amount = value(model[:y][p1.name, p2.name, m.name, t])
        amount > 1e-3 || continue
        distance = distances[p1, p2, m]
        tr_cost = distance * amount * m.tr_cost[t]
        revenue = 0
        if isa(p2, Center)
            revenue = p2.revenue[t] * amount
        end
        collection_cost = 0
        if isa(p1, Center)
            collection_cost = p1.collection_cost[m][t] * amount
        end
        push!(
            df,
            Dict(
                "source" => p1.name,
                "destination" => p2.name,
                "product" => m.name,
                "year" => t,
                "amount sent (tonne)" => _round(amount),
                "distance (km)" => _round(distance),
                "transportation cost (\$)" => _round(tr_cost),
                "center revenue (\$)" => _round(revenue),
                "center collection cost (\$)" => _round(collection_cost),
            ),
        )
    end
    return df
end

function transportation_emissions_report(model)::DataFrame
    df = DataFrame()
    df."source" = String[]
    df."destination" = String[]
    df."product" = String[]
    df."emission" = String[]
    df."year" = Int[]
    df."amount sent (tonne)" = Float64[]
    df."distance (km)" = Float64[]
    df."emission factor (tonne/km/tonne)" = Float64[]
    df."emission amount (tonne)" = Float64[]

    E = model.ext[:E]
    distances = model.ext[:distances]
    T = 1:model.ext[:instance].time_horizon

    for (p1, p2, m) in E, t in T, g in keys(m.tr_emissions)
        amount = value(model[:y][p1.name, p2.name, m.name, t])
        amount > 1e-3 || continue
        distance = distances[p1, p2, m]
        emission_factor = m.tr_emissions[g][t]
        emissions = value(model[:z_em_tr][g, p1.name, p2.name, m.name, t])
        push!(
            df,
            Dict(
                "source" => p1.name,
                "destination" => p2.name,
                "product" => m.name,
                "emission" => g,
                "year" => t,
                "amount sent (tonne)" => _round(amount),
                "distance (km)" => _round(distance),
                "emission factor (tonne/km/tonne)" => _round(emission_factor),
                "emission amount (tonne)" => _round(emissions),
            ),
        )
    end
    return df
end

write_transportation_report(solution, filename) =
    CSV.write(filename, transportation_report(solution))

write_transportation_emissions_report(solution, filename) =
    CSV.write(filename, transportation_emissions_report(solution))

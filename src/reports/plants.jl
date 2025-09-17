# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using DataFrames
using CSV

function plants_report(model)::DataFrame
    df = DataFrame()
    df."plant" = String[]
    df."latitude" = Float64[]
    df."longitude" = Float64[]
    df."initial capacity" = Float64[]
    df."current capacity" = Float64[]
    df."year" = Int[]
    df."operational?" = Bool[]
    df."input amount (tonne)" = Float64[]
    df."opening cost (\$)" = Float64[]
    df."fixed operating cost (\$)" = Float64[]
    df."variable operating cost (\$)" = Float64[]

    plants = model.ext[:instance].plants
    T = 1:model.ext[:instance].time_horizon

    for p in plants, t in T
        operational = JuMP.value(model[:x][p.name, t]) > 0.5
        input = value(model[:z_input][p.name, t])

        # Opening cost
        opening_cost = 0
        if value(model[:x][p.name, t]) > 0.5 && value(model[:x][p.name, t-1]) < 0.5
            opening_cost = p.capacities[1].opening_cost[t]
        end

        # Plant size
        curr_capacity = 0
        if operational
            curr_capacity = p.capacities[1].size
        end

        fix_operating_cost = (operational ? p.capacities[1].fix_operating_cost[t] : 0)
        var_operating_cost = input * p.capacities[1].var_operating_cost[t]
        push!(
            df,
            Dict(
                "plant" => p.name,
                "latitude" => p.latitude,
                "longitude" => p.longitude,
                "initial capacity" => p.initial_capacity,
                "current capacity" => curr_capacity,
                "year" => t,
                "operational?" => operational,
                "input amount (tonne)" => _round(input),
                "opening cost (\$)" => _round(opening_cost),
                "fixed operating cost (\$)" => _round(fix_operating_cost),
                "variable operating cost (\$)" => _round(var_operating_cost),
            ),
        )
    end
    return df
end

function plant_outputs_report(model)::DataFrame
    df = DataFrame()
    df."plant" = String[]
    df."latitude" = Float64[]
    df."longitude" = Float64[]
    df."output product" = String[]
    df."year" = Int[]
    df."amount produced (tonne)" = Float64[]
    df."amount disposed (tonne)" = Float64[]
    df."disposal limit (tonne)" = Float64[]
    df."disposal cost (\$)" = Float64[]

    plants = model.ext[:instance].plants
    T = 1:model.ext[:instance].time_horizon

    for p in plants, m in keys(p.output), t in T
        produced = JuMP.value(model[:z_prod][p.name, m.name, t])
        disposed = JuMP.value(model[:z_disp][p.name, m.name, t])
        disposal_cost = p.disposal_cost[m][t] * disposed
        push!(
            df,
            Dict(
                "plant" => p.name,
                "latitude" => p.latitude,
                "longitude" => p.longitude,
                "output product" => m.name,
                "year" => t,
                "amount produced (tonne)" => _round(produced),
                "amount disposed (tonne)" => _round(disposed),
                "disposal limit (tonne)" => _round(p.disposal_limit[m][t]),
                "disposal cost (\$)" => _round(disposal_cost),
            ),
        )
    end
    return df
end

function plant_emissions_report(model)::DataFrame
    df = DataFrame()
    df."plant" = String[]
    df."latitude" = Float64[]
    df."longitude" = Float64[]
    df."emission" = String[]
    df."year" = Int[]
    df."input amount (tonne)" = Float64[]
    df."emission factor (tonne/tonne)" = Float64[]
    df."emissions amount (tonne)" = Float64[]

    plants = model.ext[:instance].plants
    T = 1:model.ext[:instance].time_horizon

    for p in plants, t in T, g in keys(p.emissions)
        input_amount = JuMP.value(model[:z_input][p.name, t])
        input_amount > 1e-3 || continue
        emissions = JuMP.value(model[:z_plant_em][g, p.name, t])
        emission_factor = p.emissions[g][t]
        push!(
            df,
            Dict(
                "plant" => p.name,
                "latitude" => p.latitude,
                "longitude" => p.longitude,
                "emission" => g,
                "year" => t,
                "input amount (tonne)" => _round(input_amount),
                "emission factor (tonne/tonne)" => _round(emission_factor),
                "emissions amount (tonne)" => _round(emissions),
            ),
        )
    end
    return df
end

write_plants_report(solution, filename) = CSV.write(filename, plants_report(solution))
write_plant_outputs_report(solution, filename) =
    CSV.write(filename, plant_outputs_report(solution))
write_plant_emissions_report(solution, filename) =
    CSV.write(filename, plant_emissions_report(solution))

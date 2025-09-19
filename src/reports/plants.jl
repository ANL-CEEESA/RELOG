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
    df."stored amount (tonne)" = Float64[]
    df."processed amount (tonne)" = Float64[]
    df."opening cost (\$)" = Float64[]
    df."fixed operating cost (\$)" = Float64[]
    df."variable operating cost (\$)" = Float64[]
    df."expansion cost (\$)" = Float64[]
    df."storage cost (\$)" = Float64[]

    plants = model.ext[:instance].plants
    T = 1:model.ext[:instance].time_horizon

    for p in plants, t in T
        operational = JuMP.value(model[:x][p.name, t]) > 0.5
        input = value(model[:z_input][p.name, t])
        processed = value(model[:z_process][p.name, t])

        # Calculate total stored amount across all input materials
        stored = sum(value(model[:z_storage][p.name, m.name, t]) for m in keys(p.input_mix))

        # Calculate total storage cost
        storage_cost = sum(
            p.storage_cost[m][t] * value(model[:z_storage][p.name, m.name, t])
            for m in keys(p.storage_cost)
        )

        var_operating_cost = input * p.capacities[1].var_operating_cost[t]
        opening_cost = 0
        curr_capacity = 0
        expansion_cost = 0
        fix_operating_cost = 0

        if value(model[:x][p.name, t]) > 0.5 && value(model[:x][p.name, t-1]) < 0.5
            opening_cost = p.capacities[1].opening_cost[t]
        end

        if operational
            curr_expansion = JuMP.value(model[:z_exp][p.name, t])
            prev_expansion = JuMP.value(model[:z_exp][p.name, t-1])
            curr_capacity = p.capacities[1].size + curr_expansion
            expansion_cost = R_expand(p, t) * (curr_expansion - prev_expansion)
            fix_operating_cost =
                p.capacities[1].fix_operating_cost[t] + R_fix_exp(p, t) * curr_expansion
        end

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
                "stored amount (tonne)" => _round(stored),
                "processed amount (tonne)" => _round(processed),
                "opening cost (\$)" => _round(opening_cost),
                "fixed operating cost (\$)" => _round(fix_operating_cost),
                "variable operating cost (\$)" => _round(var_operating_cost),
                "expansion cost (\$)" => _round(expansion_cost),
                "storage cost (\$)" => _round(storage_cost),
            ),
        )
    end
    return df
end

function plant_inputs_report(model)::DataFrame
    df = DataFrame()
    df."plant" = String[]
    df."latitude" = Float64[]
    df."longitude" = Float64[]
    df."input product" = String[]
    df."year" = Int[]
    df."amount received (tonne)" = Float64[]
    df."current storage level (tonne)" = Float64[]
    df."storage limit (tonne)" = Float64[]
    df."storage cost (\$)" = Float64[]

    plants = model.ext[:instance].plants
    T = 1:model.ext[:instance].time_horizon

    for p in plants, m in keys(p.input_mix), t in T
        amount_received = sum(
            value(model[:y][src.name, p.name, m.name, t])
            for (src, prod) in model.ext[:E_in][p] if prod == m
        )
        storage_level = value(model[:z_storage][p.name, m.name, t])
        storage_cost = p.storage_cost[m][t] * storage_level
        push!(
            df,
            Dict(
                "plant" => p.name,
                "latitude" => p.latitude,
                "longitude" => p.longitude,
                "input product" => m.name,
                "year" => t,
                "amount received (tonne)" => _round(amount_received),
                "current storage level (tonne)" => _round(storage_level),
                "storage limit (tonne)" => _round(p.storage_limit[m][t]),
                "storage cost (\$)" => _round(storage_cost),
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
    df."processed amount (tonne)" = Float64[]
    df."emission factor (tonne/tonne)" = Float64[]
    df."emissions amount (tonne)" = Float64[]

    plants = model.ext[:instance].plants
    T = 1:model.ext[:instance].time_horizon

    for p in plants, t in T, g in keys(p.emissions)
        processed_amount = JuMP.value(model[:z_process][p.name, t])
        processed_amount > 1e-3 || continue
        emissions = JuMP.value(model[:z_em_plant][g, p.name, t])
        emission_factor = p.emissions[g][t]
        push!(
            df,
            Dict(
                "plant" => p.name,
                "latitude" => p.latitude,
                "longitude" => p.longitude,
                "emission" => g,
                "year" => t,
                "processed amount (tonne)" => _round(processed_amount),
                "emission factor (tonne/tonne)" => _round(emission_factor),
                "emissions amount (tonne)" => _round(emissions),
            ),
        )
    end
    return df
end

write_plants_report(solution, filename) = CSV.write(filename, plants_report(solution))
write_plant_inputs_report(solution, filename) = CSV.write(filename, plant_inputs_report(solution))
write_plant_outputs_report(solution, filename) =
    CSV.write(filename, plant_outputs_report(solution))
write_plant_emissions_report(solution, filename) =
    CSV.write(filename, plant_emissions_report(solution))

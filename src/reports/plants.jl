# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using DataFrames
using CSV

function plants_report(model)::DataFrame
    df = DataFrame()
    df."plant" = String[]
    df."year" = Int[]
    df."operational?" = Bool[]
    df."input amount (tonne)" = Float64[]

    plants = model.ext[:instance].plants
    T = 1:model.ext[:instance].time_horizon

    for p in plants, t in T
        operational = JuMP.value(model[:x][p.name, t]) > 0.5
        input = value(model[:z_input][p.name, t])
        operational || continue
        push!(df, [p.name, t, operational, input])
    end
    return df
end

function plant_outputs_report(model)::DataFrame
    df = DataFrame()
    df."plant" = String[]
    df."output product" = String[]
    df."year" = Int[]
    df."amount produced (tonne)" = Float64[]
    df."amount disposed (tonne)" = Float64[]

    plants = model.ext[:instance].plants
    T = 1:model.ext[:instance].time_horizon

    for p in plants, m in keys(p.output), t in T
        produced = JuMP.value(model[:z_prod][p.name, m.name, t])
        disposed = JuMP.value(model[:z_disp][p.name, m.name, t])
        produced > 1e-3 || continue
        push!(df, [p.name, m.name, t, produced, disposed])
    end
    return df
end

write_plants_report(solution, filename) = CSV.write(filename, plants_report(solution))
write_plant_outputs_report(solution, filename) =
    CSV.write(filename, plant_outputs_report(solution))

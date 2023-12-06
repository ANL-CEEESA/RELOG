# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using DataFrames
using CSV

function centers_report(model)::DataFrame
    df = DataFrame()
    df."center" = String[]
    df."year" = Int[]
    df."input product" = String[]
    df."input amount (tonne)" = Float64[]
    df."revenue (\$)" = Float64[]
    df."operating cost (\$)" = Float64[]

    centers = model.ext[:instance].centers
    T = 1:model.ext[:instance].time_horizon
    E_in = model.ext[:E_in]

    for c in centers, t in T
        input_name = (c.input === nothing) ? "" : c.input.name
        input = value(model[:z_input][c.name, t])
        if isempty(E_in[c])
            revenue = 0
        else
            revenue = sum(
                c.revenue[t] * value(model[:y][p.name, c.name, m.name, t]) for
                (p, m) in E_in[c]
            )
        end
        push!(
            df,
            [
                c.name,
                t,
                input_name,
                _round(input),
                _round(revenue),
                _round(c.operating_cost[t]),
            ],
        )
    end
    return df
end

function center_outputs_report(model)::DataFrame
    df = DataFrame()
    df."center" = String[]
    df."output product" = String[]
    df."year" = Int[]
    df."amount collected (tonne)" = Float64[]
    df."amount disposed (tonne)" = Float64[]
    df."collection cost (\$)" = Float64[]
    df."disposal cost (\$)" = Float64[]

    centers = model.ext[:instance].centers
    T = 1:model.ext[:instance].time_horizon
    E_out = model.ext[:E_out]

    for c in centers, m in c.outputs, t in T
        collected = value(model[:z_collected][c.name, m.name, t])
        disposed = value(model[:z_disp][c.name, m.name, t])
        disposal_cost = c.disposal_cost[m][t] * disposed
        if isempty(E_out[c])
            collection_cost = 0
        else
            collection_cost = sum(
                c.collection_cost[m][t] * value(model[:y][c.name, p.name, m.name, t])
                for (p, m) in E_out[c]
            )
        end
        push!(
            df,
            [
                c.name,
                m.name,
                t,
                _round(collected),
                _round(disposed),
                _round(collection_cost),
                _round(disposal_cost),
            ],
        )
    end
    return df
end

write_centers_report(solution, filename) = CSV.write(filename, centers_report(solution))
write_center_outputs_report(solution, filename) =
    CSV.write(filename, center_outputs_report(solution))

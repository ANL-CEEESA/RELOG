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

    centers = model.ext[:instance].centers
    T = 1:model.ext[:instance].time_horizon

    for c in centers, t in T
        input_name = (c.input === nothing) ? "" : c.input.name
        input = round(value(model[:z_input][c.name, t]), digits = 3)
        push!(df, [c.name, t, input_name, input])
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

    centers = model.ext[:instance].centers
    T = 1:model.ext[:instance].time_horizon

    for c in centers, m in c.outputs, t in T
        collected = round(value(model[:z_collected][c.name, m.name, t]), digits = 3)
        disposed = round(value(model[:z_disp][c.name, m.name, t]), digits = 3)
        push!(df, [c.name, m.name, t, collected, disposed])
    end
    return df
end

write_centers_report(solution, filename) = CSV.write(filename, centers_report(solution))
write_center_outputs_report(solution, filename) =
    CSV.write(filename, center_outputs_report(solution))

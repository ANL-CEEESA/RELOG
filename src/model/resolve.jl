# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020-2021, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP

function resolve(model_old, filename::AbstractString; kwargs...)::OrderedDict
    @info "Reading $filename..."
    instance = RELOG.parsefile(filename)
    return resolve(model_old, instance; kwargs...)
end

function resolve(model_old, instance::Instance; optimizer = nothing)::OrderedDict
    milp_optimizer = lp_optimizer = optimizer
    if optimizer === nothing
        milp_optimizer = _get_default_milp_optimizer()
        lp_optimizer = _get_default_lp_optimizer()
    end

    @info "Building new graph..."
    graph = build_graph(instance)
    _print_graph_stats(instance, graph)

    @info "Building new optimization model..."
    model_new = RELOG.build_model(instance, graph, milp_optimizer)

    @info "Fixing decision variables..."
    _fix_plants!(model_old, model_new)
    JuMP.set_optimizer(model_new, lp_optimizer)

    @info "Optimizing MILP..."
    JuMP.optimize!(model_new)

    if !has_values(model_new)
        @warn("No solution available")
        return OrderedDict()
    end

    @info "Extracting solution..."
    solution = get_solution(model_new, marginal_costs = true)

    return solution
end

function _fix_plants!(model_old, model_new)::Nothing
    T = model_new[:instance].time

    # Fix open_plant variables
    for ((node_old, t), var_old) in model_old[:open_plant]
        value_old = JuMP.value(var_old)
        node_new = model_new[:graph].name_to_process_node_map[(
            node_old.location.plant_name,
            node_old.location.location_name,
        )]
        var_new = model_new[:open_plant][node_new, t]
        JuMP.unset_binary(var_new)
        JuMP.fix(var_new, value_old)
    end

    # Fix is_open variables
    for ((node_old, t), var_old) in model_old[:is_open]
        t > 0 || continue
        value_old = JuMP.value(var_old)
        node_new = model_new[:graph].name_to_process_node_map[(
            node_old.location.plant_name,
            node_old.location.location_name,
        )]
        var_new = model_new[:is_open][node_new, t]
        JuMP.unset_binary(var_new)
        JuMP.fix(var_new, value_old)
    end

    # Fix plant capacities
    for ((node_old, t), var_old) in model_old[:capacity]
        value_old = JuMP.value(var_old)
        node_new = model_new[:graph].name_to_process_node_map[(
            node_old.location.plant_name,
            node_old.location.location_name,
        )]
        var_new = model_new[:capacity][node_new, t]
        JuMP.delete_lower_bound(var_new)
        JuMP.delete_upper_bound(var_new)
        JuMP.fix(var_new, value_old)
    end

    # Fix plant expansion
    for ((node_old, t), var_old) in model_old[:expansion]
        t > 0 || continue
        value_old = JuMP.value(var_old)
        node_new = model_new[:graph].name_to_process_node_map[(
            node_old.location.plant_name,
            node_old.location.location_name,
        )]
        var_new = model_new[:expansion][node_new, t]
        JuMP.delete_lower_bound(var_new)
        JuMP.delete_upper_bound(var_new)
        JuMP.fix(var_new, value_old)
    end
end

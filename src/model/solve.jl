# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP, LinearAlgebra, Geodesy, ProgressBars, Printf, DataStructures, HiGHS

function _get_default_milp_optimizer()
    return optimizer_with_attributes(HiGHS.Optimizer)
end

function _get_default_lp_optimizer()
    return optimizer_with_attributes(HiGHS.Optimizer)
end


function _print_graph_stats(instance::Instance, graph::Graph)::Nothing
    @info @sprintf("%12d time periods", instance.time)
    @info @sprintf("%12d process nodes", length(graph.process_nodes))
    @info @sprintf("%12d shipping nodes (plant)", length(graph.plant_shipping_nodes))
    @info @sprintf(
        "%12d shipping nodes (collection)",
        length(graph.collection_shipping_nodes)
    )
    @info @sprintf("%12d arcs", length(graph.arcs))
    return
end

function solve(
    instance::Instance;
    optimizer = nothing,
    lp_optimizer = nothing,
    output = nothing,
    marginal_costs = true,
    return_model = false,
    graph = nothing,
)

    if lp_optimizer == nothing
        if optimizer == nothing
            # If neither is provided, use default LP optimizer.
            lp_optimizer = _get_default_lp_optimizer()
        else
            # If only MIP optimizer is provided, use it as
            # LP solver too.
            lp_optimizer = optimizer
        end
    end

    if optimizer == nothing
        optimizer = _get_default_milp_optimizer()
    end


    @info "Building graph..."
    if graph === nothing
        graph = RELOG.build_graph(instance)
    end
    _print_graph_stats(instance, graph)

    @info "Building optimization model..."
    model = RELOG.build_model(instance, graph, optimizer)

    @info "Optimizing MILP..."
    JuMP.optimize!(model)

    if !has_values(model)
        error("No solution available")
    end

    if marginal_costs
        @info "Re-optimizing with integer variables fixed..."
        all_vars = JuMP.all_variables(model)
        vals = OrderedDict(var => JuMP.value(var) for var in all_vars)
        JuMP.set_optimizer(model, lp_optimizer)
        for var in all_vars
            if JuMP.is_binary(var)
                JuMP.unset_binary(var)
                JuMP.fix(var, vals[var])
            end
        end
        JuMP.optimize!(model)
    end

    @info "Extracting solution..."
    solution = get_solution(model, marginal_costs = marginal_costs)

    if output != nothing
        write(solution, output)
    end

    if return_model
        return solution, model
    else
        return solution
    end
end

function solve(filename::AbstractString; heuristic = false, kwargs...)
    @info "Reading $filename..."
    instance = RELOG.parsefile(filename)
    if heuristic && instance.time > 1
        @info "Solving single-period version..."
        compressed = _compress(instance)
        csol, _ = solve(
            compressed;
            return_model = true,
            output = nothing,
            marginal_costs = false,
            kwargs...,
        )
        @info "Filtering candidate locations..."
        selected_pairs = []
        for (plant_name, plant_dict) in csol["Plants"]
            for (location_name, location_dict) in plant_dict
                push!(selected_pairs, (plant_name, location_name))
            end
        end
        filtered_plants = []
        for p in instance.plants
            if (p.plant_name, p.location_name) in selected_pairs
                push!(filtered_plants, p)
            end
        end
        instance.plants = filtered_plants
        @info "Solving original version..."
    end
    sol = solve(instance; kwargs...)
    return sol
end

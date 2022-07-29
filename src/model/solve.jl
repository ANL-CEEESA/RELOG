# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP, LinearAlgebra, Geodesy, Cbc, Clp, ProgressBars, Printf, DataStructures

function _get_default_milp_optimizer()
    return optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0)
end

function _get_default_lp_optimizer()
    return optimizer_with_attributes(Clp.Optimizer, "LogLevel" => 0)
end


function _print_graph_stats(instance::Instance, graph::Graph)::Nothing
    @info @sprintf("    %12d time periods", instance.time)
    @info @sprintf("    %12d process nodes", length(graph.process_nodes))
    @info @sprintf("    %12d shipping nodes (plant)", length(graph.plant_shipping_nodes))
    @info @sprintf(
        "    %12d shipping nodes (collection)",
        length(graph.collection_shipping_nodes)
    )
    @info @sprintf("    %12d arcs", length(graph.arcs))
    return
end

function solve(
    instance::Instance;
    optimizer = nothing,
    output = nothing,
    graph = nothing,
    marginal_costs = true,
    return_model = false,
)

    milp_optimizer = lp_optimizer = optimizer
    if optimizer === nothing
        milp_optimizer = _get_default_milp_optimizer()
        lp_optimizer = _get_default_lp_optimizer()
    end

    if graph === nothing
        @info "Building graph..."
        graph = RELOG.build_graph(instance)
        _print_graph_stats(instance, graph)
    end

    @info "Building optimization model..."
    model = RELOG.build_model(instance, graph, milp_optimizer)

    @info "Optimizing MILP..."
    JuMP.optimize!(model)
    if !has_values(model)
        error("No solution available")
    end
    solution = get_solution(model, marginal_costs = false)

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
        if has_values(model)
            @info "Extracting solution..."
            solution = get_solution(model, marginal_costs = true)
        else
            @warn "Error computing marginal costs. Ignoring."
        end
    end

    if output !== nothing
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
        csol, model = solve(compressed; output = nothing, marginal_costs = false, return_model = true, kwargs...)
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

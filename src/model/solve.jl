# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP, LinearAlgebra, Geodesy, HiGHS, ProgressBars, Printf, DataStructures

function _get_default_milp_optimizer()
    return optimizer_with_attributes(HiGHS.Optimizer)
end

function _get_default_lp_optimizer()
    return optimizer_with_attributes(HiGHS.Optimizer)
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

function solve_stochastic(;
    scenarios::Vector{String},
    probs::Vector{Float64},
    optimizer,
    method=:ef,
    tol=0.1,
)
    @info "Reading instance files..."
    instances = [parsefile(sc) for sc in scenarios]

    @info "Building graphs..."
    graphs = [build_graph(inst) for inst in instances]

    @info "Building stochastic model..."
    sp = RELOG.build_model(instances[1], graphs, probs; optimizer, method, tol)

    @info "Optimizing stochastic model..."
    optimize!(sp)

    @info "Extracting solution..."
    solutions = [
        get_solution(instances[i], graphs[i], sp, i)
        for i in 1:length(instances)
    ]

    return solutions
end

function solve(
    instance::Instance;
    optimizer=HiGHS.Optimizer,
    marginal_costs=true,
    return_model=false
)
    @info "Building graph..."
    graph = RELOG.build_graph(instance)
    _print_graph_stats(instance, graph)

    @info "Building model..."
    model = RELOG.build_model(instance, [graph], [1.0]; optimizer)

    @info "Optimizing model..."
    optimize!(model)
    if !has_values(model)
        error("No solution available")
    end

    @info "Extracting solution..."
    solution = get_solution(instance, graph, model, 1)

    if marginal_costs
        @info "Re-optimizing with integer variables fixed..."
        open_plant_vals = value.(model[1, :open_plant])
        is_open_vals = value.(model[1, :is_open])

        for n in 1:length(graph.process_nodes), t in 1:instance.time
            unset_binary(model[1, :open_plant][n, t])
            unset_binary(model[1, :is_open][n, t])
            fix(
                model[1, :open_plant][n, t],
                open_plant_vals[n, t]
            )
            fix(
                model[1, :is_open][n, t],
                is_open_vals[n, t]
            )
            
        end
        optimize!(model)
        if has_values(model)
            @info "Extracting solution..."
            solution = get_solution(instance, graph, model, 1, marginal_costs=true)
        else
            @warn "Error computing marginal costs. Ignoring."
        end
    end

    if return_model
        return solution, model
    else
        return solution
    end
end

function solve(filename::AbstractString; heuristic=false, kwargs...)
    @info "Reading $filename..."
    instance = RELOG.parsefile(filename)
    if heuristic && instance.time > 1
        @info "Solving single-period version..."
        compressed = _compress(instance)
        csol, model = solve(compressed; marginal_costs=false, return_model=true, kwargs...)
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

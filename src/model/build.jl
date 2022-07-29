# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP, LinearAlgebra, Geodesy, Cbc, Clp, ProgressBars, Printf, DataStructures

function build_model(instance::Instance, graph::Graph, optimizer)::JuMP.Model
    model = Model(optimizer)
    model[:instance] = instance
    model[:graph] = graph
    create_vars!(model)
    create_objective_function!(model)
    create_shipping_node_constraints!(model)
    create_process_node_constraints!(model)
    return model
end


function create_vars!(model::JuMP.Model)
    graph, T = model[:graph], model[:instance].time
    model[:flow] =
        Dict((a, t) => @variable(model, lower_bound = 0) for a in graph.arcs, t = 1:T)
    model[:plant_dispose] = Dict(
        (n, t) => @variable(
            model,
            lower_bound = 0,
            upper_bound = n.location.disposal_limit[n.product][t],
        ) for n in values(graph.plant_shipping_nodes), t = 1:T
    )
    model[:collection_dispose] = Dict(
        (n, t) => @variable(
            model,
            lower_bound = 0,
            upper_bound = n.location.amount[t],
        ) for
        n in values(graph.collection_shipping_nodes), t = 1:T
    )
    model[:store] = Dict(
        (n, t) =>
            @variable(model, lower_bound = 0, upper_bound = n.location.storage_limit)
        for n in values(graph.process_nodes), t = 1:T
    )
    model[:process] = Dict(
        (n, t) => @variable(model, lower_bound = 0) for
        n in values(graph.process_nodes), t = 1:T
    )
    model[:open_plant] = Dict(
        (n, t) => @variable(model, binary = true) for n in values(graph.process_nodes),
        t = 1:T
    )
    model[:is_open] = Dict(
        (n, t) => @variable(model, binary = true) for n in values(graph.process_nodes),
        t = 1:T
    )
    model[:capacity] = Dict(
        (n, t) => @variable(
            model,
            lower_bound = 0,
            upper_bound = n.location.sizes[2].capacity
        ) for n in values(graph.process_nodes), t = 1:T
    )
    model[:expansion] = Dict(
        (n, t) => @variable(
            model,
            lower_bound = 0,
            upper_bound = n.location.sizes[2].capacity - n.location.sizes[1].capacity
        ) for n in values(graph.process_nodes), t = 1:T
    )
end


function slope_open(plant, t)
    if plant.sizes[2].capacity <= plant.sizes[1].capacity
        0.0
    else
        (plant.sizes[2].opening_cost[t] - plant.sizes[1].opening_cost[t]) /
        (plant.sizes[2].capacity - plant.sizes[1].capacity)
    end
end

function slope_fix_oper_cost(plant, t)
    if plant.sizes[2].capacity <= plant.sizes[1].capacity
        0.0
    else
        (plant.sizes[2].fixed_operating_cost[t] - plant.sizes[1].fixed_operating_cost[t]) /
        (plant.sizes[2].capacity - plant.sizes[1].capacity)
    end
end

function create_objective_function!(model::JuMP.Model)
    graph, T = model[:graph], model[:instance].time
    obj = AffExpr(0.0)

    # Process node costs
    for n in values(graph.process_nodes), t = 1:T

        # Transportation costs
        for a in n.incoming_arcs
            c = n.location.input.transportation_cost[t] * a.values["distance"]
            add_to_expression!(obj, c, model[:flow][a, t])
        end

        # Opening costs
        add_to_expression!(
            obj,
            n.location.sizes[1].opening_cost[t],
            model[:open_plant][n, t],
        )

        # Fixed operating costs (base)
        add_to_expression!(
            obj,
            n.location.sizes[1].fixed_operating_cost[t],
            model[:is_open][n, t],
        )

        # Fixed operating costs (expansion)
        add_to_expression!(obj, slope_fix_oper_cost(n.location, t), model[:expansion][n, t])

        # Processing costs
        add_to_expression!(
            obj,
            n.location.sizes[1].variable_operating_cost[t],
            model[:process][n, t],
        )

        # Storage costs
        add_to_expression!(obj, n.location.storage_cost[t], model[:store][n, t])

        # Expansion costs
        if t < T
            add_to_expression!(
                obj,
                slope_open(n.location, t) - slope_open(n.location, t + 1),
                model[:expansion][n, t],
            )
        else
            add_to_expression!(obj, slope_open(n.location, t), model[:expansion][n, t])
        end
    end

    # Plant shipping node costs
    for n in values(graph.plant_shipping_nodes), t = 1:T
        # Disposal costs
        add_to_expression!(
            obj,
            n.location.disposal_cost[n.product][t],
            model[:plant_dispose][n, t],
        )
    end

    # Collection shipping node costs
    for n in values(graph.collection_shipping_nodes), t = 1:T
        # Disposal costs
        add_to_expression!(
            obj,
            n.location.product.disposal_cost[t],
            model[:collection_dispose][n, t],
        )
    end

    @objective(model, Min, obj)
end


function create_shipping_node_constraints!(model::JuMP.Model)
    graph, T = model[:graph], model[:instance].time
    model[:eq_balance] = OrderedDict()
    for t = 1:T
        # Collection centers
        for n in graph.collection_shipping_nodes
            model[:eq_balance][n, t] = @constraint(
                model,
                sum(model[:flow][a, t] for a in n.outgoing_arcs) ==
                n.location.amount[t] - model[:collection_dispose][n, t],
            )
        end
        for prod in model[:instance].products
            if isempty(prod.collection_centers)
                continue
            end
            expr = AffExpr()
            for center in prod.collection_centers
                n = graph.collection_center_to_node[center]
                add_to_expression!(expr, model[:collection_dispose][n, t])
            end
            @constraint(model, expr <= prod.disposal_limit[t])
        end

        # Plants
        for n in graph.plant_shipping_nodes
            @constraint(
                model,
                sum(model[:flow][a, t] for a in n.incoming_arcs) ==
                sum(model[:flow][a, t] for a in n.outgoing_arcs) +
                model[:plant_dispose][n, t]
            )
        end
    end

end


function create_process_node_constraints!(model::JuMP.Model)
    graph, T = model[:graph], model[:instance].time

    for t = 1:T, n in graph.process_nodes
        input_sum = AffExpr(0.0)
        for a in n.incoming_arcs
            add_to_expression!(input_sum, 1.0, model[:flow][a, t])
        end

        # Output amount is implied by amount processed
        for a in n.outgoing_arcs
            @constraint(
                model,
                model[:flow][a, t] == a.values["weight"] * model[:process][n, t]
            )
        end

        # If plant is closed, capacity is zero
        @constraint(
            model,
            model[:capacity][n, t] <= n.location.sizes[2].capacity * model[:is_open][n, t]
        )

        # If plant is open, capacity is greater than base
        @constraint(
            model,
            model[:capacity][n, t] >= n.location.sizes[1].capacity * model[:is_open][n, t]
        )

        # Capacity is linked to expansion
        @constraint(
            model,
            model[:capacity][n, t] <=
            n.location.sizes[1].capacity + model[:expansion][n, t]
        )

        # Can only process up to capacity
        @constraint(model, model[:process][n, t] <= model[:capacity][n, t])

        if t > 1
            # Plant capacity can only increase over time
            @constraint(model, model[:capacity][n, t] >= model[:capacity][n, t-1])
            @constraint(model, model[:expansion][n, t] >= model[:expansion][n, t-1])
        end

        # Amount received equals amount processed plus stored
        store_in = 0
        if t > 1
            store_in = model[:store][n, t-1]
        end
        if t == T
            @constraint(model, model[:store][n, t] == 0)
        end
        @constraint(
            model,
            input_sum + store_in == model[:store][n, t] + model[:process][n, t]
        )


        # Plant is currently open if it was already open in the previous time period or
        # if it was built just now
        if t > 1
            @constraint(
                model,
                model[:is_open][n, t] == model[:is_open][n, t-1] + model[:open_plant][n, t]
            )
        else
            @constraint(model, model[:is_open][n, t] == model[:open_plant][n, t])
        end

        # Plant can only be opened during building period
        if t ∉ model[:instance].building_period
            @constraint(model, model[:open_plant][n, t] == 0)
        end
    end
end

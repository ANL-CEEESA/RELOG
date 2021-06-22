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
    model[:dispose] = Dict(
        (n, t) => @variable(
            model,
            lower_bound = 0,
            upper_bound = n.location.disposal_limit[n.product][t]
        ) for n in values(graph.plant_shipping_nodes), t = 1:T
    )
    model[:store] = Dict(
        (n, t) =>
            @variable(model, lower_bound = 0, upper_bound = n.location.storage_limit) for
        n in values(graph.process_nodes), t = 1:T
    )
    model[:process] = Dict(
        (n, t) => @variable(model, lower_bound = 0) for n in values(graph.process_nodes),
        t = 1:T
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
        (n, t) =>
            @variable(model, lower_bound = 0, upper_bound = n.location.sizes[2].capacity)
        for n in values(graph.process_nodes), t = 1:T
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

        # Transportation and variable operating costs
        for a in n.incoming_arcs
            c = n.location.input.transportation_cost[t] * a.values["distance"]
            add_to_expression!(obj, c, model[:flow][a, t])
        end

        # Opening costs
        add_to_expression!(obj, n.location.sizes[1].opening_cost[t], model[:open_plant][n, t])

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

    # Shipping node costs
    for n in values(graph.plant_shipping_nodes), t = 1:T

        # Disposal costs
        add_to_expression!(obj, n.location.disposal_cost[n.product][t], model[:dispose][n, t])
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
                sum(model[:flow][a, t] for a in n.outgoing_arcs) == n.location.amount[t]
            )
        end

        # Plants
        for n in graph.plant_shipping_nodes
            @constraint(
                model,
                sum(model[:flow][a, t] for a in n.incoming_arcs) ==
                sum(model[:flow][a, t] for a in n.outgoing_arcs) + model[:dispose][n, t]
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
            @constraint(model, model[:flow][a, t] == a.values["weight"] * model[:process][n, t])
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
            model[:capacity][n, t] <= n.location.sizes[1].capacity + model[:expansion][n, t]
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
        @constraint(model, input_sum + store_in == model[:store][n, t] + model[:process][n, t])


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

default_milp_optimizer = optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0)
default_lp_optimizer = optimizer_with_attributes(Clp.Optimizer, "LogLevel" => 0)

function solve(
    instance::Instance;
    optimizer = nothing,
    output = nothing,
    marginal_costs = true,
)

    milp_optimizer = lp_optimizer = optimizer
    if optimizer == nothing
        milp_optimizer = default_milp_optimizer
        lp_optimizer = default_lp_optimizer
    end

    @info "Building graph..."
    graph = RELOG.build_graph(instance)
    @info @sprintf("    %12d time periods", instance.time)
    @info @sprintf("    %12d process nodes", length(graph.process_nodes))
    @info @sprintf("    %12d shipping nodes (plant)", length(graph.plant_shipping_nodes))
    @info @sprintf(
        "    %12d shipping nodes (collection)",
        length(graph.collection_shipping_nodes)
    )
    @info @sprintf("    %12d arcs", length(graph.arcs))

    @info "Building optimization model..."
    model = RELOG.build_model(instance, graph, milp_optimizer)

    @info "Optimizing MILP..."
    JuMP.optimize!(model)

    if !has_values(model)
        @warn "No solution available"
        return OrderedDict()
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

    return solution
end

function solve(filename::AbstractString; heuristic = false, kwargs...)
    @info "Reading $filename..."
    instance = RELOG.parsefile(filename)
    if heuristic && instance.time > 1
        @info "Solving single-period version..."
        compressed = _compress(instance)
        csol = solve(compressed; output = nothing, marginal_costs = false, kwargs...)
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


function get_solution(model::JuMP.Model; marginal_costs = true)
    graph, instance = model[:graph], model[:instance]
    T = instance.time

    output = OrderedDict(
        "Plants" => OrderedDict(),
        "Products" => OrderedDict(),
        "Costs" => OrderedDict(
            "Fixed operating (\$)" => zeros(T),
            "Variable operating (\$)" => zeros(T),
            "Opening (\$)" => zeros(T),
            "Transportation (\$)" => zeros(T),
            "Disposal (\$)" => zeros(T),
            "Expansion (\$)" => zeros(T),
            "Storage (\$)" => zeros(T),
            "Total (\$)" => zeros(T),
        ),
        "Energy" =>
            OrderedDict("Plants (GJ)" => zeros(T), "Transportation (GJ)" => zeros(T)),
        "Emissions" => OrderedDict(
            "Plants (tonne)" => OrderedDict(),
            "Transportation (tonne)" => OrderedDict(),
        ),
    )

    plant_to_process_node = OrderedDict(n.location => n for n in graph.process_nodes)
    plant_to_shipping_nodes = OrderedDict()
    for p in instance.plants
        plant_to_shipping_nodes[p] = []
        for a in plant_to_process_node[p].outgoing_arcs
            push!(plant_to_shipping_nodes[p], a.dest)
        end
    end

    # Products
    if marginal_costs
        for n in graph.collection_shipping_nodes
            location_dict = OrderedDict{Any,Any}(
                "Marginal cost (\$/tonne)" => [
                    round(abs(JuMP.shadow_price(model[:eq_balance][n, t])), digits = 2) for t = 1:T
                ],
            )
            if n.product.name ∉ keys(output["Products"])
                output["Products"][n.product.name] = OrderedDict()
            end
            output["Products"][n.product.name][n.location.name] = location_dict
        end
    end

    # Plants
    for plant in instance.plants
        skip_plant = true
        process_node = plant_to_process_node[plant]
        plant_dict = OrderedDict{Any,Any}(
            "Input" => OrderedDict(),
            "Output" =>
                OrderedDict("Send" => OrderedDict(), "Dispose" => OrderedDict()),
            "Input product" => plant.input.name,
            "Total input (tonne)" => [0.0 for t = 1:T],
            "Total output" => OrderedDict(),
            "Latitude (deg)" => plant.latitude,
            "Longitude (deg)" => plant.longitude,
            "Capacity (tonne)" =>
                [JuMP.value(model[:capacity][process_node, t]) for t = 1:T],
            "Opening cost (\$)" => [
                JuMP.value(model[:open_plant][process_node, t]) *
                plant.sizes[1].opening_cost[t] for t = 1:T
            ],
            "Fixed operating cost (\$)" => [
                JuMP.value(model[:is_open][process_node, t]) *
                plant.sizes[1].fixed_operating_cost[t] +
                JuMP.value(model[:expansion][process_node, t]) *
                slope_fix_oper_cost(plant, t) for t = 1:T
            ],
            "Expansion cost (\$)" => [
                (
                    if t == 1
                        slope_open(plant, t) * JuMP.value(model[:expansion][process_node, t])
                    else
                        slope_open(plant, t) * (
                            JuMP.value(model[:expansion][process_node, t]) -
                            JuMP.value(model[:expansion][process_node, t-1])
                        )
                    end
                ) for t = 1:T
            ],
            "Process (tonne)" =>
                [JuMP.value(model[:process][process_node, t]) for t = 1:T],
            "Variable operating cost (\$)" => [
                JuMP.value(model[:process][process_node, t]) *
                plant.sizes[1].variable_operating_cost[t] for t = 1:T
            ],
            "Storage (tonne)" => [JuMP.value(model[:store][process_node, t]) for t = 1:T],
            "Storage cost (\$)" => [
                JuMP.value(model[:store][process_node, t]) * plant.storage_cost[t] for
                t = 1:T
            ],
        )
        output["Costs"]["Fixed operating (\$)"] += plant_dict["Fixed operating cost (\$)"]
        output["Costs"]["Variable operating (\$)"] +=
            plant_dict["Variable operating cost (\$)"]
        output["Costs"]["Opening (\$)"] += plant_dict["Opening cost (\$)"]
        output["Costs"]["Expansion (\$)"] += plant_dict["Expansion cost (\$)"]
        output["Costs"]["Storage (\$)"] += plant_dict["Storage cost (\$)"]

        # Inputs
        for a in process_node.incoming_arcs
            vals = [JuMP.value(model[:flow][a, t]) for t = 1:T]
            if sum(vals) <= 1e-3
                continue
            end
            skip_plant = false
            dict = OrderedDict{Any,Any}(
                "Amount (tonne)" => vals,
                "Distance (km)" => a.values["distance"],
                "Latitude (deg)" => a.source.location.latitude,
                "Longitude (deg)" => a.source.location.longitude,
                "Transportation cost (\$)" =>
                    a.source.product.transportation_cost .* vals .* a.values["distance"],
                "Transportation energy (J)" =>
                    vals .* a.values["distance"] .* a.source.product.transportation_energy,
                "Emissions (tonne)" => OrderedDict(),
            )
            emissions_dict = output["Emissions"]["Transportation (tonne)"]
            for (em_name, em_values) in a.source.product.transportation_emissions
                dict["Emissions (tonne)"][em_name] =
                    em_values .* dict["Amount (tonne)"] .* a.values["distance"]
                if em_name ∉ keys(emissions_dict)
                    emissions_dict[em_name] = zeros(T)
                end
                emissions_dict[em_name] += dict["Emissions (tonne)"][em_name]
            end
            if a.source.location isa CollectionCenter
                plant_name = "Origin"
                location_name = a.source.location.name
            else
                plant_name = a.source.location.plant_name
                location_name = a.source.location.location_name
            end

            if plant_name ∉ keys(plant_dict["Input"])
                plant_dict["Input"][plant_name] = OrderedDict()
            end
            plant_dict["Input"][plant_name][location_name] = dict
            plant_dict["Total input (tonne)"] += vals
            output["Costs"]["Transportation (\$)"] += dict["Transportation cost (\$)"]
            output["Energy"]["Transportation (GJ)"] +=
                dict["Transportation energy (J)"] / 1e9
        end

        plant_dict["Energy (GJ)"] = plant_dict["Total input (tonne)"] .* plant.energy
        output["Energy"]["Plants (GJ)"] += plant_dict["Energy (GJ)"]

        plant_dict["Emissions (tonne)"] = OrderedDict()
        emissions_dict = output["Emissions"]["Plants (tonne)"]
        for (em_name, em_values) in plant.emissions
            plant_dict["Emissions (tonne)"][em_name] =
                em_values .* plant_dict["Total input (tonne)"]
            if em_name ∉ keys(emissions_dict)
                emissions_dict[em_name] = zeros(T)
            end
            emissions_dict[em_name] += plant_dict["Emissions (tonne)"][em_name]
        end

        # Outputs
        for shipping_node in plant_to_shipping_nodes[plant]
            product_name = shipping_node.product.name
            plant_dict["Total output"][product_name] = zeros(T)
            plant_dict["Output"]["Send"][product_name] = product_dict = OrderedDict()

            disposal_amount = [JuMP.value(model[:dispose][shipping_node, t]) for t = 1:T]
            if sum(disposal_amount) > 1e-5
                skip_plant = false
                plant_dict["Output"]["Dispose"][product_name] =
                    disposal_dict = OrderedDict()
                disposal_dict["Amount (tonne)"] =
                    [JuMP.value(model[:dispose][shipping_node, t]) for t = 1:T]
                disposal_dict["Cost (\$)"] = [
                    disposal_dict["Amount (tonne)"][t] *
                    plant.disposal_cost[shipping_node.product][t] for t = 1:T
                ]
                plant_dict["Total output"][product_name] += disposal_amount
                output["Costs"]["Disposal (\$)"] += disposal_dict["Cost (\$)"]
            end

            for a in shipping_node.outgoing_arcs
                vals = [JuMP.value(model[:flow][a, t]) for t = 1:T]
                if sum(vals) <= 1e-3
                    continue
                end
                skip_plant = false
                dict = OrderedDict(
                    "Amount (tonne)" => vals,
                    "Distance (km)" => a.values["distance"],
                    "Latitude (deg)" => a.dest.location.latitude,
                    "Longitude (deg)" => a.dest.location.longitude,
                )
                if a.dest.location.plant_name ∉ keys(product_dict)
                    product_dict[a.dest.location.plant_name] = OrderedDict()
                end
                product_dict[a.dest.location.plant_name][a.dest.location.location_name] =
                    dict
                plant_dict["Total output"][product_name] += vals
            end
        end

        if !skip_plant
            if plant.plant_name ∉ keys(output["Plants"])
                output["Plants"][plant.plant_name] = OrderedDict()
            end
            output["Plants"][plant.plant_name][plant.location_name] = plant_dict
        end
    end

    output["Costs"]["Total (\$)"] = sum(values(output["Costs"]))
    return output
end

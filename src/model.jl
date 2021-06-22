# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP, LinearAlgebra, Geodesy, Cbc, Clp, ProgressBars, Printf, DataStructures


mutable struct ManufacturingModel
    mip::JuMP.Model
    vars::DotDict
    eqs::DotDict
    instance::Instance
    graph::Graph
end


function build_model(instance::Instance, graph::Graph, optimizer)::ManufacturingModel
    model = ManufacturingModel(Model(optimizer), DotDict(), DotDict(), instance, graph)
    create_vars!(model)
    create_objective_function!(model)
    create_shipping_node_constraints!(model)
    create_process_node_constraints!(model)
    return model
end


function create_vars!(model::ManufacturingModel)
    mip, vars, graph, T = model.mip, model.vars, model.graph, model.instance.time

    vars.flow = Dict((a, t) => @variable(mip, lower_bound = 0) for a in graph.arcs, t = 1:T)

    vars.dispose = Dict(
        (n, t) => @variable(
            mip,
            lower_bound = 0,
            upper_bound = n.location.disposal_limit[n.product][t]
        ) for n in values(graph.plant_shipping_nodes), t = 1:T
    )

    vars.store = Dict(
        (n, t) =>
            @variable(mip, lower_bound = 0, upper_bound = n.location.storage_limit) for
        n in values(graph.process_nodes), t = 1:T
    )

    vars.process = Dict(
        (n, t) => @variable(mip, lower_bound = 0) for n in values(graph.process_nodes),
        t = 1:T
    )

    vars.open_plant = Dict(
        (n, t) => @variable(mip, binary = true) for n in values(graph.process_nodes),
        t = 1:T
    )

    vars.is_open = Dict(
        (n, t) => @variable(mip, binary = true) for n in values(graph.process_nodes),
        t = 1:T
    )

    vars.capacity = Dict(
        (n, t) =>
            @variable(mip, lower_bound = 0, upper_bound = n.location.sizes[2].capacity)
        for n in values(graph.process_nodes), t = 1:T
    )

    vars.expansion = Dict(
        (n, t) => @variable(
            mip,
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

function create_objective_function!(model::ManufacturingModel)
    mip, vars, graph, T = model.mip, model.vars, model.graph, model.instance.time
    obj = AffExpr(0.0)

    # Process node costs
    for n in values(graph.process_nodes), t = 1:T

        # Transportation and variable operating costs
        for a in n.incoming_arcs
            c = n.location.input.transportation_cost[t] * a.values["distance"]
            add_to_expression!(obj, c, vars.flow[a, t])
        end

        # Opening costs
        add_to_expression!(obj, n.location.sizes[1].opening_cost[t], vars.open_plant[n, t])

        # Fixed operating costs (base)
        add_to_expression!(
            obj,
            n.location.sizes[1].fixed_operating_cost[t],
            vars.is_open[n, t],
        )

        # Fixed operating costs (expansion)
        add_to_expression!(obj, slope_fix_oper_cost(n.location, t), vars.expansion[n, t])

        # Processing costs
        add_to_expression!(
            obj,
            n.location.sizes[1].variable_operating_cost[t],
            vars.process[n, t],
        )

        # Storage costs
        add_to_expression!(obj, n.location.storage_cost[t], vars.store[n, t])

        # Expansion costs
        if t < T
            add_to_expression!(
                obj,
                slope_open(n.location, t) - slope_open(n.location, t + 1),
                vars.expansion[n, t],
            )
        else
            add_to_expression!(obj, slope_open(n.location, t), vars.expansion[n, t])
        end
    end

    # Shipping node costs
    for n in values(graph.plant_shipping_nodes), t = 1:T

        # Disposal costs
        add_to_expression!(obj, n.location.disposal_cost[n.product][t], vars.dispose[n, t])
    end

    @objective(mip, Min, obj)
end


function create_shipping_node_constraints!(model::ManufacturingModel)
    mip, vars, graph, T = model.mip, model.vars, model.graph, model.instance.time
    eqs = model.eqs

    eqs.balance = OrderedDict()

    for t = 1:T
        # Collection centers
        for n in graph.collection_shipping_nodes
            eqs.balance[n, t] = @constraint(
                mip,
                sum(vars.flow[a, t] for a in n.outgoing_arcs) == n.location.amount[t]
            )
        end

        # Plants
        for n in graph.plant_shipping_nodes
            @constraint(
                mip,
                sum(vars.flow[a, t] for a in n.incoming_arcs) ==
                sum(vars.flow[a, t] for a in n.outgoing_arcs) + vars.dispose[n, t]
            )
        end
    end

end


function create_process_node_constraints!(model::ManufacturingModel)
    mip, vars, graph, T = model.mip, model.vars, model.graph, model.instance.time

    for t = 1:T, n in graph.process_nodes
        input_sum = AffExpr(0.0)
        for a in n.incoming_arcs
            add_to_expression!(input_sum, 1.0, vars.flow[a, t])
        end

        # Output amount is implied by amount processed
        for a in n.outgoing_arcs
            @constraint(mip, vars.flow[a, t] == a.values["weight"] * vars.process[n, t])
        end

        # If plant is closed, capacity is zero
        @constraint(
            mip,
            vars.capacity[n, t] <= n.location.sizes[2].capacity * vars.is_open[n, t]
        )

        # If plant is open, capacity is greater than base
        @constraint(
            mip,
            vars.capacity[n, t] >= n.location.sizes[1].capacity * vars.is_open[n, t]
        )

        # Capacity is linked to expansion
        @constraint(
            mip,
            vars.capacity[n, t] <= n.location.sizes[1].capacity + vars.expansion[n, t]
        )

        # Can only process up to capacity
        @constraint(mip, vars.process[n, t] <= vars.capacity[n, t])

        if t > 1
            # Plant capacity can only increase over time
            @constraint(mip, vars.capacity[n, t] >= vars.capacity[n, t-1])
            @constraint(mip, vars.expansion[n, t] >= vars.expansion[n, t-1])
        end

        # Amount received equals amount processed plus stored
        store_in = 0
        if t > 1
            store_in = vars.store[n, t-1]
        end
        if t == T
            @constraint(mip, vars.store[n, t] == 0)
        end
        @constraint(mip, input_sum + store_in == vars.store[n, t] + vars.process[n, t])


        # Plant is currently open if it was already open in the previous time period or
        # if it was built just now
        if t > 1
            @constraint(
                mip,
                vars.is_open[n, t] == vars.is_open[n, t-1] + vars.open_plant[n, t]
            )
        else
            @constraint(mip, vars.is_open[n, t] == vars.open_plant[n, t])
        end

        # Plant can only be opened during building period
        if t ∉ model.instance.building_period
            @constraint(mip, vars.open_plant[n, t] == 0)
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
    JuMP.optimize!(model.mip)

    if !has_values(model.mip)
        @warn "No solution available"
        return OrderedDict()
    end

    if marginal_costs
        @info "Re-optimizing with integer variables fixed..."
        all_vars = JuMP.all_variables(model.mip)
        vals = OrderedDict(var => JuMP.value(var) for var in all_vars)
        JuMP.set_optimizer(model.mip, lp_optimizer)
        for var in all_vars
            if JuMP.is_binary(var)
                JuMP.unset_binary(var)
                JuMP.fix(var, vals[var])
            end
        end
        JuMP.optimize!(model.mip)
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


function get_solution(model::ManufacturingModel; marginal_costs = true)
    mip, vars, eqs, graph, instance =
        model.mip, model.vars, model.eqs, model.graph, model.instance
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
                    round(abs(JuMP.shadow_price(eqs.balance[n, t])), digits = 2) for
                    t = 1:T
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
                [JuMP.value(vars.capacity[process_node, t]) for t = 1:T],
            "Opening cost (\$)" => [
                JuMP.value(vars.open_plant[process_node, t]) *
                plant.sizes[1].opening_cost[t] for t = 1:T
            ],
            "Fixed operating cost (\$)" => [
                JuMP.value(vars.is_open[process_node, t]) *
                plant.sizes[1].fixed_operating_cost[t] +
                JuMP.value(vars.expansion[process_node, t]) * slope_fix_oper_cost(plant, t) for t = 1:T
            ],
            "Expansion cost (\$)" => [
                (
                    if t == 1
                        slope_open(plant, t) * JuMP.value(vars.expansion[process_node, t])
                    else
                        slope_open(plant, t) * (
                            JuMP.value(vars.expansion[process_node, t]) -
                            JuMP.value(vars.expansion[process_node, t-1])
                        )
                    end
                ) for t = 1:T
            ],
            "Process (tonne)" =>
                [JuMP.value(vars.process[process_node, t]) for t = 1:T],
            "Variable operating cost (\$)" => [
                JuMP.value(vars.process[process_node, t]) *
                plant.sizes[1].variable_operating_cost[t] for t = 1:T
            ],
            "Storage (tonne)" => [JuMP.value(vars.store[process_node, t]) for t = 1:T],
            "Storage cost (\$)" => [
                JuMP.value(vars.store[process_node, t]) * plant.storage_cost[t] for t = 1:T
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
            vals = [JuMP.value(vars.flow[a, t]) for t = 1:T]
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

            disposal_amount = [JuMP.value(vars.dispose[shipping_node, t]) for t = 1:T]
            if sum(disposal_amount) > 1e-5
                skip_plant = false
                plant_dict["Output"]["Dispose"][product_name] =
                    disposal_dict = OrderedDict()
                disposal_dict["Amount (tonne)"] =
                    [JuMP.value(model.vars.dispose[shipping_node, t]) for t = 1:T]
                disposal_dict["Cost (\$)"] = [
                    disposal_dict["Amount (tonne)"][t] *
                    plant.disposal_cost[shipping_node.product][t] for t = 1:T
                ]
                plant_dict["Total output"][product_name] += disposal_amount
                output["Costs"]["Disposal (\$)"] += disposal_dict["Cost (\$)"]
            end

            for a in shipping_node.outgoing_arcs
                vals = [JuMP.value(vars.flow[a, t]) for t = 1:T]
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

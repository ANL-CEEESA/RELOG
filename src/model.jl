# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP, LinearAlgebra, Geodesy, Cbc, Clp, ProgressBars


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
    
    vars.flow = Dict((a, t) => @variable(mip,
                                         lower_bound=0,
                                         base_name="flow($(a.source.location.index),$(a.dest.location.index),$t)")
                    for a in graph.arcs, t in 1:T)
   
    vars.dispose = Dict((n, t) => @variable(mip,
                                            lower_bound=0,
                                            upper_bound=n.location.disposal_limit[n.product][t],
                                            base_name="dispose($(n.location.index),$(n.product.name),$t)")
                        for n in values(graph.plant_shipping_nodes), t in 1:T)
    
    vars.open_plant = Dict((n, t) => @variable(mip,
                                               binary=true,
                                               base_name="open_plant($(n.location.index),$t)")
                           for n in values(graph.process_nodes), t in 1:T)

    vars.is_open = Dict((n, t) => @variable(mip,
                                            binary=true,
                                            base_name="is_open($(n.location.index),$t)")
                        for n in values(graph.process_nodes), t in 1:T)

    vars.capacity = Dict((n, t) => @variable(mip,
                                             lower_bound = 0,
                                             upper_bound = n.location.sizes[2].capacity,
                                             base_name="capacity($(n.location.index),$t)")
                         for n in values(graph.process_nodes), t in 1:T)
    
    vars.expansion = Dict((n, t) => @variable(mip,
                                              lower_bound = 0,
                                              upper_bound = n.location.sizes[2].capacity - 
                                                            n.location.sizes[1].capacity,
                                              base_name="expansion($(n.location.index),$t)")
                         for n in values(graph.process_nodes), t in 1:T)
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
    obj = @expression(mip, 0 * @variable(mip))

    # Process node costs
    for n in values(graph.process_nodes), t in 1:T
        
        # Transportation and variable operating costs
        for a in n.incoming_arcs
            c = n.location.input.transportation_cost[t] * a.values["distance"]
            c += n.location.sizes[1].variable_operating_cost[t]
            add_to_expression!(obj, c, vars.flow[a, t])
        end
        
        # Opening costs
        add_to_expression!(obj,
                           n.location.sizes[1].opening_cost[t],
                           vars.open_plant[n, t])
        
        # Fixed operating costs (base)
        add_to_expression!(obj,
                           n.location.sizes[1].fixed_operating_cost[t],
                           vars.is_open[n, t])
        
        # Fixed operating costs (expansion)
        add_to_expression!(obj,
                           slope_fix_oper_cost(n.location, t),
                           vars.expansion[n, t])
        
        # Expansion costs
        if t < T
            add_to_expression!(obj,
                               slope_open(n.location, t) - slope_open(n.location, t + 1),
                               vars.expansion[n, t])
        else
            add_to_expression!(obj,
                               slope_open(n.location, t),
                               vars.expansion[n, t])
        end
    end

    # Disposal costs
    for n in values(graph.plant_shipping_nodes), t in 1:T
        add_to_expression!(obj, n.location.disposal_cost[n.product][t], vars.dispose[n, t])
    end

    @objective(mip, Min, obj)
end    


function create_shipping_node_constraints!(model::ManufacturingModel)
    mip, vars, graph, T = model.mip, model.vars, model.graph, model.instance.time
    eqs = model.eqs
    
    eqs.balance = Dict()
    
    for t in 1:T
        # Collection centers
        for n in graph.collection_shipping_nodes
            eqs.balance[n, t] = @constraint(mip,
                                            sum(vars.flow[a, t] for a in n.outgoing_arcs)
                                              == n.location.amount[t])
        end

        # Plants
        for n in graph.plant_shipping_nodes
            @constraint(mip,
                sum(vars.flow[a, t] for a in n.incoming_arcs) ==
                sum(vars.flow[a, t] for a in n.outgoing_arcs) + vars.dispose[n, t])
        end
    end
end


function create_process_node_constraints!(model::ManufacturingModel)
    mip, vars, graph, T = model.mip, model.vars, model.graph, model.instance.time

    for n in graph.process_nodes, t in 1:T
        # Output amount is implied by input amount
        input_sum = isempty(n.incoming_arcs) ? 0 : sum(vars.flow[a, t] for a in n.incoming_arcs)
        for a in n.outgoing_arcs
            @constraint(mip, vars.flow[a, t] == a.values["weight"] * input_sum)
        end

        # If plant is closed, capacity is zero
        @constraint(mip, vars.capacity[n, t] <= n.location.sizes[2].capacity * vars.is_open[n, t])
        
        # If plant is open, capacity is greater than base
        @constraint(mip, vars.capacity[n, t] >= n.location.sizes[1].capacity * vars.is_open[n, t])

        # Capacity is linked to expansion
        @constraint(mip, vars.capacity[n, t] <= n.location.sizes[1].capacity + vars.expansion[n, t])

        # Input sum must be smaller than capacity
        @constraint(mip, input_sum <= vars.capacity[n, t])
        
        if t > 1
            # Plant capacity can only increase over time
            @constraint(mip, vars.capacity[n, t] >= vars.capacity[n, t-1])
            @constraint(mip, vars.expansion[n, t] >= vars.expansion[n, t-1])
        end
        
        # Plant is currently open if it was already open in the previous time period or
        # if it was built just now
        if t > 1
            @constraint(mip, vars.is_open[n, t] == vars.is_open[n, t-1] + vars.open_plant[n, t])
        else
            @constraint(mip, vars.is_open[n, t] == vars.open_plant[n, t])
        end
    end
end

function solve(filename::String; milp_optimizer=Cbc.Optimizer, lp_optimizer=Clp.Optimizer)
    println("Reading $filename...")
    instance = RELOG.load(filename)
    
    println("Building graph...")
    graph = RELOG.build_graph(instance)
    
    println("Building optimization model...")
    model = RELOG.build_model(instance, graph, milp_optimizer)
    
    println("Optimizing MILP...")
    JuMP.optimize!(model.mip)
    
    println("Re-optimizing with integer variables fixed...")
    all_vars = JuMP.all_variables(model.mip)
    vals = Dict(var => JuMP.value(var) for var in all_vars)
    JuMP.set_optimizer(model.mip, lp_optimizer)
    for var in all_vars
        if JuMP.is_binary(var)
            JuMP.unset_binary(var)
            JuMP.fix(var, vals[var])
        end
    end
    JuMP.optimize!(model.mip)
    
    println("Extracting solution...")
    return get_solution(model)
end

function get_solution(model::ManufacturingModel)
    mip, vars, eqs, graph, instance = model.mip, model.vars, model.eqs, model.graph, model.instance
    T = instance.time
    
    output = Dict(
        "Plants" => Dict(),
        "Products" => Dict(),
        "Costs" => Dict(
            "Fixed operating (\$)" => zeros(T),
            "Variable operating (\$)" => zeros(T),
            "Opening (\$)" => zeros(T),
            "Transportation (\$)" => zeros(T),
            "Disposal (\$)" => zeros(T),
            "Expansion (\$)" => zeros(T),
            "Total (\$)" => zeros(T),
        ),
        "Energy" => Dict(
            "Plants (GJ)" => zeros(T),
            "Transportation (GJ)" => zeros(T),
        )
    )
    
    plant_to_process_node = Dict(n.location => n for n in graph.process_nodes)
    plant_to_shipping_nodes = Dict()
    for p in instance.plants
        plant_to_shipping_nodes[p] = []
        for a in plant_to_process_node[p].outgoing_arcs
            push!(plant_to_shipping_nodes[p], a.dest)
        end
    end
    
    # Products
    for n in graph.collection_shipping_nodes
        location_dict = Dict{Any, Any}(
            "Marginal cost (\$/tonne)" => [round(abs(JuMP.shadow_price(eqs.balance[n, t])), digits=2)
                                           for t in 1:T],
        )
        if n.product.name ∉ keys(output["Products"])
            output["Products"][n.product.name] = Dict()
        end
        output["Products"][n.product.name][n.location.name] = location_dict
    end
    
    # Plants
    for plant in instance.plants
        skip_plant = true
        process_node = plant_to_process_node[plant]
        plant_dict = Dict{Any, Any}(
            "Input" => Dict(),
            "Output" => Dict(
                "Send" => Dict(),
                "Dispose" => Dict(),
            ),
            "Total input (tonne)" => [0.0 for t in 1:T],
            "Total output" => Dict(),
            "Latitude (deg)" => plant.latitude,
            "Longitude (deg)" => plant.longitude,
            "Capacity (tonne)" => [JuMP.value(vars.capacity[process_node, t])
                                   for t in 1:T],
            "Opening cost (\$)" => [JuMP.value(vars.open_plant[process_node, t]) *
                                    plant.sizes[1].opening_cost[t]
                                    for t in 1:T],
            "Fixed operating cost (\$)" => [JuMP.value(vars.is_open[process_node, t]) *
                                            plant.sizes[1].fixed_operating_cost[t] +
                                            JuMP.value(vars.expansion[process_node, t]) *
                                            slope_fix_oper_cost(plant, t)
                                            for t in 1:T],
            "Expansion cost (\$)" => [JuMP.value(vars.expansion[process_node, t]) *
                                          (if t < T
                                              slope_open(plant, t) - slope_open(plant, t + 1)
                                           else
                                              slope_open(plant, t)
                                           end)
                                      for t in 1:T],
        )
        output["Costs"]["Fixed operating (\$)"] += plant_dict["Fixed operating cost (\$)"]
        output["Costs"]["Opening (\$)"] += plant_dict["Opening cost (\$)"]
        output["Costs"]["Expansion (\$)"] += plant_dict["Expansion cost (\$)"]

        # Inputs
        for a in process_node.incoming_arcs
            vals = [JuMP.value(vars.flow[a, t]) for t in 1:T]
            if sum(vals) <= 1e-3
                continue
            end
            skip_plant = false
            dict = Dict{Any, Any}(
                "Amount (tonne)" => vals,
                "Distance (km)" => a.values["distance"],
                "Latitude (deg)" => a.source.location.latitude,
                "Longitude (deg)" => a.source.location.longitude,
                "Transportation cost (\$)" => a.source.product.transportation_cost .* vals .* a.values["distance"],
                "Variable operating cost (\$)" => plant.sizes[1].variable_operating_cost .* vals,
                "Transportation energy (J)" => vals .* a.values["distance"] .* a.source.product.transportation_energy,                
            )
            if a.source.location isa CollectionCenter
                plant_name = "Origin"
                location_name = a.source.location.name
            else
                plant_name = a.source.location.plant_name
                location_name = a.source.location.location_name
            end
            
            if plant_name ∉ keys(plant_dict["Input"])
                plant_dict["Input"][plant_name] = Dict()
            end
            plant_dict["Input"][plant_name][location_name] = dict
            plant_dict["Total input (tonne)"] += vals
            output["Costs"]["Transportation (\$)"] += dict["Transportation cost (\$)"]
            output["Costs"]["Variable operating (\$)"] += dict["Variable operating cost (\$)"]
            output["Energy"]["Transportation (GJ)"] += dict["Transportation energy (J)"] / 1e6
        end
        
        plant_dict["Energy (GJ)"] = plant_dict["Total input (tonne)"] .* plant.energy
        output["Energy"]["Plants (GJ)"] += plant_dict["Energy (GJ)"]

        # Outputs
        for shipping_node in plant_to_shipping_nodes[plant]
            product_name = shipping_node.product.name
            plant_dict["Total output"][product_name] = zeros(T)
            plant_dict["Output"]["Send"][product_name] = product_dict = Dict()

            disposal_amount = [JuMP.value(vars.dispose[shipping_node, t]) for t in 1:T]
            if sum(disposal_amount) > 1e-5
                skip_plant = false
                plant_dict["Output"]["Dispose"][product_name] = disposal_dict = Dict()
                disposal_dict["Amount (tonne)"] = [JuMP.value(model.vars.dispose[shipping_node, t])
                                                   for t in 1:T]
                disposal_dict["Cost (\$)"] = [disposal_dict["Amount (tonne)"][t] *
                                              plant.disposal_cost[shipping_node.product][t]
                                              for t in 1:T]
                plant_dict["Total output"][product_name] += disposal_amount
                output["Costs"]["Disposal (\$)"] += disposal_dict["Cost (\$)"]
            end

            for a in shipping_node.outgoing_arcs
                vals = [JuMP.value(vars.flow[a, t]) for t in 1:T]
                if sum(vals) <= 1e-3
                    continue
                end
                skip_plant = false
                dict = Dict(
                    "Amount (tonne)" => vals,
                    "Distance (km)" => a.values["distance"],
                    "Latitude (deg)" => a.dest.location.latitude,
                    "Longitude (deg)" => a.dest.location.longitude,
                )
                if a.dest.location.plant_name ∉ keys(product_dict)
                    product_dict[a.dest.location.plant_name] = Dict()
                end
                product_dict[a.dest.location.plant_name][a.dest.location.location_name] = dict
                plant_dict["Total output"][product_name] += vals
            end
        end
            
        if !skip_plant
            if plant.plant_name ∉ keys(output["Plants"])
                output["Plants"][plant.plant_name] = Dict()
            end
            output["Plants"][plant.plant_name][plant.location_name] = plant_dict
        end
    end

    output["Costs"]["Total (\$)"] = sum(values(output["Costs"]))
    return output
end

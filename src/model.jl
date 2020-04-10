# Copyright (C) 2019 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using JuMP, LinearAlgebra, Geodesy, Cbc, ProgressBars

mutable struct ReverseManufacturingModel
    mip::JuMP.Model
    vars::DotDict
    arcs
    shipping_nodes
    process_nodes
end

abstract type Node
end

mutable struct ProcessNode <: Node
    product_name::String
    plant_name::String
    location_name::String
    incoming_arcs::Array
    outgoing_arcs::Array
    fixed_cost::Float64
    expansion_cost::Float64
    base_capacity::Float64
    max_capacity::Float64
end

mutable struct ShippingNode <: Node
    product_name::String
    plant_name::String
    location_name::String
    incoming_arcs::Array
    outgoing_arcs::Array
    balance::Float64
    disposal_cost::Float64
    disposal_limit::Float64
end

function Base.show(io::IO, node::ProcessNode)
    print(io, "ProcessNode($(node.product_name), $(node.plant_name), $(node.location_name), fixed_cost=$(node.fixed_cost))")
end

function Base.show(io::IO, node::ShippingNode)
    print(io, "ShippingNode($(node.product_name), $(node.plant_name), $(node.location_name), balance=$(node.balance), ")
    print(io, "disposal_cost=$(node.disposal_cost), disposal_limit=$(node.disposal_limit))")
end

mutable struct Arc
    # Origin of the arc
    source::Node

    # Destination of the arc
    dest::Node

    # Costs dictionary. Each value in this dictionary is multiplied by the arc flow variable 
    # and added to the objective function.
    costs::Dict

    # Values dictionary. This dictionary is used to store extra information about the
    # arc. They are not used automatically by the model.
    values::Dict
end

function Base.show(io::IO, arc::Arc)
    print(io, "Arc($(arc.source), $(arc.dest))")
end

function build_model(instance::ReverseManufacturingInstance,
                     optimizer,
                    ) :: ReverseManufacturingModel

    println("Building optimization model...")
    mip = Model(optimizer)
    shipping_nodes, process_nodes, arcs = create_nodes_and_arcs(instance)
    
    println("        $(length(shipping_nodes)) shipping nodes")
    println("        $(length(process_nodes)) process nodes")
    println("        $(length(arcs)) arcs")

    vars = DotDict()
    vars.flow = Dict(a => @variable(mip, lower_bound=0) for a in arcs)
    vars.dispose = Dict(n => @variable(mip,
                                       lower_bound = 0,
                                       upper_bound = n.disposal_limit)
                        for n in values(shipping_nodes))
    vars.open_plant = Dict(n => @variable(mip, binary=true) for n in values(process_nodes))
    vars.capacity = Dict(n => @variable(mip, lower_bound = 0, upper_bound = n.max_capacity)
                         for n in values(process_nodes))
    vars.expansion = Dict(n => @variable(mip, lower_bound = 0, upper_bound = (n.max_capacity - n.base_capacity))
                         for n in values(process_nodes))        
    create_shipping_node_constraints!(mip, shipping_nodes, vars)
    create_process_node_constraints!(mip, process_nodes, vars)
    
    println("    Creating objective function...")
    obj = @expression(mip, 0 * @variable(mip))

    # Shipping and variable operating costs
    for a in tqdm(arcs)
        for c in keys(a.costs)
            add_to_expression!(obj, a.costs[c], vars.flow[a])
        end
    end

    # Opening and fixed operating costs
    for n in tqdm(values(process_nodes))
        add_to_expression!(obj, n.fixed_cost, vars.open_plant[n])
    end

    # Expansion cost
    for n in tqdm(values(process_nodes))
        add_to_expression!(obj, n.expansion_cost, vars.expansion[n])
    end

    # Disposal costs
    for n in tqdm(values(shipping_nodes))
        add_to_expression!(obj, n.disposal_cost, vars.dispose[n])
    end

    @objective(mip, Min, obj)
    
    return ReverseManufacturingModel(mip,
                                     vars,
                                     arcs,
                                     shipping_nodes,
                                     process_nodes)
end

function create_shipping_node_constraints!(mip, nodes, vars)
    println("    Creating shipping-node constraints...")
    for (id, n) in tqdm(nodes)
        @constraint(mip,
            sum(vars.flow[a] for a in n.incoming_arcs) + n.balance ==
            sum(vars.flow[a] for a in n.outgoing_arcs) + vars.dispose[n])
    end
end

function create_process_node_constraints!(mip, nodes, vars)
    println("    Creating process-node constraints...")
    for (id, n) in tqdm(nodes)
        # Output amount is implied by input amount
        input_sum = isempty(n.incoming_arcs) ? 0 : sum(vars.flow[a] for a in n.incoming_arcs)
        for a in n.outgoing_arcs
            @constraint(mip, vars.flow[a] == a.values["weight"] * input_sum)
        end

        # If plant is closed, capacity is zero.
        @constraint(mip, vars.capacity[n] <= n.max_capacity * vars.open_plant[n])

        # Capacity is linked to expansion
        @constraint(mip, vars.capacity[n] <= n.base_capacity + vars.expansion[n])

        # Input sum must be smaller than capacity
        @constraint(mip, input_sum <= vars.capacity[n])
    end
end

function create_nodes_and_arcs(instance)
    println("    Creating nodes and arcs...")
    arcs = Arc[]
    shipping_nodes = Dict()
    process_nodes = Dict()
    
    # Create all nodes
    for (product_name, product) in instance.products
        
        # Shipping nodes for initial amounts
        if haskey(product, "initial amounts")
            for location_name in keys(product["initial amounts"])
                balance = product["initial amounts"][location_name]["amount"]
                n = ShippingNode(product_name,
                                 "Origin", # plant_name
                                 location_name,
                                 [], # incoming_arcs
                                 [], # outgoing_arcs
                                 balance,
                                 0.0, # disposal_cost
                                 0.0, # disposal_limit
                                )
                shipping_nodes[n.product_name, n.plant_name, n.location_name] = n
            end
        end
        
        # Process nodes for each plant
        for plant in product["input plants"]
            for (location_name, location) in plant["locations"]
                base_capacity = 1e8
                max_capacity = 1e8
                expansion_cost = 0.0
                fixed_cost = location["opening cost"] + location["fixed operating cost"]
                if "base capacity" in keys(location)
                    base_capacity = location["base capacity"]
                end
                if "max capacity" in keys(location)
                    max_capacity = location["max capacity"]
                end
                if "expansion cost" in keys(location)
                    expansion_cost = location["expansion cost"]
                end
                n = ProcessNode(product_name,
                                plant["name"],
                                location_name,
                                [], # incoming_arcs
                                [], # outgoing_arcs
                                fixed_cost,
                                expansion_cost,
                                base_capacity,
                                max_capacity)
                process_nodes[n.product_name, n.plant_name, n.location_name] = n
            end
        end
        
        # Shipping nodes for each plant
        for plant in product["output plants"]
            for (location_name, location) in plant["locations"]
                disposal_cost = 0.0
                disposal_limit = 0.0

                if "disposal" in keys(location) && product_name in keys(location["disposal"])
                    dict = location["disposal"][product_name]
                    disposal_cost = dict["cost"]
                    if "limit" in keys(dict)
                        disposal_limit = dict["limit"]
                    else
                        disposal_limit = 1e10
                    end
                end

                n = ShippingNode(product_name,
                                 plant["name"],
                                 location_name,
                                 [], # incoming_arcs
                                 [], # outgoing_arcs
                                 0.0, # balance
                                 disposal_cost,
                                 disposal_limit,
                                )
                shipping_nodes[n.product_name, n.plant_name, n.location_name] = n
            end
        end
    end
    
    # Create arcs
    for (product_name, product) in instance.products
        
        # Transportation arcs from initial location to plants
        if haskey(product, "initial amounts")
            for source_location_name in keys(product["initial amounts"])
                source_location = product["initial amounts"][source_location_name]
                for dest_plant in product["input plants"]
                    for dest_location_name in keys(dest_plant["locations"])
                        dest_location = dest_plant["locations"][dest_location_name]
                        source = shipping_nodes[product_name, "Origin", source_location_name]
                        dest = process_nodes[product_name, dest_plant["name"], dest_location_name]
                        distance = calculate_distance(source_location["latitude"],
                                                      source_location["longitude"],
                                                      dest_location["latitude"],
                                                      dest_location["longitude"])
                        costs = Dict("transportation" => product["transportation cost"] * distance,
                                     "variable" => dest_location["variable operating cost"])
                        values = Dict("distance" => distance)
                        a = Arc(source, dest, costs, values)
                        push!(arcs, a)
                        push!(source.outgoing_arcs, a)
                        push!(dest.incoming_arcs, a)
                    end
                end
            end
        end
        
        
        for source_plant in product["output plants"]
            for source_location_name in keys(source_plant["locations"])
                source_location = source_plant["locations"][source_location_name]

                # Process arcs (conversions within a plant)
                source = process_nodes[source_plant["input"], source_plant["name"], source_location_name]
                dest = shipping_nodes[product_name, source_plant["name"], source_location_name]
                costs = Dict()
                values = Dict("weight" => source_plant["outputs"][product_name])
                a = Arc(source, dest, costs, values)
                push!(arcs, a)
                push!(source.outgoing_arcs, a)
                push!(dest.incoming_arcs, a)
                
                # Transportation arcs (from one plant to another)
                for dest_plant in product["input plants"]
                    for dest_location_name in keys(dest_plant["locations"])
                        dest_location = dest_plant["locations"][dest_location_name]
                        source = shipping_nodes[product_name,
                                                source_plant["name"],
                                                source_location_name]
                        dest = process_nodes[product_name, dest_plant["name"], dest_location_name]
                        distance = calculate_distance(source_location["latitude"],
                                                      source_location["longitude"],
                                                      dest_location["latitude"],
                                                      dest_location["longitude"])
                        costs = Dict("transportation" => product["transportation cost"] * distance,
                                     "variable" => dest_location["variable operating cost"])
                        values = Dict("distance" => distance)
                        a = Arc(source, dest, costs, values)
                        push!(arcs, a)
                        push!(source.outgoing_arcs, a)
                        push!(dest.incoming_arcs, a)
                    end
                end
            end
        end
    end
    return shipping_nodes, process_nodes, arcs
end

function calculate_distance(source_lat, source_lon, dest_lat, dest_lon)::Float64
    x = LLA(source_lat, source_lon, 0.0)
    y = LLA(dest_lat, dest_lon, 0.0)
    return round(distance(x, y) / 1000.0, digits=2)
end

function solve(filename::String;
               optimizer=Cbc.Optimizer)
    println("Reading $filename")
    instance = ReverseManufacturing.readfile(filename)
    model = ReverseManufacturing.build_model(instance, optimizer)
    
    println("Optimizing...")
    JuMP.optimize!(model.mip)
    
    println("Extracting solution...")
    return get_solution(instance, model)
end

function get_solution(instance::ReverseManufacturingInstance,
                      model::ReverseManufacturingModel)
    vals = Dict()
    for a in values(model.arcs)
        vals[a] = JuMP.value(model.vars.flow[a])
    end
    for n in values(model.process_nodes)
        vals[n] = JuMP.value(model.vars.open_plant[n])
    end
    
    output = Dict(
        "plants" => Dict(),
        "costs" => Dict(
            "fixed" => 0.0,
            "variable" => 0.0,
            "transportation" => 0.0,
            "disposal" => 0.0,
            "total" => 0.0,
            "expansion" => 0.0,
        )
    )

    for (plant_name, plant) in instance.plants
        skip_plant = true
        plant_dict = Dict{Any, Any}()
        input_product_name = plant["input"]
        
        for (location_name, location) in plant["locations"]
            skip_location = true
            process_node = model.process_nodes[input_product_name, plant_name, location_name]

            plant_loc_dict = Dict{Any, Any}(
                "input" => Dict(),
                "output" => Dict(
                    "send" => Dict(),
                    "dispose" => Dict(),
                ),
                "total input" => 0.0,
                "total output" => Dict(),
                "latitude" => location["latitude"],
                "longitude" => location["longitude"],
                "capacity" => round(JuMP.value(model.vars.capacity[process_node]), digits=2)
            )

            plant_loc_dict["fixed cost"] = round(vals[process_node] * process_node.fixed_cost, digits=5)
            plant_loc_dict["expansion cost"] = round(JuMP.value(model.vars.expansion[process_node]) * process_node.expansion_cost, digits=5)
            output["costs"]["fixed"] += plant_loc_dict["fixed cost"]
            output["costs"]["expansion"] += plant_loc_dict["expansion cost"]

            # Inputs
            for a in process_node.incoming_arcs
                if vals[a] <= 1e-3
                    continue
                end
                skip_plant = skip_location = false
                val = round(vals[a], digits=5)
                if !(a.source.plant_name in keys(plant_loc_dict["input"]))
                    plant_loc_dict["input"][a.source.plant_name] = Dict()
                end
                if a.source.plant_name == "Origin"
                    product = instance.products[a.source.product_name]
                    source_location = product["initial amounts"][a.source.location_name]
                else
                    source_plant = instance.plants[a.source.plant_name]
                    source_location = source_plant["locations"][a.source.location_name]
                end
                
                # Input
                cost_transportation = round(a.costs["transportation"] * val, digits=5)
                plant_loc_dict["input"][a.source.plant_name][a.source.location_name] = dict = Dict()
                cost_variable = round(a.costs["variable"] * val, digits=5)
                dict["amount"] = val
                dict["distance"] = a.values["distance"]
                dict["transportation cost"] = cost_transportation
                dict["variable operating cost"] = cost_variable
                dict["latitude"] = source_location["latitude"]
                dict["longitude"] = source_location["longitude"]
                plant_loc_dict["total input"] += val
                
                output["costs"]["transportation"] += cost_transportation
                output["costs"]["variable"] += cost_variable
            end

            # Outputs
            for output_product_name in keys(plant["outputs"])
                plant_loc_dict["total output"][output_product_name] = 0.0
                plant_loc_dict["output"]["send"][output_product_name] = product_dict = Dict()
                shipping_node = model.shipping_nodes[output_product_name, plant_name, location_name]

                disposal_amount = JuMP.value(model.vars.dispose[shipping_node])
                if disposal_amount > 1e-5
                    plant_loc_dict["output"]["dispose"][output_product_name] = disposal_dict = Dict()
                    disposal_dict["amount"] = JuMP.value(model.vars.dispose[shipping_node])
                    disposal_dict["cost"] = disposal_dict["amount"] * shipping_node.disposal_cost
                    plant_loc_dict["total output"][output_product_name] += disposal_amount
                    output["costs"]["disposal"] += disposal_dict["cost"]
                end

                for a in shipping_node.outgoing_arcs
                    if vals[a] <= 1e-3
                        continue
                    end
                    skip_plant = skip_location = false
                    if !(a.dest.plant_name in keys(product_dict))
                        product_dict[a.dest.plant_name] = Dict{Any,Any}()
                    end
                    dest_location = instance.plants[a.dest.plant_name]["locations"][a.dest.location_name]
                    val = round(vals[a], digits=5)
                    plant_loc_dict["total output"][output_product_name] += val
                    product_dict[a.dest.plant_name][a.dest.location_name] = dict = Dict()
                    dict["amount"] = val
                    dict["distance"] = a.values["distance"]
                    dict["latitude"] = dest_location["latitude"]
                    dict["longitude"] = dest_location["longitude"]
                end
            end
            
            if !skip_location
                plant_dict[location_name] = plant_loc_dict
            end
        end
        if !skip_plant
            output["plants"][plant_name] = plant_dict
        end
    end

    output["costs"]["total"] = sum(values(output["costs"]))
    return output
end

export FlowArc

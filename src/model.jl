# Copyright (C) 2019 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using JuMP, LinearAlgebra, Geodesy, Cbc, ProgressBars

mutable struct ReverseManufacturingModel
    mip::JuMP.Model
    vars::DotDict
    arcs
    decision_nodes
    process_nodes
end

mutable struct Node
    product_name::String
    plant_name::String
    location_name::String
    balance::Float64
    incoming_arcs::Array
    outgoing_arcs::Array
    cost::Float64
end

function Node(product_name::String,
              plant_name::String,
              location_name::String;
              balance::Float64 = 0.0,
              incoming_arcs::Array = [],
              outgoing_arcs::Array = [],
              cost::Float64 = 0.0,
             ) :: Node
    return Node(product_name,
                plant_name,
                location_name,
                balance,
                incoming_arcs,
                outgoing_arcs,
                cost)
end

function Base.show(io::IO, node::Node)
    print(io, "Node($(node.product_name), $(node.plant_name), $(node.location_name)")
    if node.balance != 0.0
        print(io, ", $(node.balance)")
    end
    print(io, ")")
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
    decision_nodes, process_nodes, arcs = create_nodes_and_arcs(instance)
    
    println("        $(length(decision_nodes)) decision nodes")
    println("        $(length(process_nodes)) process nodes")
    println("        $(length(arcs)) arcs")

    vars = DotDict()
    vars.flow = Dict(a => @variable(mip, lower_bound=0) for a in arcs)
    vars.node = Dict(n => @variable(mip, binary=true) for n in values(process_nodes))
    create_decision_node_constraints!(mip, decision_nodes, vars)
    create_process_node_constraints!(mip, process_nodes, vars)
    
    println("    Creating objective function...")
    obj = @expression(mip, 0 * @variable(mip))
    for a in tqdm(arcs)
        for c in keys(a.costs)
            add_to_expression!(obj, a.costs[c], vars.flow[a])
        end
    end
    for n in tqdm(values(process_nodes))
        add_to_expression!(obj, n.cost, vars.node[n])
    end
    @objective(mip, Min, obj)
    
    return ReverseManufacturingModel(mip,
                                     vars,
                                     arcs,
                                     decision_nodes,
                                     process_nodes)
end

function create_decision_node_constraints!(mip, nodes, vars)
    println("    Creating decision-node constraints...")
    for (id, n) in tqdm(nodes)
        @constraint(mip,
            sum(vars.flow[a] for a in n.incoming_arcs) + n.balance ==
            sum(vars.flow[a] for a in n.outgoing_arcs))
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
        # If plant is closed, input must be zero
        @constraint(mip, input_sum <= 1e6 * vars.node[n])
    end
end

function create_nodes_and_arcs(instance)
    println("    Creating nodes and arcs...")
    arcs = Arc[]
    decision_nodes = Dict()
    process_nodes = Dict()
    
    # Create all nodes
    for (product_name, product) in instance.products
        
        # Decision nodes for initial amounts
        if haskey(product, "initial amounts")
            for location_name in keys(product["initial amounts"])
                amount = product["initial amounts"][location_name]["amount"]
                n = Node(product_name, "Origin", location_name, balance=amount)
                decision_nodes[n.product_name, n.plant_name, n.location_name] = n
            end
        end
        
        # Process nodes for each plant
        for plant in product["input plants"]
            for (location_name, location) in plant["locations"]
                cost = location["opening cost"] + location["fixed operating cost"]
                n = Node(product_name, plant["name"], location_name, cost=cost)
                process_nodes[n.product_name, n.plant_name, n.location_name] = n
            end
        end
        
        # Decision nodes for each plant
        for plant in product["output plants"]
            for location_name in keys(plant["locations"])
                n = Node(product_name, plant["name"], location_name)
                decision_nodes[n.product_name, n.plant_name, n.location_name] = n
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
                        source = decision_nodes[product_name, "Origin", source_location_name]
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
                dest = decision_nodes[product_name, source_plant["name"], source_location_name]
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
                        source = decision_nodes[product_name, source_plant["name"], source_location_name]
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
    return decision_nodes, process_nodes, arcs
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
        vals[n] = JuMP.value(model.vars.node[n])
    end
    
    output = Dict(
        "plants" => Dict(),
        "costs" => Dict(
            "fixed" => 0.0,
            "variable" => 0.0,
            "transportation" => 0.0,
            "total" => 0.0,
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
                "output" => Dict(),
                "total input" => 0.0,
                "total output" => Dict(),
                "transportation costs" => Dict(),
                "variable costs" => Dict(),
                "latitude" => location["latitude"],
                "longitude" => location["longitude"],
            )

            plant_loc_dict["fixed cost"] = round(vals[process_node] * process_node.cost, digits=5)
            output["costs"]["fixed"] += plant_loc_dict["fixed cost"]

            # Inputs
            for a in process_node.incoming_arcs
                if vals[a] <= 0
                    continue
                end
                skip_plant = skip_location = false
                val = round(vals[a], digits=5)
                if !(a.source.plant_name in keys(plant_loc_dict["input"]))
                    plant_loc_dict["input"][a.source.plant_name] = Dict()
                    plant_loc_dict["transportation costs"][a.source.plant_name] = Dict()
                    plant_loc_dict["variable costs"][a.source.plant_name] = Dict()
                end
                if a.source.plant_name == "Origin"
                    product = instance.products[a.source.product_name]
                    source_location = product["initial amounts"][a.source.location_name]
                else
                    source_plant = instance.plants[a.source.plant_name]
                    source_location = source_plant["locations"][a.source.location_name]
                end
                
                # Input
                plant_loc_dict["input"][a.source.plant_name][a.source.location_name] = dict = Dict()
                dict["amount"] = val
                dict["latitude"] = source_location["latitude"]
                dict["longitude"] = source_location["longitude"]
                plant_loc_dict["total input"] += val
                
                # Transportation costs
                cost_transportation = round(a.costs["transportation"] * val, digits=5)
                plant_loc_dict["transportation costs"][a.source.plant_name][a.source.location_name] = dict = Dict()
                dict["cost"] = cost_transportation
                dict["latitude"] = source_location["latitude"]
                dict["longitude"] = source_location["longitude"]
                dict["distance"] = a.values["distance"]
                output["costs"]["transportation"] += cost_transportation
                
                cost_variable = round(a.costs["variable"] * val, digits=5)
                plant_loc_dict["variable costs"][a.source.plant_name][a.source.location_name] = dict = Dict()
                dict["cost"] = cost_variable
                dict["latitude"] = source_location["latitude"]
                dict["longitude"] = source_location["longitude"]
                output["costs"]["variable"] += cost_variable
            end

            # Outputs
            for output_product_name in keys(plant["outputs"])
                plant_loc_dict["total output"][output_product_name] = 0.0
                plant_loc_dict["output"][output_product_name] = product_dict = Dict()
                decision_node = model.decision_nodes[output_product_name, plant_name, location_name]
                for a in decision_node.outgoing_arcs
                    if vals[a] <= 0
                        continue
                    end
                    skip_plant = skip_location = false
                    if !(a.dest.plant_name in keys(product_dict))
                        product_dict[a.dest.plant_name] = Dict{Any,Any}()
                    end
                    val = round(vals[a], digits=5)
                    plant_loc_dict["total output"][output_product_name] += val
                    product_dict[a.dest.plant_name][a.dest.location_name] = val
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

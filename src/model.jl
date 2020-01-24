# Copyright (C) 2019 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using JuMP, LinearAlgebra, Geodesy

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
    source::Node
    dest::Node
    costs::Dict
    values::Dict
end

function Base.show(io::IO, arc::Arc)
    print(io, "Arc($(arc.source), $(arc.dest))")
end

function build_model(instance::ReverseManufacturingInstance,
                     optimizer,
                    ) :: ReverseManufacturingModel

    mip = isa(optimizer, JuMP.OptimizerFactory) ? Model(optimizer) : direct_model(optimizer)
    decision_nodes, process_nodes, arcs = create_nodes_and_arcs(instance)
    vars = DotDict()
    vars.flow = Dict(a => @variable(mip, lower_bound=0) for a in arcs)
    vars.node = Dict(n => @variable(mip, binary=true) for n in values(process_nodes))
    create_decision_node_constraints!(mip, decision_nodes, vars)
    create_process_node_constraints!(mip, process_nodes, vars)
    flow_costs = sum(a.costs[c] * vars.flow[a] for a in arcs for c in keys(a.costs))
    node_costs = sum(n.cost * vars.node[n] for n in values(process_nodes))
    @objective(mip, Min, flow_costs + node_costs)
    return return ReverseManufacturingModel(mip,
                                            vars,
                                            arcs,
                                            decision_nodes,
                                            process_nodes)
end

function create_decision_node_constraints!(mip, nodes, vars)
    for (id, n) in nodes
        @constraint(mip,
            sum(vars.flow[a] for a in n.incoming_arcs) + n.balance ==
            sum(vars.flow[a] for a in n.outgoing_arcs))
    end
end

function create_process_node_constraints!(mip, nodes, vars)
    for (id, n) in nodes
        # Output amount is implied by input amount
        input_sum = sum(vars.flow[a] for a in n.incoming_arcs)
        for a in n.outgoing_arcs
            @constraint(mip, vars.flow[a] == a.values["weight"] * input_sum)
        end
        # If plant is closed, input must be zero
        @constraint(mip, input_sum <= 1e6 * vars.node[n])
    end
end

function create_nodes_and_arcs(instance)
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

                # Process-arcs within a plant
                source = process_nodes[source_plant["input"], source_plant["name"], source_location_name]
                dest = decision_nodes[product_name, source_plant["name"], source_location_name]
                costs = Dict()
                values = Dict("weight" => source_plant["outputs"][product_name])
                a = Arc(source, dest, costs, values)
                push!(arcs, a)
                push!(source.outgoing_arcs, a)
                push!(dest.incoming_arcs, a)
                
                # Transportation-arcs from one plant to another
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

export FlowArc

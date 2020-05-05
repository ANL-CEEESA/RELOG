# Copyright (C) 2019 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using JuMP, LinearAlgebra, Geodesy, Cbc, ProgressBars


mutable struct ManufacturingModel
    mip::JuMP.Model
    vars::DotDict
    instance::Instance
    graph::Graph
end


function build_model(instance::Instance, graph::Graph, optimizer)::ManufacturingModel
    model = ManufacturingModel(Model(optimizer), DotDict(), instance, graph)
    create_vars!(model)
    create_objective_function!(model)
    create_shipping_node_constraints!(model)
    create_process_node_constraints!(model)
    return model
end


function create_vars!(model::ManufacturingModel)
    mip, vars, graph = model.mip, model.vars, model.graph
    
    vars.flow = Dict(a => @variable(mip, lower_bound=0)
                    for a in graph.arcs)
   
    vars.dispose = Dict(n => @variable(mip,
                                       lower_bound = 0,
                                       upper_bound = n.location.disposal_limit[n.product])
                        for n in values(graph.plant_shipping_nodes))
    
    vars.open_plant = Dict(n => @variable(mip, binary=true)
                           for n in values(graph.process_nodes))
    
    vars.capacity = Dict(n => @variable(mip,
                                        lower_bound = 0,
                                        upper_bound = n.plant.max_capacity)
                         for n in values(graph.process_nodes))
    
    vars.expansion = Dict(n => @variable(mip,
                                         lower_bound = 0,
                                         upper_bound = (n.plant.max_capacity - n.plant.base_capacity))
                         for n in values(graph.process_nodes))
end


function create_objective_function!(model::ManufacturingModel)
    mip, vars, graph = model.mip, model.vars, model.graph
    obj = @expression(mip, 0 * @variable(mip))

    # Process node costs
    for n in values(graph.process_nodes)
        
        # Transportation and variable operating costs
        for a in n.incoming_arcs
            c = n.plant.input.transportation_cost * a.values["distance"]
            c += n.plant.variable_operating_cost
            add_to_expression!(obj, c, vars.flow[a])
        end
        
        # Fixed and opening costss
        add_to_expression!(obj,
                           n.plant.fixed_operating_cost + n.plant.opening_cost,
                           vars.open_plant[n])
        
        # Expansion costs
        add_to_expression!(obj, n.plant.expansion_cost,
                           vars.expansion[n])
    end

    # Disposal costs
    for n in values(graph.plant_shipping_nodes)
        add_to_expression!(obj,
                           n.location.disposal_cost[n.product],
                           vars.dispose[n])
    end

    @objective(mip, Min, obj)
end    


function create_shipping_node_constraints!(model::ManufacturingModel)
    mip, vars, graph = model.mip, model.vars, model.graph
    
    # Collection centers
    for n in graph.collection_shipping_nodes
        @constraint(mip, sum(vars.flow[a] for a in n.outgoing_arcs) == n.location.amount)
    end
    
    # Plants
    for n in graph.plant_shipping_nodes
        @constraint(mip,
            sum(vars.flow[a] for a in n.incoming_arcs) ==
            sum(vars.flow[a] for a in n.outgoing_arcs) + vars.dispose[n])
    end
end


function create_process_node_constraints!(model::ManufacturingModel)
    mip, vars, graph = model.mip, model.vars, model.graph

    for n in graph.process_nodes
        
        # Output amount is implied by input amount
        input_sum = isempty(n.incoming_arcs) ? 0 : sum(vars.flow[a] for a in n.incoming_arcs)
        for a in n.outgoing_arcs
            @constraint(mip, vars.flow[a] == a.values["weight"] * input_sum)
        end

        # If plant is closed, capacity is zero
        @constraint(mip, vars.capacity[n] <= n.plant.max_capacity * vars.open_plant[n])

        # Capacity is linked to expansion
        @constraint(mip, vars.capacity[n] <= n.plant.base_capacity + vars.expansion[n])

        # Input sum must be smaller than capacity
        @constraint(mip, input_sum <= vars.capacity[n])
    end
end

function solve(filename::String; optimizer=Cbc.Optimizer)
    println("Reading $filename...")
    instance = ReverseManufacturing.load(filename)
    
    println("Building graph...")
    graph = ReverseManufacturing.build_graph(instance)
    
    println("Building optimization model...")
    model = ReverseManufacturing.build_model(instance, graph, optimizer)
    
    println("Optimizing...")
    JuMP.optimize!(model.mip)
    
    println("Extracting solution...")
    return get_solution(model)
end

function get_solution(model::ManufacturingModel)
    mip, vars, graph, instance = model.mip, model.vars, model.graph, model.instance
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
    
    plant_to_process_node = Dict(n.plant => n for n in graph.process_nodes)
    plant_to_shipping_nodes = Dict()
    for p in instance.plants
        plant_to_shipping_nodes[p] = []
        for a in plant_to_process_node[p].outgoing_arcs
            push!(plant_to_shipping_nodes[p], a.dest)
        end
    end
    
    for plant in instance.plants
        skip_plant = true
        process_node = plant_to_process_node[plant]
        plant_dict = Dict{Any, Any}(
            "input" => Dict(),
            "output" => Dict(
                "send" => Dict(),
                "dispose" => Dict(),
            ),
            "total input" => 0.0,
            "total output" => Dict(),
            "latitude" => plant.latitude,
            "longitude" => plant.longitude,
            "capacity" => JuMP.value(vars.capacity[process_node]),
            "fixed cost" => JuMP.value(vars.open_plant[process_node]) * (plant.opening_cost + plant.fixed_operating_cost),
            "expansion cost" => JuMP.value(vars.expansion[process_node]) * plant.expansion_cost,
        )
        output["costs"]["fixed"] += plant_dict["fixed cost"]
        output["costs"]["expansion"] += plant_dict["expansion cost"]

        # Inputs
        for a in process_node.incoming_arcs
            val = JuMP.value(vars.flow[a])
            if val <= 1e-3
                continue
            end
            skip_plant = false
            dict = Dict{Any, Any}(
                "amount" => val,
                "distance" => a.values["distance"],
                "latitude" => a.source.location.latitude,
                "longitude" => a.source.location.longitude,
                "transportation cost" => a.source.product.transportation_cost * val,
                "variable operating cost" => plant.variable_operating_cost * val,
            )
            if a.source.location isa CollectionCenter
                plant_name = "Origin"
                location_name = a.source.location.name
            else
                plant_name = a.source.location.plant_name
                location_name = a.source.location.location_name
            end
            
            if plant_name ∉ keys(plant_dict["input"])
                plant_dict["input"][plant_name] = Dict()
            end
            plant_dict["input"][plant_name][location_name] = dict
            plant_dict["total input"] += val
            output["costs"]["transportation"] += dict["transportation cost"]
            output["costs"]["variable"] += dict["variable operating cost"]
        end

        # Outputs
        for shipping_node in plant_to_shipping_nodes[plant]
            product_name = shipping_node.product.name
            plant_dict["total output"][product_name] = 0.0
            plant_dict["output"]["send"][product_name] = product_dict = Dict()

            disposal_amount = JuMP.value(vars.dispose[shipping_node])
            if disposal_amount > 1e-5
                plant_dict["output"]["dispose"][product_name] = disposal_dict = Dict()
                disposal_dict["amount"] = JuMP.value(model.vars.dispose[shipping_node])
                disposal_dict["cost"] = disposal_dict["amount"] * plant.disposal_cost[shipping_node.product]
                plant_dict["total output"][product_name] += disposal_amount
                output["costs"]["disposal"] += disposal_dict["cost"]
            end

            for a in shipping_node.outgoing_arcs
                val = JuMP.value(vars.flow[a])
                if val <= 1e-3
                    continue
                end
                skip_plant = false
                dict = Dict(
                    "amount" => val,
                    "distance" => a.values["distance"],
                    "latitude" => a.dest.plant.latitude,
                    "longitude" => a.dest.plant.longitude,
                )
                if a.dest.plant.plant_name ∉ keys(product_dict)
                    product_dict[a.dest.plant.plant_name] = Dict()
                end
                product_dict[a.dest.plant.plant_name][a.dest.plant.location_name] = dict
                plant_dict["total output"][product_name] += val
            end
        end
            
        if !skip_plant
            if plant.plant_name ∉ keys(output["plants"])
                output["plants"][plant.plant_name] = Dict()
            end
            output["plants"][plant.plant_name][plant.location_name] = plant_dict
        end
    end

    output["costs"]["total"] = sum(values(output["costs"]))
    return output
end

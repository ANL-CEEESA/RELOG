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


function create_process_node_constraints!(model)
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
    
#     println("Extracting solution...")
#     return get_solution(instance, model)
end

# function get_solution(instance::ReverseManufacturingInstance,
#                       model::ReverseManufacturingModel)
#     vals = Dict()
#     for a in values(model.arcs)
#         vals[a] = JuMP.value(model.vars.flow[a])
#     end
#     for n in values(model.process_nodes)
#         vals[n] = JuMP.value(model.vars.open_plant[n])
#     end
    
#     output = Dict(
#         "plants" => Dict(),
#         "costs" => Dict(
#             "fixed" => 0.0,
#             "variable" => 0.0,
#             "transportation" => 0.0,
#             "disposal" => 0.0,
#             "total" => 0.0,
#             "expansion" => 0.0,
#         )
#     )

#     for (plant_name, plant) in instance.plants
#         skip_plant = true
#         plant_dict = Dict{Any, Any}()
#         input_product_name = plant["input"]
        
#         for (location_name, location) in plant["locations"]
#             skip_location = true
#             process_node = model.process_nodes[input_product_name, plant_name, location_name]

#             plant_loc_dict = Dict{Any, Any}(
#                 "input" => Dict(),
#                 "output" => Dict(
#                     "send" => Dict(),
#                     "dispose" => Dict(),
#                 ),
#                 "total input" => 0.0,
#                 "total output" => Dict(),
#                 "latitude" => location["latitude"],
#                 "longitude" => location["longitude"],
#                 "capacity" => round(JuMP.value(model.vars.capacity[process_node]), digits=2)
#             )

#             plant_loc_dict["fixed cost"] = round(vals[process_node] * process_node.fixed_cost, digits=5)
#             plant_loc_dict["expansion cost"] = round(JuMP.value(model.vars.expansion[process_node]) * process_node.expansion_cost, digits=5)
#             output["costs"]["fixed"] += plant_loc_dict["fixed cost"]
#             output["costs"]["expansion"] += plant_loc_dict["expansion cost"]

#             # Inputs
#             for a in process_node.incoming_arcs
#                 if vals[a] <= 1e-3
#                     continue
#                 end
#                 skip_plant = skip_location = false
#                 val = round(vals[a], digits=5)
#                 if !(a.source.plant_name in keys(plant_loc_dict["input"]))
#                     plant_loc_dict["input"][a.source.plant_name] = Dict()
#                 end
#                 if a.source.plant_name == "Origin"
#                     product = instance.products[a.source.product_name]
#                     source_location = product["initial amounts"][a.source.location_name]
#                 else
#                     source_plant = instance.plants[a.source.plant_name]
#                     source_location = source_plant["locations"][a.source.location_name]
#                 end
                
#                 # Input
#                 cost_transportation = round(a.costs["transportation"] * val, digits=5)
#                 plant_loc_dict["input"][a.source.plant_name][a.source.location_name] = dict = Dict()
#                 cost_variable = round(a.costs["variable"] * val, digits=5)
#                 dict["amount"] = val
#                 dict["distance"] = a.values["distance"]
#                 dict["transportation cost"] = cost_transportation
#                 dict["variable operating cost"] = cost_variable
#                 dict["latitude"] = source_location["latitude"]
#                 dict["longitude"] = source_location["longitude"]
#                 plant_loc_dict["total input"] += val
                
#                 output["costs"]["transportation"] += cost_transportation
#                 output["costs"]["variable"] += cost_variable
#             end

#             # Outputs
#             for output_product_name in keys(plant["outputs"])
#                 plant_loc_dict["total output"][output_product_name] = 0.0
#                 plant_loc_dict["output"]["send"][output_product_name] = product_dict = Dict()
#                 shipping_node = model.shipping_nodes[output_product_name, plant_name, location_name]

#                 disposal_amount = JuMP.value(model.vars.dispose[shipping_node])
#                 if disposal_amount > 1e-5
#                     plant_loc_dict["output"]["dispose"][output_product_name] = disposal_dict = Dict()
#                     disposal_dict["amount"] = JuMP.value(model.vars.dispose[shipping_node])
#                     disposal_dict["cost"] = disposal_dict["amount"] * shipping_node.disposal_cost
#                     plant_loc_dict["total output"][output_product_name] += disposal_amount
#                     output["costs"]["disposal"] += disposal_dict["cost"]
#                 end

#                 for a in shipping_node.outgoing_arcs
#                     if vals[a] <= 1e-3
#                         continue
#                     end
#                     skip_plant = skip_location = false
#                     if !(a.dest.plant_name in keys(product_dict))
#                         product_dict[a.dest.plant_name] = Dict{Any,Any}()
#                     end
#                     dest_location = instance.plants[a.dest.plant_name]["locations"][a.dest.location_name]
#                     val = round(vals[a], digits=5)
#                     plant_loc_dict["total output"][output_product_name] += val
#                     product_dict[a.dest.plant_name][a.dest.location_name] = dict = Dict()
#                     dict["amount"] = val
#                     dict["distance"] = a.values["distance"]
#                     dict["latitude"] = dest_location["latitude"]
#                     dict["longitude"] = dest_location["longitude"]
#                 end
#             end
            
#             if !skip_location
#                 plant_dict[location_name] = plant_loc_dict
#             end
#         end
#         if !skip_plant
#             output["plants"][plant_name] = plant_dict
#         end
#     end

#     output["costs"]["total"] = sum(values(output["costs"]))
#     return output
# end


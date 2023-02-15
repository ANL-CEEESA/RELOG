# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function build_graph(instance::Instance)::Graph
    arcs = []
    next_index = 0
    process_nodes = ProcessNode[]
    plant_shipping_nodes = ShippingNode[]
    collection_shipping_nodes = ShippingNode[]

    name_to_process_node_map = Dict{Tuple{AbstractString,AbstractString},ProcessNode}()
    collection_center_to_node = Dict()

    process_nodes_by_input_product =
        Dict(product => ProcessNode[] for product in instance.products)
    shipping_nodes_by_plant = Dict(plant => [] for plant in instance.plants)

    # Build collection center shipping nodes
    for center in instance.collection_centers
        node = ShippingNode(next_index, center, center.product, [], [])
        next_index += 1
        collection_center_to_node[center] = node
        push!(collection_shipping_nodes, node)
    end

    # Build process and shipping nodes for plants
    for plant in instance.plants
        pn = ProcessNode(next_index, plant, [], [])
        next_index += 1
        push!(process_nodes, pn)
        push!(process_nodes_by_input_product[plant.input], pn)

        name_to_process_node_map[(plant.plant_name, plant.location_name)] = pn

        for product in keys(plant.output)
            sn = ShippingNode(next_index, plant, product, [], [])
            next_index += 1
            push!(plant_shipping_nodes, sn)
            push!(shipping_nodes_by_plant[plant], sn)
        end
    end

    # Build arcs from collection centers to plants, and from one plant to another
    for source in [collection_shipping_nodes; plant_shipping_nodes]
        for dest in process_nodes_by_input_product[source.product]
            distance = _calculate_distance(
                source.location.latitude,
                source.location.longitude,
                dest.location.latitude,
                dest.location.longitude,
                instance.distance_metric,
            )
            values = Dict("distance" => distance)
            arc = Arc(source, dest, values)
            push!(source.outgoing_arcs, arc)
            push!(dest.incoming_arcs, arc)
            push!(arcs, arc)
        end
    end

    # Build arcs from process nodes to shipping nodes within a plant
    for source in process_nodes
        plant = source.location
        for dest in shipping_nodes_by_plant[plant]
            weight = plant.output[dest.product]
            values = Dict("weight" => weight)
            arc = Arc(source, dest, values)
            push!(source.outgoing_arcs, arc)
            push!(dest.incoming_arcs, arc)
            push!(arcs, arc)
        end
    end

    return Graph(
        process_nodes,
        plant_shipping_nodes,
        collection_shipping_nodes,
        arcs,
        name_to_process_node_map,
        collection_center_to_node,
    )
end


function print_graph_stats(instance::Instance, graph::Graph)::Nothing
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

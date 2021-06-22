# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Geodesy


abstract type Node end


mutable struct Arc
    source::Node
    dest::Node
    values::Dict{String,Float64}
end


mutable struct ProcessNode <: Node
    index::Int
    location::Plant
    incoming_arcs::Array{Arc}
    outgoing_arcs::Array{Arc}
end


mutable struct ShippingNode <: Node
    index::Int
    location::Union{Plant,CollectionCenter}
    product::Product
    incoming_arcs::Array{Arc}
    outgoing_arcs::Array{Arc}
end


mutable struct Graph
    process_nodes::Array{ProcessNode}
    plant_shipping_nodes::Array{ShippingNode}
    collection_shipping_nodes::Array{ShippingNode}
    arcs::Array{Arc}
end


function build_graph(instance::Instance)::Graph
    arcs = []
    next_index = 0
    process_nodes = ProcessNode[]
    plant_shipping_nodes = ShippingNode[]
    collection_shipping_nodes = ShippingNode[]

    process_nodes_by_input_product =
        Dict(product => ProcessNode[] for product in instance.products)
    shipping_nodes_by_plant = Dict(plant => [] for plant in instance.plants)

    # Build collection center shipping nodes
    for center in instance.collection_centers
        node = ShippingNode(next_index, center, center.product, [], [])
        next_index += 1
        push!(collection_shipping_nodes, node)
    end

    # Build process and shipping nodes for plants
    for plant in instance.plants
        pn = ProcessNode(next_index, plant, [], [])
        next_index += 1
        push!(process_nodes, pn)
        push!(process_nodes_by_input_product[plant.input], pn)

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
            distance = calculate_distance(
                source.location.latitude,
                source.location.longitude,
                dest.location.latitude,
                dest.location.longitude,
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

    return Graph(process_nodes, plant_shipping_nodes, collection_shipping_nodes, arcs)
end


function to_csv(graph::Graph)
    result = ""
    for a in graph.arcs
        result *= "$(a.source.index),$(a.dest.index)\n"
    end
    return result
end


function calculate_distance(source_lat, source_lon, dest_lat, dest_lon)::Float64
    x = LLA(source_lat, source_lon, 0.0)
    y = LLA(dest_lat, dest_lon, 0.0)
    return round(distance(x, y) / 1000.0, digits = 2)
end

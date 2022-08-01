# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using Geodesy

abstract type Node end

mutable struct Arc
    index::Int
    source::Node
    dest::Node
    values::Dict{String,Float64}
end

mutable struct ProcessNode <: Node
    index::Int
    location::Plant
    incoming_arcs::Vector{Arc}
    outgoing_arcs::Vector{Arc}
end

mutable struct ShippingNode <: Node
    index::Int
    location::Union{Plant,CollectionCenter}
    product::Product
    incoming_arcs::Vector{Arc}
    outgoing_arcs::Vector{Arc}
end

mutable struct Graph
    process_nodes::Vector{ProcessNode}
    plant_shipping_nodes::Vector{ShippingNode}
    collection_shipping_nodes::Vector{ShippingNode}
    arcs::Vector{Arc}
    name_to_process_node_map::Dict{Tuple{AbstractString,AbstractString},ProcessNode}
    collection_center_to_node::Dict{CollectionCenter,ShippingNode}
end

function Base.show(io::IO, instance::Graph)
    print(io, "RELOG graph with ")
    print(io, "$(length(instance.process_nodes)) process nodes, ")
    print(io, "$(length(instance.plant_shipping_nodes)) plant shipping nodes, ")
    print(io, "$(length(instance.collection_shipping_nodes)) collection shipping nodes, ")
    print(io, "$(length(instance.arcs)) arcs")
end

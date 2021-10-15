# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using DataStructures
using JSON
using JSONSchema
using Printf
using Statistics

mutable struct Product
    name::String
    transportation_cost::Vector{Float64}
    transportation_energy::Vector{Float64}
    transportation_emissions::Dict{String,Vector{Float64}}
    disposal_limit::Vector{Float64}
    disposal_cost::Vector{Float64}
    collection_centers::Vector
end

mutable struct CollectionCenter
    index::Int64
    name::String
    latitude::Float64
    longitude::Float64
    product::Product
    amount::Vector{Float64}
end

mutable struct PlantSize
    capacity::Float64
    variable_operating_cost::Vector{Float64}
    fixed_operating_cost::Vector{Float64}
    opening_cost::Vector{Float64}
end

mutable struct Plant
    index::Int64
    plant_name::String
    location_name::String
    input::Product
    output::Dict{Product,Float64}
    latitude::Float64
    longitude::Float64
    disposal_limit::Dict{Product,Vector{Float64}}
    disposal_cost::Dict{Product,Vector{Float64}}
    sizes::Vector{PlantSize}
    energy::Vector{Float64}
    emissions::Dict{String,Vector{Float64}}
    storage_limit::Float64
    storage_cost::Vector{Float64}
end

mutable struct Instance
    time::Int64
    products::Vector{Product}
    collection_centers::Vector{CollectionCenter}
    plants::Vector{Plant}
    building_period::Vector{Int64}
end

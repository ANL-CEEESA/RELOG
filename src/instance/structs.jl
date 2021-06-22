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
    transportation_cost::Array{Float64}
    transportation_energy::Array{Float64}
    transportation_emissions::Dict{String,Array{Float64}}
end

mutable struct CollectionCenter
    index::Int64
    name::String
    latitude::Float64
    longitude::Float64
    product::Product
    amount::Array{Float64}
end

mutable struct PlantSize
    capacity::Float64
    variable_operating_cost::Array{Float64}
    fixed_operating_cost::Array{Float64}
    opening_cost::Array{Float64}
end

mutable struct Plant
    index::Int64
    plant_name::String
    location_name::String
    input::Product
    output::Dict{Product,Float64}
    latitude::Float64
    longitude::Float64
    disposal_limit::Dict{Product,Array{Float64}}
    disposal_cost::Dict{Product,Array{Float64}}
    sizes::Array{PlantSize}
    energy::Array{Float64}
    emissions::Dict{String,Array{Float64}}
    storage_limit::Float64
    storage_cost::Array{Float64}
end

mutable struct Instance
    time::Int64
    products::Array{Product,1}
    collection_centers::Array{CollectionCenter,1}
    plants::Array{Plant,1}
    building_period::Array{Int64}
end

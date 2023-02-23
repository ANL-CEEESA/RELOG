# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using DataStructures
using JSON
using JSONSchema
using Printf
using Statistics

Base.@kwdef mutable struct Product
    acquisition_cost::Vector{Float64}
    collection_centers::Vector
    disposal_cost::Vector{Float64}
    disposal_limit::Vector{Float64}
    name::String
    transportation_cost::Vector{Float64}
    transportation_emissions::Dict{String,Vector{Float64}}
    transportation_energy::Vector{Float64}
end

Base.@kwdef mutable struct CollectionCenter
    amount::Vector{Float64}
    index::Int64
    latitude::Float64
    longitude::Float64
    name::String
    product::Product
end

Base.@kwdef mutable struct PlantSize
    capacity::Float64
    fixed_operating_cost::Vector{Float64}
    opening_cost::Vector{Float64}
    variable_operating_cost::Vector{Float64}
end

Base.@kwdef mutable struct Plant
    disposal_cost::Dict{Product,Vector{Float64}}
    disposal_limit::Dict{Product,Vector{Float64}}
    emissions::Dict{String,Vector{Float64}}
    energy::Vector{Float64}
    index::Int64
    initial_capacity::Float64
    input::Product
    latitude::Float64
    location_name::String
    longitude::Float64
    output::Dict{Product,Float64}
    plant_name::String
    sizes::Vector{PlantSize}
    storage_cost::Vector{Float64}
    storage_limit::Float64
end


abstract type DistanceMetric end

Base.@kwdef mutable struct KnnDrivingDistance <: DistanceMetric
    tree = nothing
    ratios = nothing
end

mutable struct EuclideanDistance <: DistanceMetric end

Base.@kwdef mutable struct Instance
    building_period::Vector{Int64}
    collection_centers::Vector{CollectionCenter}
    distance_metric::DistanceMetric
    plants::Vector{Plant}
    products::Vector{Product}
    time::Int64
end

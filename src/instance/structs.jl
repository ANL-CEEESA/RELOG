using OrderedCollections

Base.@kwdef struct Product
    name::String
    tr_cost::Vector{Float64}
    tr_energy::Vector{Float64}
    tr_emissions::OrderedDict{String,Vector{Float64}}
end

Base.@kwdef struct Center
    latitude::Float64
    longitude::Float64
    input::Union{Product,Nothing}
    outputs::Vector{Product}
    fixed_output::OrderedDict{Product,Vector{Float64}}
    var_output::OrderedDict{Product,Vector{Float64}}
    revenue::Vector{Float64}
    collection_cost::OrderedDict{Product,Vector{Float64}}
    operating_cost::Vector{Float64}
    disposal_limit::OrderedDict{Product,Vector{Float64}}
    disposal_cost::OrderedDict{Product,Vector{Float64}}
end

Base.@kwdef struct PlantCapacity
    size::Float64
    opening_cost::Vector{Float64}
    fix_operating_cost::Vector{Float64}
    var_operating_cost::Vector{Float64}
end

Base.@kwdef struct Plant
    latitude::Float64
    longitude::Float64
    input_mix::OrderedDict{Product,Vector{Float64}}
    output::OrderedDict{Product,Vector{Float64}}
    emissions::OrderedDict{String,Vector{Float64}}
    storage_cost::OrderedDict{Product,Vector{Float64}}
    storage_limit::OrderedDict{Product,Vector{Float64}}
    disposal_cost::OrderedDict{Product,Vector{Float64}}
    disposal_limit::OrderedDict{Product,Vector{Float64}}
    capacities::Vector{PlantCapacity}
    initial_capacity::Float64
end

Base.@kwdef struct Instance
    building_period::Vector{Int}
    centers_by_name::OrderedDict{String,Center}
    centers::Vector{Center}
    distance_metric::String
    products_by_name::OrderedDict{String,Product}
    products::Vector{Product}
    time_horizon::Int
    plants::Vector{Plant}
    plants_by_name::OrderedDict{String,Plant}
end

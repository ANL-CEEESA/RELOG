# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JSON, JSONSchema


mutable struct Product
    name::String
    transportation_cost::Array{Float64}
    transportation_energy::Array{Float64}
    transportation_emissions::Dict{String, Array{Float64}}
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
    output::Dict{Product, Float64}
    latitude::Float64
    longitude::Float64
    disposal_limit::Dict{Product, Array{Float64}}
    disposal_cost::Dict{Product, Array{Float64}}
    sizes::Array{PlantSize}
    energy::Array{Float64}
    emissions::Dict{String, Array{Float64}}
end


mutable struct Instance
    time::Int64
    products::Array{Product, 1}
    collection_centers::Array{CollectionCenter, 1}
    plants::Array{Plant, 1}
    building_period::Array{Int64}
end

function validate(json, schema)
    result = JSONSchema.validate(json, schema)
    if result !== nothing
        if result isa JSONSchema.SingleIssue
            path = join(result.path, " → ")
            if length(path) == 0
                path = "root"
            end
            msg = "$(result.msg) in $(path)"
        else
            msg = convert(String, result)
        end
        throw(msg)
    end
end


function load(path::String)::Instance
    basedir = dirname(@__FILE__)
    json = JSON.parsefile(path)
    json_schema = JSON.parsefile("$basedir/schemas/input.json")
    validate(json, Schema(json_schema))
    
    T = json["parameters"]["time horizon (years)"]
    json_schema["definitions"]["TimeSeries"]["minItems"] = T
    json_schema["definitions"]["TimeSeries"]["maxItems"] = T
    validate(json, Schema(json_schema))
    
    building_period = [1]
    if "building period (years)" in keys(json)
        building_period = json["building period (years)"]
    end
    
    plants = Plant[]
    products = Product[]
    collection_centers = CollectionCenter[]
    prod_name_to_product = Dict{String, Product}()
    
    # Create products
    for (product_name, product_dict) in json["products"]
        cost = product_dict["transportation cost (\$/km/tonne)"]
        energy = zeros(T)
        emissions = Dict()
        
        if "transportation energy (J/km/tonne)" in keys(product_dict)
            energy = product_dict["transportation energy (J/km/tonne)"]
        end
        
        if "transportation emissions (tonne/km/tonne)" in keys(product_dict)
            emissions = product_dict["transportation emissions (tonne/km/tonne)"]
        end
        
        product = Product(product_name, cost, energy, emissions)
        push!(products, product)
        prod_name_to_product[product_name] = product
        
        # Create collection centers
        if "initial amounts" in keys(product_dict)
            for (center_name, center_dict) in product_dict["initial amounts"]
                center = CollectionCenter(length(collection_centers) + 1,
                                          center_name,
                                          center_dict["latitude (deg)"],
                                          center_dict["longitude (deg)"],
                                          product,
                                          center_dict["amount (tonne)"])
                push!(collection_centers, center)
            end
        end
    end
    
    # Create plants
    for (plant_name, plant_dict) in json["plants"]
        input = prod_name_to_product[plant_dict["input"]]
        output = Dict()
        
        # Plant outputs
        if "outputs (tonne/tonne)" in keys(plant_dict)
            output = Dict(prod_name_to_product[key] => value
                          for (key, value) in plant_dict["outputs (tonne/tonne)"]
                          if value > 0)
        end
        
        energy = zeros(T)
        emissions = Dict()
        
        if "energy (GJ/tonne)" in keys(plant_dict)
            energy = plant_dict["energy (GJ/tonne)"]
        end
        
        if "emissions (tonne/tonne)" in keys(plant_dict)
            emissions = plant_dict["emissions (tonne/tonne)"]
        end
        
        for (location_name, location_dict) in plant_dict["locations"]
            sizes = PlantSize[]
            disposal_limit = Dict(p => [0.0 for t in 1:T] for p in keys(output))
            disposal_cost = Dict(p => [0.0 for t in 1:T] for p in keys(output))
            
            # Disposal
            if "disposal" in keys(location_dict)
                for (product_name, disposal_dict) in location_dict["disposal"]
                    limit = [1e8 for t in 1:T]
                    if "limit (tonne)" in keys(disposal_dict)
                       limit = disposal_dict["limit (tonne)"]
                    end
                    disposal_limit[prod_name_to_product[product_name]] = limit
                    disposal_cost[prod_name_to_product[product_name]] = disposal_dict["cost (\$/tonne)"]
                end
            end
            
            # Capacities
            for (capacity_name, capacity_dict) in location_dict["capacities (tonne)"]
                push!(sizes, PlantSize(parse(Float64, capacity_name),
                                       capacity_dict["variable operating cost (\$/tonne)"],
                                       capacity_dict["fixed operating cost (\$)"],
                                       capacity_dict["opening cost (\$)"]))
            end
            length(sizes) > 1 ||  push!(sizes, sizes[1])
            sort!(sizes, by = x -> x.capacity)
            
            # Validation: Capacities
            if length(sizes) != 2
                throw("At most two capacities are supported")
            end
            if sizes[1].variable_operating_cost != sizes[2].variable_operating_cost
                throw("Variable operating costs must be the same for all capacities")
            end

            plant = Plant(length(plants) + 1,
                          plant_name,
                          location_name,
                          input,
                          output,
                          location_dict["latitude (deg)"],
                          location_dict["longitude (deg)"],
                          disposal_limit,
                          disposal_cost,
                          sizes,
                          energy,
                          emissions)
            
            push!(plants, plant)
        end
    end
    
    return Instance(T, products, collection_centers, plants, building_period)
end

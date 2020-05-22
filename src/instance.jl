# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JSON, JSONSchema


mutable struct Product
    name::String
    transportation_cost::Array{Float64}
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
end


mutable struct Instance
    time::Int64
    products::Array{Product, 1}
    collection_centers::Array{CollectionCenter, 1}
    plants::Array{Plant, 1}
end


function load(path::String)::Instance
    basedir = dirname(@__FILE__)
    json = JSON.parsefile(path)
    schema = Schema(JSON.parsefile("$basedir/schemas/input.json"))
    
    result = JSONSchema.validate(json, schema)
    if result !== nothing
        if result isa JSONSchema.SingleIssue
            path = join(result.path, " → ")
            msg = "$(result.x) $(result.msg) in $(path)"
        else
            msg = convert(String, result)
        end
        throw(msg)
    end
    
    T = json["parameters"]["time periods"]
    plants = Plant[]
    products = Product[]
    collection_centers = CollectionCenter[]
    prod_name_to_product = Dict{String, Product}()
    
    # Create products
    for (product_name, product_dict) in json["products"]
        product = Product(product_name, product_dict["transportation cost"])
        push!(products, product)
        prod_name_to_product[product_name] = product
        
        # Create collection centers
        if "initial amounts" in keys(product_dict)
            for (center_name, center_dict) in product_dict["initial amounts"]
                center = CollectionCenter(length(collection_centers) + 1,
                                          center_name,
                                          center_dict["latitude"],
                                          center_dict["longitude"],
                                          product,
                                          center_dict["amount"])
                push!(collection_centers, center)
            end
        end
    end
    
    # Create plants
    for (plant_name, plant_dict) in json["plants"]
        input = prod_name_to_product[plant_dict["input"]]
        output = Dict()
        
        # Plant outputs
        if "outputs" in keys(plant_dict)
            output = Dict(prod_name_to_product[key] => value
                          for (key, value) in plant_dict["outputs"]
                          if value > 0)
        end
        
        for (location_name, location_dict) in plant_dict["locations"]
            sizes = PlantSize[]
            disposal_limit = Dict(p => [0.0 for t in 1:T] for p in keys(output))
            disposal_cost = Dict(p => [0.0 for t in 1:T] for p in keys(output))
            
            # Disposal
            if "disposal" in keys(location_dict)
                for (product_name, disposal_dict) in location_dict["disposal"]
                    limit = [1e8 for t in 1:T]
                    if "limit" in keys(disposal_dict)
                       limit = disposal_dict["limit"]
                    end
                    disposal_limit[prod_name_to_product[product_name]] = limit
                    disposal_cost[prod_name_to_product[product_name]] = disposal_dict["cost"]
                end
            end
            
            # Capacities
            for (capacity_name, capacity_dict) in location_dict["capacities"]
                push!(sizes, PlantSize(parse(Float64, capacity_name),
                                       capacity_dict["variable operating cost"],
                                       capacity_dict["fixed operating cost"],
                                       capacity_dict["opening cost"]))
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
                          location_dict["latitude"],
                          location_dict["longitude"],
                          disposal_limit,
                          disposal_cost,
                          sizes)
            
            push!(plants, plant)
        end
    end
    
    return Instance(T, products, collection_centers, plants)
end

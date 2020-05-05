# Copyright (C) 2020 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using JSON, JSONSchema


mutable struct Product
    name::String
    transportation_cost::Float64
end


mutable struct CollectionCenter
    name::String
    latitude::Float64
    longitude::Float64
    product::Product
    amount::Float64
end


mutable struct Plant
    plant_name::String
    location_name::String
    input::Product
    output::Dict{Product, Float64}
    latitude::Float64
    longitude::Float64
    variable_operating_cost::Float64
    fixed_operating_cost::Float64
    opening_cost::Float64
    base_capacity::Float64
    max_capacity::Float64
    expansion_cost::Float64
    disposal_limit::Dict{Product, Float64}
    disposal_cost::Dict{Product, Float64}
end


mutable struct Instance
    products::Array{Product, 1}
    collection_centers::Array{CollectionCenter, 1}
    plants::Array{Plant, 1}
end


function load(path::String)::Instance
    basedir = dirname(@__FILE__)
    json = JSON.parsefile(path)
    schema = Schema(JSON.parsefile("$basedir/schemas/input.json"))
    
    validation_results = JSONSchema.validate(json, schema)
    if validation_results !== nothing
        println(validation_results)
        throw("Invalid input file")
    end
    
    products = Product[]
    collection_centers = CollectionCenter[]
    plants = Plant[]
    
    product_name_to_product = Dict{String, Product}()
    
    # Create products
    for (product_name, product_dict) in json["products"]
        product = Product(product_name, product_dict["transportation cost"])
        push!(products, product)
        product_name_to_product[product_name] = product
        
        # Create collection centers
        if "initial amounts" in keys(product_dict)
            for (center_name, center_dict) in product_dict["initial amounts"]
                center = CollectionCenter(center_name,
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
        input = product_name_to_product[plant_dict["input"]]
        output = Dict()
        
        # Plant outputs
        if "outputs" in keys(plant_dict)
            output = Dict(product_name_to_product[key] => value
                          for (key, value) in plant_dict["outputs"]
                          if value > 0)
        end
        
        for (location_name, location_dict) in plant_dict["locations"]
            disposal_limit = Dict(p => 0.0 for p in keys(output))
            disposal_cost = Dict(p => 0.0 for p in keys(output))
            
            # Plant disposal
            if "disposal" in keys(location_dict)
                for (product_name, disposal_dict) in location_dict["disposal"]
                    disposal_limit[product_name_to_product[product_name]] = disposal_dict["limit"]
                    disposal_cost[product_name_to_product[product_name]] = disposal_dict["cost"]
                end
            end
            
            base_capacity = 1e8
            max_capacity = 1e8
            expansion_cost = 0
            
            if "base capacity" in keys(location_dict)
                base_capacity = location_dict["base capacity"]
            end
            
            if "max capacity" in keys(location_dict)
                max_capacity = location_dict["max capacity"]
            end
            
            if "expansion cost" in keys(location_dict)
                expansion_cost = location_dict["expansion cost"]
            end
            
            plant = Plant(plant_name,
                          location_name,
                          input,
                          output,
                          location_dict["latitude"],
                          location_dict["longitude"],
                          location_dict["variable operating cost"],
                          location_dict["fixed operating cost"],
                          location_dict["opening cost"],
                          base_capacity,
                          max_capacity,
                          expansion_cost,
                          disposal_limit,
                          disposal_cost)
            push!(plants, plant)
        end
    end
    
    return Instance(products, collection_centers, plants)
end

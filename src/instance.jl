# Copyright (C) 2020 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using Printf, JSON, JSONSchema
import Base.getindex, Base.time


struct Product
    name::String
    transportation_cost::Float64
end


struct CollectionCenter
    name::String
    latitude::Float64
    longitude::Float64
    product::Product
    amount::Float64
end


struct DisposalEntry
    product::Product
    cost::Float64
    limit::Float64
end


struct Plant
    name::String
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
    disposal::Array{DisposalEntry}
end


struct Instance
    products::Array{Product, 1}
    collection_centers::Array{CollectionCenter, 1}
    plants::Array{Plant, 1}
end


mutable struct ReverseManufacturingInstance
    json::Dict
    products::Dict
    plants::Dict
end


function Base.show(io::IO, instance::ReverseManufacturingInstance)
    n_plants = length(instance["plants"])
    n_products = length(instance["products"])
    print(io, "ReverseManufacturingInstance with ")
    print(io, "$n_plants plants, ")
    print(io, "$n_products products")
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
            disposal = DisposalEntry[]
            
            # Plant disposal
            if "disposal" in keys(location_dict)
                for (product_name, disposal_dict) in location_dict["disposal"]
                    push!(disposal, DisposalEntry(product_name_to_product[product_name],
                                                  disposal_dict["cost"],
                                                  disposal_dict["limit"]))
                end
            end
            
            base_capacity = Inf
            max_capacity = Inf
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
            
            plant = Plant(location_name,
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
                          disposal)
            push!(plants, plant)
        end
    end
    
    return Instance(products, collection_centers, plants)
end


function readfile(path::String)::ReverseManufacturingInstance
    basedir = dirname(@__FILE__)
    json = JSON.parsefile(path)
    schema = Schema(JSON.parsefile("$basedir/schemas/input.json"))
    
    validation_results = JSONSchema.validate(json, schema)
    if validation_results !== nothing
        println(validation_results)
        throw("Invalid input file")
    end
    
    for plant_name in keys(json["plants"])
        "outputs" in keys(json["plants"][plant_name]) || continue
        for output_name in keys(json["plants"][plant_name]["outputs"])
            if json["plants"][plant_name]["outputs"][output_name] < 1e-5
                delete!(json["plants"][plant_name]["outputs"], output_name)
            end
        end
    end
    
    products = Dict(key => json["products"][key]
                    for key in keys(json["products"]))
    plants = Dict(key => json["plants"][key]
                  for key in keys(json["plants"]))
    
    for product_name in keys(products)
        product = products[product_name]
        product["name"] = product_name
        product["input plants"] = []
        product["output plants"] = []
    end
    
    for plant_name in keys(plants)
        plant = plants[plant_name]
        plant["name"] = plant_name
        
        # Input product
        input_product = products[plant["input"]]
        plant["input product"] = input_product
        push!(input_product["input plants"], plant)
        
        # Output products
        if !haskey(plant, "outputs")
            plant["outputs"] = Dict()
        end
        for product_name in keys(plant["outputs"])
            product = products[product_name]
            push!(product["output plants"], plant)
        end
    end
    
    return ReverseManufacturingInstance(json, products, plants)
end


export ReverseManufacturingInstance

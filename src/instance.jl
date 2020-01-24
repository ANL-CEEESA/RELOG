# Copyright (C) 2020 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using Printf, JSON
import Base.getindex, Base.time

"""
    mutable struct ReverseManufacturingInstance

Representation of an instance of the Facility Location for Reverse Manufacturing problem.
"""
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

"""
    load(name::String)::ReverseManufacturingInstance

Loads an instance from the benchmark set.

Example
=======

    julia> ReverseManufacturing.load("samples/s1.json")

"""
function load(name::String) :: ReverseManufacturingInstance
    basedir = dirname(@__FILE__)
    return ReverseManufacturing.readfile("$basedir/../instances/$name.json")
end


"""
    readfile(path::String)::ReverseManufacturingInstance

Loads an instance from the given JSON file.

Example
=======

    julia> ReverseManufacturing.load("/home/user/instance.json")

"""    
function readfile(path::String)::ReverseManufacturingInstance
    json = JSON.parsefile(path)
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
        if haskey(plant, "outputs")
            for product_name in keys(plant["outputs"])
                product = products[product_name]
                push!(product["output plants"], plant)
            end
        end
    end
    
    return ReverseManufacturingInstance(json, products, plants)
end

export ReverseManufacturingInstance

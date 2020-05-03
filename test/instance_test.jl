# Copyright (C) 2020 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using ReverseManufacturing

@testset "Instance" begin
    @testset "load" begin
        basedir = dirname(@__FILE__)
        instance = ReverseManufacturing.load("$basedir/../instances/samples/s1.json")
        
        centers = instance.collection_centers
        plants = instance.plants
        products = instance.products
        
        plant_name_to_plant = Dict(p.name => p for p in plants)
        product_name_to_product = Dict(p.name => p for p in products)
        
        p2 = product_name_to_product["P2"]
        p3 = product_name_to_product["P3"]
        
        @test length(centers) == 10
        @test centers[1].name == "C1"
        @test centers[1].latitude == 7
        @test centers[1].latitude == 7
        @test centers[1].longitude == 7
        @test centers[1].amount == 934.56
        @test centers[1].product.name == "P1"
        
        @test length(plants) == 6

        plant = plant_name_to_plant["L1"]
        @test plant.name == "L1"
        @test plant.input.name == "P1"
        @test plant.latitude == 0
        @test plant.longitude == 0
        @test plant.opening_cost == 500
        @test plant.fixed_operating_cost == 30
        @test plant.variable_operating_cost == 30
        @test plant.base_capacity == 250
        @test plant.max_capacity == 1000
        @test plant.expansion_cost == 1
        
        @test length(plant.output) == 2
        @test plant.output[p2] == 0.2
        @test plant.output[p3] == 0.5
        
        @test length(plant.disposal) == 2
        @test plant.disposal[1].product.name == "P2"
        @test plant.disposal[1].cost == -10
        @test plant.disposal[1].limit == 1
        
        plant = plant_name_to_plant["L3"]
        @test plant.name == "L3"
        @test plant.input.name == "P2"
        @test plant.latitude == 25
        @test plant.longitude == 65
        @test plant.opening_cost == 3000
        @test plant.fixed_operating_cost == 50
        @test plant.variable_operating_cost == 50
        @test plant.base_capacity == Inf
        @test plant.max_capacity == Inf
        @test plant.expansion_cost == 0
    end
end


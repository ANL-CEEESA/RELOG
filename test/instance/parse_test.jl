# Copyright (C) 2020 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using RELOG

@testset "parse" begin
    basedir = dirname(@__FILE__)
    instance = RELOG.parsefile("$basedir/../../instances/s1.json")

    centers = instance.collection_centers
    plants = instance.plants
    products = instance.products
    location_name_to_plant = Dict(p.location_name => p for p in plants)
    product_name_to_product = Dict(p.name => p for p in products)

    @test length(centers) == 10
    @test centers[1].name == "C1"
    @test centers[1].latitude == 7
    @test centers[1].latitude == 7
    @test centers[1].longitude == 7
    @test centers[1].amount == [934.56, 934.56]
    @test centers[1].product.name == "P1"

    @test length(plants) == 6

    plant = location_name_to_plant["L1"]
    @test plant.plant_name == "F1"
    @test plant.location_name == "L1"
    @test plant.input.name == "P1"
    @test plant.latitude == 0
    @test plant.longitude == 0

    @test length(plant.sizes) == 2
    @test plant.sizes[1].capacity == 250
    @test plant.sizes[1].opening_cost == [500, 500]
    @test plant.sizes[1].fixed_operating_cost == [30, 30]
    @test plant.sizes[1].variable_operating_cost == [30, 30]
    @test plant.sizes[2].capacity == 1000
    @test plant.sizes[2].opening_cost == [1250, 1250]
    @test plant.sizes[2].fixed_operating_cost == [30, 30]
    @test plant.sizes[2].variable_operating_cost == [30, 30]

    p2 = product_name_to_product["P2"]
    p3 = product_name_to_product["P3"]
    @test length(plant.output) == 2
    @test plant.output[p2] == 0.2
    @test plant.output[p3] == 0.5
    @test plant.disposal_limit[p2] == [1, 1]
    @test plant.disposal_limit[p3] == [1, 1]
    @test plant.disposal_cost[p2] == [-10, -10]
    @test plant.disposal_cost[p3] == [-10, -10]

    plant = location_name_to_plant["L3"]
    @test plant.location_name == "L3"
    @test plant.input.name == "P2"
    @test plant.latitude == 25
    @test plant.longitude == 65

    @test length(plant.sizes) == 2
    @test plant.sizes[1].capacity == 1000.0
    @test plant.sizes[1].opening_cost == [3000, 3000]
    @test plant.sizes[1].fixed_operating_cost == [50, 50]
    @test plant.sizes[1].variable_operating_cost == [50, 50]
    @test plant.sizes[1] == plant.sizes[2]

    p4 = product_name_to_product["P4"]
    @test plant.output[p3] == 0.05
    @test plant.output[p4] == 0.8
    @test plant.disposal_limit[p3] == [1e8, 1e8]
    @test plant.disposal_limit[p4] == [0, 0]
end

@testset "parse (invalid)" begin
    basedir = dirname(@__FILE__)
    @test_throws String RELOG.parsefile("$basedir/../fixtures/s1-wrong-length.json")
end

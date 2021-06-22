# Copyright (C) 2020 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using RELOG

@testset "Instance" begin
    @testset "load" begin
        basedir = dirname(@__FILE__)
        instance = RELOG.parsefile("$basedir/../instances/s1.json")

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

    @testset "validate timeseries" begin
        @test_throws String RELOG.parsefile("fixtures/s1-wrong-length.json")
    end

    @testset "compress" begin
        basedir = dirname(@__FILE__)
        instance = RELOG.parsefile("$basedir/../instances/s1.json")
        compressed = RELOG._compress(instance)

        product_name_to_product = Dict(p.name => p for p in compressed.products)
        location_name_to_facility = Dict()
        for p in compressed.plants
            location_name_to_facility[p.location_name] = p
        end
        for c in compressed.collection_centers
            location_name_to_facility[c.name] = c
        end

        p1 = product_name_to_product["P1"]
        p2 = product_name_to_product["P2"]
        p3 = product_name_to_product["P3"]
        c1 = location_name_to_facility["C1"]
        l1 = location_name_to_facility["L1"]

        @test compressed.time == 1
        @test compressed.building_period == [1]

        @test p1.name == "P1"
        @test p1.transportation_cost ≈ [0.015]
        @test p1.transportation_energy ≈ [0.115]
        @test p1.transportation_emissions["CO2"] ≈ [0.051]
        @test p1.transportation_emissions["CH4"] ≈ [0.0025]

        @test c1.name == "C1"
        @test c1.amount ≈ [1869.12]

        @test l1.plant_name == "F1"
        @test l1.location_name == "L1"
        @test l1.energy ≈ [0.115]
        @test l1.emissions["CO2"] ≈ [0.051]
        @test l1.emissions["CH4"] ≈ [0.0025]
        @test l1.sizes[1].opening_cost ≈ [500]
        @test l1.sizes[2].opening_cost ≈ [1250]
        @test l1.sizes[1].fixed_operating_cost ≈ [60]
        @test l1.sizes[2].fixed_operating_cost ≈ [60]
        @test l1.sizes[1].variable_operating_cost ≈ [30]
        @test l1.sizes[2].variable_operating_cost ≈ [30]
        @test l1.disposal_limit[p2] ≈ [2.0]
        @test l1.disposal_limit[p3] ≈ [2.0]
        @test l1.disposal_cost[p2] ≈ [-10.0]
        @test l1.disposal_cost[p3] ≈ [-10.0]
    end
end

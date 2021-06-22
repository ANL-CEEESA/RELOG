# Copyright (C) 2020 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using RELOG

@testset "compress" begin
    basedir = dirname(@__FILE__)
    instance = RELOG.parsefile("$basedir/../../instances/s1.json")
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

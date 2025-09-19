using RELOG
using Test
using OrderedCollections

function instance_parse_test_1()
    instance = RELOG.parsefile(fixture("simple.json"))

    # Parameters
    @test instance.time_horizon == 4
    @test instance.building_period == [1]
    @test instance.distance_metric isa RELOG.EuclideanDistance

    # Products
    @test length(instance.products) == 4
    p1 = instance.products[1]
    @test p1.name == "P1"
    @test p1.tr_cost == [0.015, 0.015, 0.015, 0.015]
    @test p1.tr_energy == [0.12, 0.12, 0.12, 0.12]
    @test p1.tr_emissions ==
          Dict("CO2" => [0.052, 0.052, 0.052, 0.052], "CH4" => [0.003, 0.003, 0.003, 0.003])
    @test p1.disposal_limit == [1.0, 1.0, 1.0, 1.0]
    @test instance.products_by_name["P1"] === p1
    p2 = instance.products[2]
    p3 = instance.products[3]
    p4 = instance.products[4]

    # Centers
    @test length(instance.centers) == 3
    c1 = instance.centers[1]
    @test c1.latitude == 41.881
    @test c1.longitude == -87.623
    @test c1.input === p1
    @test c1.outputs == [p2, p3]
    @test c1.fixed_output == Dict(p2 => [100, 50, 0, 0], p3 => [20, 10, 0, 0])
    @test c1.var_output == Dict(p2 => [0.2, 0.25, 0.12], p3 => [0.25, 0.25, 0.25])
    @test c1.revenue == [12.0, 12.0, 12.0, 12.0]
    @test c1.operating_cost == [150.0, 150.0, 150.0, 150.0]
    @test c1.disposal_limit == Dict(p2 => [0, 0, 0, 0], p3 => [Inf, Inf, Inf, Inf])
    @test c1.disposal_cost ==
          Dict(p2 => [0.23, 0.23, 0.23, 0.23], p3 => [1.0, 1.0, 1.0, 1.0])
    c2 = instance.centers[2]
    @test c2.input === nothing
    @test c2.revenue == [0, 0, 0, 0]

    # Plants
    @test length(instance.plants) == 1
    l1 = instance.plants[1]
    @test l1.latitude == 44.881
    @test l1.longitude == -87.623
    @test l1.input_mix ==
          Dict(p1 => [0.953, 0.953, 0.953, 0.953], p2 => [0.047, 0.047, 0.047, 0.047])
    @test l1.output == Dict(p3 => [0.25, 0.25, 0.25, 0.25], p4 => [0.12, 0.12, 0.12, 0.12])
    @test l1.emissions == Dict("CO2" => [0.1, 0.1, 0.1, 0.1])
    @test l1.storage_cost == Dict(p1 => [0.1, 0.1, 0.1, 0.1], p2 => [0.1, 0.1, 0.1, 0.1])
    @test l1.storage_limit == Dict(p1 => [100, 100, 100, 100], p2 => [Inf, Inf, Inf, Inf])
    @test l1.disposal_cost == Dict(p3 => [0, 0, 0, 0], p4 => [0.86, 0.86, 0.86, 0.86])
    @test l1.disposal_limit ==
          Dict(p3 => [Inf, Inf, Inf, Inf], p4 => [1000.0, 1000.0, 1000.0, 1000.0])
    @test l1.initial_capacity == 250
    @test length(l1.capacities) == 2
    c1 = l1.capacities[1]
    @test c1.size == 100
    @test c1.opening_cost == [300, 400, 450, 475]
    @test c1.fix_operating_cost == [300, 300, 300, 300]
    @test c1.var_operating_cost == [5, 5, 5, 5]
    c2 = l1.capacities[2]
    @test c2.size == 500
    @test c2.opening_cost == [1000, 1000, 1000, 1000]
    @test c2.fix_operating_cost == [400, 400, 400, 400]
    @test c2.var_operating_cost == [5, 5, 5, 5]

    # Emissions
    @test length(instance.emissions) == 2
    co2 = instance.emissions[1]
    @test co2.name == "CO2"
    @test co2.limit == [1000.0, 1100.0, 1200.0, 1300.0]
    @test co2.penalty == [50.0, 55.0, 60.0, 65.0]
    @test instance.emissions_by_name["CO2"] === co2
    ch4 = instance.emissions[2]
    @test ch4.name == "CH4"
    @test ch4.limit == [Inf, Inf, Inf, Inf]
    @test ch4.penalty == [1200.0, 1200.0, 1200.0, 1200.0]
    @test instance.emissions_by_name["CH4"] === ch4
end


function instance_parse_test_2()
    # Should not crash
    RELOG.parsefile(fixture("boat_example.json"))
end

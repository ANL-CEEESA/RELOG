using RELOG
using Test
using OrderedCollections

function instance_parse_test()
    instance = RELOG.parsefile(fixture("simple.json"))

    # Parameters
    @test instance.time_horizon == 4
    @test instance.building_period == [1]
    @test instance.distance_metric == "driving"

    # Products
    @test length(instance.products) == 4
    p1 = instance.products[1]
    @test p1.name == "P1"
    @test p1.tr_cost == [0.015, 0.015, 0.015, 0.015]
    @test p1.tr_energy == [0.12, 0.12, 0.12, 0.12]
    @test p1.tr_emissions ==
          Dict("CO2" => [0.052, 0.052, 0.052, 0.052], "CH4" => [0.003, 0.003, 0.003, 0.003])
    @test instance.products_by_name["P1"] === p1
    p2 = instance.products[2]
    p3 = instance.products[3]

    # Centers
    @test length(instance.centers) == 3
    c1 = instance.centers[1]
    @test c1.latitude == 41.881
    @test c1.longitude == -87.623
    @test c1.input === p1
    @test c1.outputs == [p2, p3]
    @test c1.fixed_output == Dict(p2 => [100, 50, 0, 0], p3 => [20, 10, 0, 0])
    @test c1.var_output ==
          Dict(p2 => [0.12, 0.25, 0.12, 0.0], p3 => [0.25, 0.25, 0.25, 0.0])
    @test c1.revenue == [12.0, 12.0, 12.0, 12.0]
    @test c1.operating_cost == [150.0, 150.0, 150.0, 150.0]
    @test c1.disposal_limit == Dict(p2 => [0, 0, 0, 0], p3 => [Inf, Inf, Inf, Inf])
    @test c1.disposal_cost ==
          Dict(p2 => [0.23, 0.23, 0.23, 0.23], p3 => [1.0, 1.0, 1.0, 1.0])
    c2 = instance.centers[2]
    @test c2.input === nothing
    @test c2.revenue == [0, 0, 0, 0]

end

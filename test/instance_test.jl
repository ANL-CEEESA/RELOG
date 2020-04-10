# Copyright (C) 2020 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using ReverseManufacturing

@testset "Instance" begin
    instance = ReverseManufacturing.load("samples/s1")
    plants, products = instance.plants, instance.products
    @test length(products) == 4
    
    @test sort(collect(keys(plants))) == ["F1", "F2", "F3", "F4"]
    @test plants["F1"]["input product"] == products["P1"]
    
    @test sort(collect(keys(products))) == ["P1", "P2", "P3", "P4"]
    @test products["P1"]["input plants"] == [plants["F1"]]
    @test products["P1"]["transportation cost"] == 0.015
    @test products["P1"]["initial amounts"]["C1"]["latitude"] == 7.0
end

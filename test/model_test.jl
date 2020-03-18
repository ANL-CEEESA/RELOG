# Copyright (C) 2020 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using ReverseManufacturing, Cbc, JuMP, Printf

@testset "Model" begin
    instance = ReverseManufacturing.load("samples/s1")
    model = ReverseManufacturing.build_model(instance, Cbc.Optimizer)
    
    # Verify nodes
    @test ("P1", "Origin", "C1") in keys(model.shipping_nodes)
    @test ("P1", "Origin", "C3") in keys(model.shipping_nodes)
    @test ("P1", "Origin", "C8") in keys(model.shipping_nodes)
    @test ("P2", "F1", "L1") in keys(model.shipping_nodes)
    @test ("P2", "F1", "L2") in keys(model.shipping_nodes)
    @test ("P3", "F1", "L1") in keys(model.shipping_nodes)
    @test ("P3", "F1", "L2") in keys(model.shipping_nodes)
    @test ("P3", "F2", "L3") in keys(model.shipping_nodes)
    @test ("P3", "F2", "L4") in keys(model.shipping_nodes)
    @test ("P4", "F2", "L3") in keys(model.shipping_nodes)
    @test ("P4", "F2", "L4") in keys(model.shipping_nodes)
    @test ("P1", "F1", "L1") in keys(model.process_nodes)
    @test ("P1", "F1", "L2") in keys(model.process_nodes)
    @test ("P2", "F2", "L3") in keys(model.process_nodes)
    @test ("P2", "F2", "L4") in keys(model.process_nodes)
    @test ("P3", "F4", "L6") in keys(model.process_nodes)
    @test ("P4", "F3", "L5") in keys(model.process_nodes)
    
    # Verify some arcs
    p1_orig_c1 = model.shipping_nodes["P1", "Origin", "C1"]
    p1_f1_l1 = model.process_nodes["P1", "F1", "L1"]
    @test length(p1_orig_c1.outgoing_arcs) == 2
    @test length(p1_f1_l1.incoming_arcs) == 10
    
    arc = p1_orig_c1.outgoing_arcs[1]
    @test arc.dest.location_name == "L1"
    @test arc.values["distance"] == 1095.62
    @test round(arc.costs["transportation"], digits=2) == 1643.43
    @test arc.costs["variable"] == 70.0
    
    p2_f1_l1 = model.shipping_nodes["P2", "F1", "L1"]
    p2_f2_l3 = model.process_nodes["P2", "F2", "L3"]
    @test length(p2_f1_l1.incoming_arcs) == 1
    @test length(p2_f1_l1.outgoing_arcs) == 2
    
    arc = p2_f1_l1.incoming_arcs[1]
    @test arc.values["weight"] == 0.2
    @test isempty(arc.costs)
end

@testset "Solve" begin
    solution = ReverseManufacturing.solve("$(pwd())/../instances/samples/s1.json")
    @test "plants" in keys(solution)
    @test "F1" in keys(solution["plants"])
    @test "F2" in keys(solution["plants"])
    @test "F3" in keys(solution["plants"])
    @test "F4" in keys(solution["plants"])
    @test "L2" in keys(solution["plants"]["F1"])
    @test "total output" in keys(solution["plants"]["F1"]["L2"])
end
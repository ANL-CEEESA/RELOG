# Copyright (C) 2020 Argonne National Laboratory
# Written by Alinson Santos Xavier <axavier@anl.gov>

using RELOG

@testset "Graph" begin
    @testset "build_graph" begin
        basedir = dirname(@__FILE__)
        instance = RELOG.parsefile("$basedir/../instances/s1.json")
        graph = RELOG.build_graph(instance)
        process_node_by_location_name = Dict(n.location.location_name => n
                                             for n in graph.process_nodes)
        
        @test length(graph.plant_shipping_nodes) == 8
        @test length(graph.collection_shipping_nodes) == 10
        @test length(graph.process_nodes) == 6
        
        node = graph.collection_shipping_nodes[1]
        @test node.location.name == "C1"
        @test length(node.incoming_arcs) == 0
        @test length(node.outgoing_arcs) == 2
        @test node.outgoing_arcs[1].source.location.name == "C1"
        @test node.outgoing_arcs[1].dest.location.plant_name == "F1"
        @test node.outgoing_arcs[1].dest.location.location_name == "L1"
        @test node.outgoing_arcs[1].values["distance"] == 1095.62
        
        node = process_node_by_location_name["L1"]
        @test node.location.plant_name == "F1"
        @test node.location.location_name == "L1"
        @test length(node.incoming_arcs) == 10
        @test length(node.outgoing_arcs) == 2
        
        node = process_node_by_location_name["L3"]
        @test node.location.plant_name == "F2"
        @test node.location.location_name == "L3"
        @test length(node.incoming_arcs) == 2
        @test length(node.outgoing_arcs) == 2
        
        @test length(graph.arcs) == 38
    end
end


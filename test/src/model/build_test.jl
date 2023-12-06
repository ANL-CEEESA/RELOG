using RELOG
using Test
using HiGHS
using JuMP

function model_build_test_1()
    instance = RELOG.parsefile(fixture("simple.json"))
    model = RELOG.build_model(instance, optimizer = HiGHS.Optimizer, variable_names = true)
    y = model[:y]
    z_disp = model[:z_disp]
    z_input = model[:z_input]
    x = model[:x]
    obj = objective_function(model)
    # print(model)

    @test obj.terms[y["L1", "C3", "P4", 1]] == (
        111.118 + # transportation
        12.0 # revenue
    )
    @test obj.terms[y["C1", "L1", "P2", 4]] == (
        333.262 +  # transportation
        0.25 + # center collection cost
        5.0 # plant operating cost
    )
    @test obj.terms[z_disp["C1", "P2", 1]] == 0.23
    @test obj.constant == (
        150 * 4 * 3 # center operating cost
    )
    @test obj.terms[z_disp["L1", "P4", 2]] == 0.86
    @test obj.terms[x["L1", 1]] == (
        -100.0 + # opening cost
        300 # fixed operating cost
    )
    @test obj.terms[x["L1", 2]] == (
        -50.0 + # opening cost
        300 # fixed operating cost
    )
    @test obj.terms[x["L1", 3]] == (
        -25.0 + # opening cost
        300 # fixed operating cost
    )
    @test obj.terms[x["L1", 4]] == (
        475.0 + # opening cost
        300 # fixed operating cost
    )

    # Plants: Definition of total plant input
    @test repr(model[:eq_z_input]["L1", 1]) ==
          "eq_z_input[L1,1] : -y[C2,L1,P1,1] - y[C1,L1,P2,1] + z_input[L1,1] = 0"

    # Plants: Must meet input mix
    @test repr(model[:eq_input_mix]["L1", "P1", 1]) ==
          "eq_input_mix[L1,P1,1] : y[C2,L1,P1,1] - 0.953 z_input[L1,1] = 0"
    @test repr(model[:eq_input_mix]["L1", "P2", 1]) ==
          "eq_input_mix[L1,P2,1] : y[C1,L1,P2,1] - 0.047 z_input[L1,1] = 0"

    # Plants: Calculate amount produced
    @test repr(model[:eq_z_prod]["L1", "P3", 1]) ==
          "eq_z_prod[L1,P3,1] : z_prod[L1,P3,1] - 0.25 z_input[L1,1] = 0"
    @test repr(model[:eq_z_prod]["L1", "P4", 1]) ==
          "eq_z_prod[L1,P4,1] : z_prod[L1,P4,1] - 0.12 z_input[L1,1] = 0"

    # Plants: Produced material must be sent or disposed
    @test repr(model[:eq_balance]["L1", "P3", 1]) ==
          "eq_balance[L1,P3,1] : z_prod[L1,P3,1] - z_disp[L1,P3,1] = 0"
    @test repr(model[:eq_balance]["L1", "P4", 1]) ==
          "eq_balance[L1,P4,1] : -y[L1,C3,P4,1] + z_prod[L1,P4,1] - z_disp[L1,P4,1] = 0"

    # Plants: Capacity limit
    @test repr(model[:eq_capacity]["L1", 1]) ==
          "eq_capacity[L1,1] : -100 x[L1,1] + z_input[L1,1] ≤ 0"

    # Plants: Disposal limit
    @test repr(model[:eq_disposal_limit]["L1", "P4", 1]) ==
          "eq_disposal_limit[L1,P4,1] : z_disp[L1,P4,1] ≤ 1000"
    @test ("L1", "P3", 1) ∉ keys(model[:eq_disposal_limit])

    # Plants: Plant remains open
    @test repr(model[:eq_keep_open]["L1", 4]) ==
          "eq_keep_open[L1,4] : -x[L1,3] + x[L1,4] ≥ 0"
    @test repr(model[:eq_keep_open]["L1", 1]) == "eq_keep_open[L1,1] : x[L1,1] ≥ 0"

    # Plants: Building period
    @test ("L1", 1) ∉ keys(model[:eq_building_period])
    @test repr(model[:eq_building_period]["L1", 2]) ==
          "eq_building_period[L1,2] : x[L1,2] = 0"

    # Centers: Definition of total center input
    @test repr(model[:eq_z_input]["C1", 1]) ==
          "eq_z_input[C1,1] : -y[C2,C1,P1,1] + z_input[C1,1] = 0"

    # Centers: Calculate amount collected
    @test repr(model[:eq_z_collected]["C1", "P2", 1]) ==
          "eq_z_collected[C1,P2,1] : -0.2 z_input[C1,1] + z_collected[C1,P2,1] = 100"
    @test repr(model[:eq_z_collected]["C1", "P2", 2]) ==
          "eq_z_collected[C1,P2,2] : -0.25 z_input[C1,1] - 0.2 z_input[C1,2] + z_collected[C1,P2,2] = 50"
    @test repr(model[:eq_z_collected]["C1", "P2", 3]) ==
          "eq_z_collected[C1,P2,3] : -0.12 z_input[C1,1] - 0.25 z_input[C1,2] - 0.2 z_input[C1,3] + z_collected[C1,P2,3] = 0"
    @test repr(model[:eq_z_collected]["C1", "P2", 4]) ==
          "eq_z_collected[C1,P2,4] : -0.12 z_input[C1,2] - 0.25 z_input[C1,3] - 0.2 z_input[C1,4] + z_collected[C1,P2,4] = 0"

    # Centers: Collected products must be disposed or sent
    @test repr(model[:eq_balance]["C1", "P2", 1]) ==
          "eq_balance[C1,P2,1] : -y[C1,L1,P2,1] - z_disp[C1,P2,1] + z_collected[C1,P2,1] = 0"
    @test repr(model[:eq_balance]["C1", "P3", 1]) ==
          "eq_balance[C1,P3,1] : -z_disp[C1,P3,1] + z_collected[C1,P3,1] = 0"

    # Centers: Disposal limit
    @test repr(model[:eq_disposal_limit]["C1", "P2", 1]) ==
          "eq_disposal_limit[C1,P2,1] : z_disp[C1,P2,1] ≤ 0"
    @test ("C1", "P3", 1) ∉ keys(model[:eq_disposal_limit])
end


function model_build_test_2()
    instance = RELOG.parsefile(fixture("boat_example.json"))
    model = RELOG.build_model(instance, optimizer = HiGHS.Optimizer)
    optimize!(model) 
end

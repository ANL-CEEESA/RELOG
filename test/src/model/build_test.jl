using RELOG
using Test
using HiGHS
using JuMP

function model_build_test()
    instance = RELOG.parsefile(fixture("simple.json"))
    model = RELOG.build_model(instance, optimizer = HiGHS.Optimizer, variable_names = true)
    y = model[:y]
    z_disp = model[:z_disp]
    z_input = model[:z_input]
    z_process = model[:z_process]
    z_storage = model[:z_storage]
    z_em_tr = model[:z_em_tr]
    z_em_plant = model[:z_em_plant]
    z_exp = model[:z_exp]
    x = model[:x]
    obj = objective_function(model)
    # print(model)

    @test obj.terms[y["L1", "C3", "P4", 1]] == (
        111.118 * 0.015 # transportation
        - 12.0 # revenue
    )
    @test obj.terms[y["C1", "L1", "P2", 4]] == (
        333.262 * 0.015 +  # transportation
        0.25 + # center collection cost
        5.0 # plant operating cost
    )
    @test obj.terms[z_disp["C1", "P2", 1]] == 0.23
    @test obj.constant == (
        150 * 4 * 3 # center operating cost
        - 300 # initial opening cost
        - 150 * 1.75 # initial expansion
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

    # Test expansion variables exist and have correct initial values
    @test z_exp["L1", 0] == 150.0  # initial_capacity (250) - min_capacity (100)
    @test haskey(z_exp, ("L1", 1))
    @test haskey(z_exp, ("L1", 2))
    @test haskey(z_exp, ("L1", 3))
    @test haskey(z_exp, ("L1", 4))

    # Test expansion costs in objective function
    # R_expand[1] = (1000 - 300) / (500 - 100) = 1.75
    # R_expand[2] = (1000 - 400) / (500 - 100) = 1.5
    # R_fix_exp[1] = (400 - 300) / (500 - 100) = 0.25
    @test obj.terms[z_exp["L1", 1]] == (
        +1.75  # expansion cost[1]
        - 1.5  # expansion cost[2]
        + 0.25   # fixed operating cost[1]
    )

    # Test storage cost in objective function
    @test obj.terms[z_storage["L1", "P1", 1]] == 0.1  # P1 storage cost
    @test obj.terms[z_storage["L1", "P2", 1]] == 0.1  # P2 storage cost

    # Variables: Transportation emissions
    @test haskey(z_em_tr, ("CO2", "L1", "C3", "P4", 1))
    @test haskey(z_em_tr, ("CH4", "L1", "C3", "P4", 1))
    @test haskey(z_em_tr, ("CO2", "C2", "L1", "P1", 1))
    @test haskey(z_em_tr, ("CH4", "C2", "L1", "P1", 1))

    # Variables: Plant emissions
    @test haskey(z_em_plant, ("CO2", "L1", 1))
    @test haskey(z_em_plant, ("CO2", "L1", 2))
    @test haskey(z_em_plant, ("CO2", "L1", 3))
    @test haskey(z_em_plant, ("CO2", "L1", 4))

    # Plants: Definition of total plant input
    @test repr(model[:eq_z_input]["L1", 1]) ==
          "eq_z_input[L1,1] : -y[C2,L1,P1,1] - y[C1,L1,P2,1] + z_input[L1,1] = 0"

    # Plants: Definition of total processing amount
    @test repr(model[:eq_z_process]["L1", 1]) ==
          "eq_z_process[L1,1] : -z_input[L1,1] + z_storage[L1,P1,1] + z_storage[L1,P2,1] + z_process[L1,1] = 0"

    # Plants: Processing mix must have correct proportion
    @test repr(model[:eq_process_mix]["L1", "P1", 1]) ==
          "eq_process_mix[L1,P1,1] : y[C2,L1,P1,1] - z_storage[L1,P1,1] - 0.953 z_process[L1,1] = 0"
    @test repr(model[:eq_process_mix]["L1", "P2", 1]) ==
          "eq_process_mix[L1,P2,1] : y[C1,L1,P2,1] - z_storage[L1,P2,1] - 0.047 z_process[L1,1] = 0"

    # Plants: Calculate amount produced
    @test repr(model[:eq_z_prod]["L1", "P3", 1]) ==
          "eq_z_prod[L1,P3,1] : z_prod[L1,P3,1] - 0.25 z_process[L1,1] = 0"
    @test repr(model[:eq_z_prod]["L1", "P4", 1]) ==
          "eq_z_prod[L1,P4,1] : z_prod[L1,P4,1] - 0.12 z_process[L1,1] = 0"

    # Plants: Produced material must be sent or disposed
    @test repr(model[:eq_balance]["L1", "P3", 1]) ==
          "eq_balance[L1,P3,1] : z_prod[L1,P3,1] - z_disp[L1,P3,1] = 0"
    @test repr(model[:eq_balance]["L1", "P4", 1]) ==
          "eq_balance[L1,P4,1] : -y[L1,C3,P4,1] + z_prod[L1,P4,1] - z_disp[L1,P4,1] = 0"

    # Plants: Processing limit (capacity constraint)
    @test repr(model[:eq_process_limit]["L1", 1]) ==
          "eq_process_limit[L1,1] : -100 x[L1,1] - z_exp[L1,1] + z_process[L1,1] ≤ 0"

    # Plants: Expansion upper bound
    @test repr(model[:eq_exp_ub]["L1", 1]) ==
          "eq_exp_ub[L1,1] : -400 x[L1,1] + z_exp[L1,1] ≤ 0"

    # Plants: Disposal limit
    @test repr(model[:eq_disposal_limit]["L1", "P4", 1]) ==
          "eq_disposal_limit[L1,P4,1] : z_disp[L1,P4,1] ≤ 1000"
    @test ("L1", "P3", 1) ∉ keys(model[:eq_disposal_limit])

    # Plants: Plant remains open
    @test repr(model[:eq_keep_open]["L1", 4]) ==
          "eq_keep_open[L1,4] : -x[L1,3] + x[L1,4] ≥ 0"
    @test repr(model[:eq_keep_open]["L1", 1]) == "eq_keep_open[L1,1] : x[L1,1] ≥ 1"

    # Plants: Building period
    @test ("L1", 1) ∉ keys(model[:eq_building_period])
    @test repr(model[:eq_building_period]["L1", 2]) ==
          "eq_building_period[L1,2] : -x[L1,1] + x[L1,2] ≤ 0"

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

    # Global disposal limit
    @test repr(model[:eq_disposal_limit]["P1", 1]) ==
          "eq_disposal_limit[P1,1] : z_disp[C2,P1,1] ≤ 1"
    @test repr(model[:eq_disposal_limit]["P2", 1]) ==
          "eq_disposal_limit[P2,1] : z_disp[C1,P2,1] ≤ 2"
    @test repr(model[:eq_disposal_limit]["P3", 1]) ==
          "eq_disposal_limit[P3,1] : z_disp[L1,P3,1] + z_disp[C1,P3,1] ≤ 5"
    @test ("P4", 1) ∉ keys(model[:eq_disposal_limit])

    # Products: Transportation emissions
    @test repr(model[:eq_emission_tr]["CH4", "L1", "C3", "P4", 1]) ==
          "eq_emission_tr[CH4,L1,C3,P4,1] : -0.333354 y[L1,C3,P4,1] + z_em_tr[CH4,L1,C3,P4,1] = 0"

    # Plants: Plant emissions (updated to use z_process)
    @test repr(model[:eq_emission_plant]["CO2", "L1", 1]) ==
          "eq_emission_plant[CO2,L1,1] : -0.1 z_process[L1,1] + z_em_plant[CO2,L1,1] = 0"

    # Objective function: Emissions penalty costs
    @test obj.terms[z_em_plant["CO2", "L1", 1]] == 50.0  # CO2 penalty at time 1
    @test obj.terms[z_em_plant["CO2", "L1", 2]] == 55.0  # CO2 penalty at time 2
    @test obj.terms[z_em_plant["CO2", "L1", 3]] == 60.0  # CO2 penalty at time 3
    @test obj.terms[z_em_plant["CO2", "L1", 4]] == 65.0  # CO2 penalty at time 4
    @test obj.terms[z_em_tr["CO2", "L1", "C3", "P4", 1]] == 50.0  # CO2 transportation penalty at time 1
    @test obj.terms[z_em_tr["CH4", "L1", "C3", "P4", 1]] == 1200.0  # CH4 transportation penalty at time 1

    # Global emissions limit constraints
    @test repr(model[:eq_emission_limit]["CO2", 1]) ==
          "eq_emission_limit[CO2,1] : z_em_tr[CO2,C2,L1,P1,1] + z_em_tr[CO2,C2,C1,P1,1] + z_em_tr[CO2,C1,L1,P2,1] + z_em_tr[CO2,L1,C3,P4,1] + z_em_plant[CO2,L1,1] ≤ 1000"
    @test ("CH4", 1) ∉ keys(model[:eq_emission_limit])

    # Test storage variables exist
    @test haskey(z_storage, ("L1", "P1", 1))
    @test haskey(z_storage, ("L1", "P2", 1))
    @test haskey(z_process, ("L1", 1))
    @test haskey(z_process, ("L1", 2))
    @test haskey(z_process, ("L1", 3))
    @test haskey(z_process, ("L1", 4))

    # Test initial storage values
    @test z_storage["L1", "P1", 0] == 0
    @test z_storage["L1", "P2", 0] == 0

    # Test storage limit constraints (P1 has limit of 100, P2 has no limit)
    @test haskey(model[:eq_storage_limit], ("L1", "P1", 1))
    @test repr(model[:eq_storage_limit]["L1", "P1", 1]) ==
          "eq_storage_limit[L1,P1,1] : z_storage[L1,P1,1] ≤ 100"
    @test ("L1", "P2", 1) ∉ keys(model[:eq_storage_limit])  # P2 has no storage limit

    # Test final storage constraints exist
    @test haskey(model[:eq_storage_final], ("L1", "P1"))
    @test haskey(model[:eq_storage_final], ("L1", "P2"))
    @test repr(model[:eq_storage_final]["L1", "P1"]) ==
          "eq_storage_final[L1,P1] : z_storage[L1,P1,4] = 0"
    @test repr(model[:eq_storage_final]["L1", "P2"]) ==
          "eq_storage_final[L1,P2] : z_storage[L1,P2,4] = 0"
end

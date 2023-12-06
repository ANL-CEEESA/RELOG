using RELOG
using Test
using HiGHS
using JuMP

function model_build_test()
    instance = RELOG.parsefile(fixture("simple.json"))
    model = RELOG.build_model(instance, optimizer=HiGHS.Optimizer, variable_names=true)
    print(model)
end
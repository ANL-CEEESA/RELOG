function report_tests()
    # Load and solve the boat example
    instance = RELOG.parsefile(fixture("boat_example.json"))
    model = RELOG.build_model(instance, optimizer = HiGHS.Optimizer, variable_names = true)
    optimize!(model)
    write_to_file(model, "tmp/model.lp")
    RELOG.write_plants_report(model, "tmp/plants.csv")
    RELOG.write_plant_outputs_report(model, "tmp/plant_outputs.csv")
    RELOG.write_centers_report(model, "tmp/centers.csv")
    RELOG.write_center_outputs_report(model, "tmp/center_outputs.csv")
    RELOG.write_transportation_report(model, "tmp/transportation.csv")
end

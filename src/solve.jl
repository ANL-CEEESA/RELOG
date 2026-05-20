# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function solve(path::String; optimizer)::Nothing
    basename = replace(path, r"\.json$" => "")
    instance = parsefile(path)
    model = build_model(instance; optimizer = optimizer)
    optimize!(model)
    write_plants_report(model, "$basename.plants.csv")
    write_plant_inputs_report(model, "$basename.plant_inputs.csv")
    write_plant_outputs_report(model, "$basename.plant_outputs.csv")
    write_plant_emissions_report(model, "$basename.plant_emissions.csv")
    write_transportation_report(model, "$basename.transportation.csv")
    write_transportation_emissions_report(model, "$basename.transportation_emissions.csv")
    write_centers_report(model, "$basename.centers.csv")
    write_center_outputs_report(model, "$basename.center_outputs.csv")
    return nothing
end

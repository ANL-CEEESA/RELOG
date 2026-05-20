# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function solve(
    path::String;
    optimizer,
    max_plants::Union{Int,Nothing} = nothing,
)::Nothing
    basename = replace(path, r"\.json$" => "")
    instance = parsefile(path)

    if max_plants !== nothing
        instance = _reduce_and_restrict(instance; optimizer, max_plants)
    end

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

"""
    _reduce_and_restrict(instance; optimizer, max_plants) -> Instance

Heuristic pre-solve: reduce the instance to at most `max_plants` plants,
solve the reduced problem to identify which plants are utilized, then
return a restricted version of the *original* instance containing only
the plants that were utilized in the reduced solution.
"""
function _reduce_and_restrict(
    instance::Instance;
    optimizer,
    max_plants::Int,
)::Instance
    # Step 1: Reduce the instance by merging nearby plants
    reduced, merge_map = reduce_plants(instance; max_plants = max_plants)

    # Step 2: Solve the reduced problem
    reduced_model = build_model(reduced; optimizer = optimizer)
    optimize!(reduced_model)

    # Step 3: Identify utilized plants in the reduced solution.
    # A reduced plant is utilized if it is operational (x > 0.5) at any time.
    T = reduced.time_horizon
    utilized_reduced = Set{String}()
    for p in reduced.plants
        for t in 1:T
            if JuMP.value(reduced_model[:x][p.name, t]) > 0.5
                push!(utilized_reduced, p.name)
                break
            end
        end
    end

    # Step 4: Map back to original plant names via merge_map
    utilized_original = Set{String}()
    for rname in utilized_reduced
        for orig_name in merge_map[rname]
            push!(utilized_original, orig_name)
        end
    end

    # Step 5: Build a restricted instance with only the utilized plants
    restricted_plants = [p for p in instance.plants if p.name in utilized_original]
    restricted_plants_by_name = OrderedDict{String,Plant}(
        p.name => p for p in restricted_plants
    )

    return Instance(;
        building_period = instance.building_period,
        centers_by_name = instance.centers_by_name,
        centers = instance.centers,
        distance_metric = instance.distance_metric,
        products_by_name = instance.products_by_name,
        products = instance.products,
        time_horizon = instance.time_horizon,
        plants = restricted_plants,
        plants_by_name = restricted_plants_by_name,
        emissions_by_name = instance.emissions_by_name,
        emissions = instance.emissions,
    )
end

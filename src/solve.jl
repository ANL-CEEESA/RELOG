# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function solve(
    path::String;
    optimizer,
    max_plants::Union{Int,Nothing} = nothing,
)::Nothing
    log_info("RELOG: Supply Chain Analysis and Optimization, version 0.5.0")
    log_info("Copyright (C) 2020-2026, UChicago Argonne, LLC")

    log_info("Parsing: $path")
    basename = replace(path, r"\.json$" => "")
    instance = parsefile(path)

    log_info(
        "Parsed instance with " *
        "$(length(instance.plants)) plants, "*
        "$(length(instance.centers)) centers, "*
        "$(length(instance.products)) products, "*
        "$(instance.time_horizon) time steps"
    )

    if max_plants !== nothing
        instance, allowed_arcs = _reduce_and_restrict(instance; optimizer, max_plants, path)
        model = build_model(instance; optimizer = optimizer, allowed_arcs = allowed_arcs)
    else
        model = build_model(instance; optimizer = optimizer)
    end
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
    _reduce_and_restrict(instance; optimizer, max_plants) -> (Instance, Set{Tuple{String, String, String}})

Heuristic pre-solve: reduce the instance to at most `max_plants` plants,
solve the reduced problem to identify which plants are utilized, then
return a restricted version of the *original* instance containing only
the plants that were utilized in the reduced solution. Also returns the
set of allowed arcs expanded from the reduced model solution.
"""
function _reduce_and_restrict(
    instance::Instance;
    optimizer,
    max_plants::Int,
    path::String = "",
)::Tuple{Instance,Set{Tuple{String, String, String}}}

    log_info("Reducing instance to at most $(max_plants) plants")
    reduced, merge_map = reduce_plants(instance; max_plants = max_plants)

    log_info("Building reduced model...")
    reduced_model = build_model(reduced; optimizer = optimizer)

    log_info("Optimizing reduced model...")
    optimize!(reduced_model)

    log_info("Identifying utilized plants...")
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
    utilized_original = Set{String}()
    for rname in utilized_reduced
        for orig_name in merge_map[rname]
            push!(utilized_original, orig_name)
        end
    end
    restricted_plants = [p for p in instance.plants if p.name in utilized_original]
    restricted_plants_by_name = OrderedDict{String,Plant}(
        p.name => p for p in restricted_plants
    )
    log_info("$(length(utilized_reduced)) super plants utilized, mapping back to $(length(utilized_original)) original plants")

    log_info("Identifying utilized arcs...")
    tol = 1e-7
    allowed_arcs = Set{Tuple{String, String, String}}()
    arc_count = 0
    for (src, dst, m) in reduced_model.ext[:E]
        src_name = src.name
        dst_name = dst.name

        has_flow = false
        for t in 1:T
            if JuMP.value(reduced_model[:y][src_name, dst_name, m.name, t]) > tol
                has_flow = true
                break
            end
        end

        if !has_flow
            continue
        end

        arc_count += 1

        src_is_plant = src_name in keys(merge_map)
        dst_is_plant = dst_name in keys(merge_map)

        if src_is_plant && dst_is_plant
            for orig_src in merge_map[src_name]
                for orig_dst in merge_map[dst_name]
                    push!(allowed_arcs, (orig_src, orig_dst, m.name))
                end
            end
        elseif src_is_plant && !dst_is_plant
            for orig_src in merge_map[src_name]
                push!(allowed_arcs, (orig_src, dst_name, m.name))
            end
        elseif !src_is_plant && dst_is_plant
            for orig_dst in merge_map[dst_name]
                push!(allowed_arcs, (src_name, orig_dst, m.name))
            end
        else
            push!(allowed_arcs, (src_name, dst_name, m.name))
        end
    end
    log_info("$(arc_count) arcs utilized in reduced solution, mapping back to $(length(allowed_arcs)) original arcs")

    restricted_instance = Instance(;
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

    return (restricted_instance, allowed_arcs)
end

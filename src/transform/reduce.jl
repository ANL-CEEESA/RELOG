# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using OrderedCollections

"""
    reduce_plants(instance::Instance; max_plants::Int)
        -> (Instance, Dict{String, Vector{String}})

Reduce problem size by iteratively merging the two nearest plants of the
same type until the number of plants is at most `max_plants`.

Returns a tuple of:
- A new Instance with at most `max_plants` plants.
- A merge map from each resulting plant name to the list of original plant
  names it was formed from. Plants that were never merged map to a
  single-element vector containing their own name.

If no further merges are possible (every type group has fewer than 2
plants), returns the instance as reduced so far.
"""
function reduce_plants(
    instance::Instance;
    max_plants::Int,
)::Tuple{Instance,Dict{String,Vector{String}}}
    plants = copy(instance.plants)

    # Initialize merge map: each original plant maps to itself
    merge_map = Dict{String,Vector{String}}(
        p.name => [p.name] for p in plants
    )

    while length(plants) > max_plants
        groups = _group_plants_by_type(plants)
        pair = _find_global_nearest_pair(plants, groups)
        pair === nothing && break

        i, j = pair
        merged = _merge_plants(plants[i], plants[j])

        # Union the constituent lists from both parents
        merge_map[merged.name] = vcat(
            merge_map[plants[i].name],
            merge_map[plants[j].name],
        )
        delete!(merge_map, plants[i].name)
        delete!(merge_map, plants[j].name)

        # Remove the higher index first to keep the lower index valid
        hi, lo = max(i, j), min(i, j)
        deleteat!(plants, hi)
        deleteat!(plants, lo)
        push!(plants, merged)
    end

    new_plants_by_name = OrderedDict{String,Plant}(p.name => p for p in plants)

    reduced = Instance(;
        building_period = instance.building_period,
        centers_by_name = instance.centers_by_name,
        centers = instance.centers,
        distance_metric = instance.distance_metric,
        products_by_name = instance.products_by_name,
        products = instance.products,
        time_horizon = instance.time_horizon,
        plants = plants,
        plants_by_name = new_plants_by_name,
        emissions_by_name = instance.emissions_by_name,
        emissions = instance.emissions,
    )

    return (reduced, merge_map)
end

"""
    _find_global_nearest_pair(plants, groups)

Find the nearest pair of plants across all type groups. Returns (i, j) plant
indices or nothing if no group has at least 2 plants.
"""
function _find_global_nearest_pair(
    plants::Vector{Plant},
    groups::Dict{Int,Vector{Int}},
)
    best_dist = Inf
    best_pair = nothing

    for (_, indices) in groups
        length(indices) < 2 && continue
        pair = _find_nearest_pair_in_group(plants, indices)
        pair === nothing && continue
        i, j = pair
        d = _calculate_distance(
            plants[i].latitude, plants[i].longitude,
            plants[j].latitude, plants[j].longitude,
            EuclideanDistance(),
        )
        if d < best_dist
            best_dist = d
            best_pair = pair
        end
    end

    return best_pair
end

function _product_dict_key(d::OrderedDict{Product,Vector{Float64}})
    return tuple(((k.name, v) for (k, v) in d)...)
end

function _string_dict_key(d::OrderedDict{String,Vector{Float64}})
    return tuple(((k, v) for (k, v) in d)...)
end

"""
    _group_plants_by_type(plants)

Group plant indices by type. Each distinct type key is assigned an increasing
integer ID (starting at 1, in order of first appearance). Returns a
`Dict{Int,Vector{Int}}` mapping group ID to the plant indices in that group.

The type key captures the core process-defining parameters (input mix and
output ratios) but excludes location, capacity sizes/costs, limits, costs,
emissions, and initial capacity. Fields that differ across plants in the
same group (emissions, disposal cost, storage cost, variable operating cost)
are averaged during merging.
"""
function _group_plants_by_type(plants::Vector{Plant})::Dict{Int,Vector{Int}}
    key_to_id = Dict{Any,Int}()
    groups = Dict{Int,Vector{Int}}()
    next_id = 1
    for (i, p) in enumerate(plants)
        key = (
            _product_dict_key(p.input_mix),
            _product_dict_key(p.output),
        )
        id = get!(key_to_id, key) do
            id = next_id
            next_id += 1
            id
        end
        push!(get!(groups, id, Int[]), i)
    end
    return groups
end

"""
    _find_nearest_pair_in_group(plants, indices)

Find the pair of plants within a single type group that are closest together
(Euclidean distance on lat/lon). Returns (i, j) plant indices or nothing.
The `indices` vector must have at least 2 elements.
"""
function _find_nearest_pair_in_group(
    plants::Vector{Plant},
    indices::Vector{Int},
)
    best_dist = Inf
    best_pair = nothing

    for a in 1:length(indices)
        for b in (a+1):length(indices)
            i, j = indices[a], indices[b]
            d = _calculate_distance(
                plants[i].latitude, plants[i].longitude,
                plants[j].latitude, plants[j].longitude,
                EuclideanDistance(),
            )
            if d < best_dist
                best_dist = d
                best_pair = (i, j)
            end
        end
    end

    return best_pair
end

"""
    _merge_plants(p1::Plant, p2::Plant) -> Plant

Merge two plants of the same type into a single superplant.
"""
function _merge_plants(p1::Plant, p2::Plant)::Plant
    c1_min, c1_max = p1.capacities[1], p1.capacities[2]
    c2_min, c2_max = p2.capacities[1], p2.capacities[2]

    q_size_min = min(c1_min.size, c2_min.size)
    q_size_max = c1_max.size + c2_max.size

    T = length(c1_min.opening_cost)

    # Capacity level 1 (min): average costs from the two plants' min levels
    q_opening_cost_min = _avg(c1_min.opening_cost, c2_min.opening_cost)
    q_fix_op_cost_min = _avg(c1_min.fix_operating_cost, c2_min.fix_operating_cost)

    # Capacity level 2 (max): sum costs from the two plants' max levels
    q_opening_cost_max = _sum(c1_max.opening_cost, c2_max.opening_cost)
    q_fix_op_cost_max = _sum(c1_max.fix_operating_cost, c2_max.fix_operating_cost)

    # Variable operating cost: average (may differ across plants)
    q_var_op_cost = _avg(c1_min.var_operating_cost, c2_min.var_operating_cost)

    cap_min = PlantCapacity(;
        size = q_size_min,
        opening_cost = q_opening_cost_min,
        fix_operating_cost = q_fix_op_cost_min,
        var_operating_cost = q_var_op_cost,
    )
    cap_max = PlantCapacity(;
        size = q_size_max,
        opening_cost = q_opening_cost_max,
        fix_operating_cost = q_fix_op_cost_max,
        var_operating_cost = q_var_op_cost,
    )

    # Emissions: average, union of keys (missing → zero)
    emissions = _avg_string_dicts(p1.emissions, p2.emissions, T)

    # Storage cost: average, union of keys (missing → zero)
    storage_cost = _avg_product_dicts(p1.storage_cost, p2.storage_cost, T)

    # Disposal cost: average, union of keys (missing → zero)
    disposal_cost = _avg_product_dicts(p1.disposal_cost, p2.disposal_cost, T)

    # Disposal limits: sum, union of keys (missing → Inf)
    disposal_limit = _sum_product_dicts(p1.disposal_limit, p2.disposal_limit, T)

    # Storage limits: sum, union of keys (missing → Inf)
    storage_limit = _sum_product_dicts(p1.storage_limit, p2.storage_limit, T)

    return Plant(;
        name = "$(p1.name)+$(p2.name)",
        latitude = (p1.latitude + p2.latitude) / 2,
        longitude = (p1.longitude + p2.longitude) / 2,
        input_mix = p1.input_mix,
        output = p1.output,
        emissions = emissions,
        storage_cost = storage_cost,
        storage_limit = storage_limit,
        disposal_cost = disposal_cost,
        disposal_limit = disposal_limit,
        capacities = [cap_min, cap_max],
        initial_capacity = p1.initial_capacity + p2.initial_capacity,
    )
end

function _avg(a::Vector{Float64}, b::Vector{Float64})::Vector{Float64}
    return [(a[i] + b[i]) / 2 for i in eachindex(a)]
end

function _sum(a::Vector{Float64}, b::Vector{Float64})::Vector{Float64}
    return [a[i] + b[i] for i in eachindex(a)]
end

"""
Sum two OrderedDict{Product, Vector{Float64}} entry-wise, taking the union
of keys. Missing entries are treated as Inf vectors (unlimited).
Preserves Inf + Inf = Inf.
"""
function _sum_product_dicts(
    d1::OrderedDict{Product,Vector{Float64}},
    d2::OrderedDict{Product,Vector{Float64}},
    T::Int,
)::OrderedDict{Product,Vector{Float64}}
    result = OrderedDict{Product,Vector{Float64}}()
    all_keys = union(keys(d1), keys(d2))
    inf_vec = fill(Inf, T)
    for product in all_keys
        v1 = get(d1, product, inf_vec)
        v2 = get(d2, product, inf_vec)
        result[product] = [_sum_with_inf(v1[i], v2[i]) for i in eachindex(v1)]
    end
    return result
end

function _sum_with_inf(a::Float64, b::Float64)::Float64
    (isinf(a) || isinf(b)) ? Inf : a + b
end

"""
Average two OrderedDict{Product, Vector{Float64}} entry-wise, taking the
union of keys. Missing entries are treated as zero vectors.
"""
function _avg_product_dicts(
    d1::OrderedDict{Product,Vector{Float64}},
    d2::OrderedDict{Product,Vector{Float64}},
    T::Int,
)::OrderedDict{Product,Vector{Float64}}
    result = OrderedDict{Product,Vector{Float64}}()
    all_keys = union(keys(d1), keys(d2))
    zero_vec = zeros(Float64, T)
    for product in all_keys
        v1 = get(d1, product, zero_vec)
        v2 = get(d2, product, zero_vec)
        result[product] = _avg(v1, v2)
    end
    return result
end

"""
Average two OrderedDict{String, Vector{Float64}} entry-wise, taking the
union of keys. Missing entries are treated as zero vectors.
"""
function _avg_string_dicts(
    d1::OrderedDict{String,Vector{Float64}},
    d2::OrderedDict{String,Vector{Float64}},
    T::Int,
)::OrderedDict{String,Vector{Float64}}
    result = OrderedDict{String,Vector{Float64}}()
    all_keys = union(keys(d1), keys(d2))
    zero_vec = zeros(Float64, T)
    for k in all_keys
        v1 = get(d1, k, zero_vec)
        v2 = get(d2, k, zero_vec)
        result[k] = _avg(v1, v2)
    end
    return result
end

# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using JuMP

R_expand(p::Plant, t::Int) =
    (p.capacities[2].opening_cost[t] - p.capacities[1].opening_cost[t]) /
    (p.capacities[2].size - p.capacities[1].size)

R_fix_exp(p::Plant, t::Int) =
    (p.capacities[2].fix_operating_cost[t] - p.capacities[1].fix_operating_cost[t]) /
    (p.capacities[2].size - p.capacities[1].size)

function build_model(instance::Instance; optimizer, variable_names::Bool = false)
    model = JuMP.Model(optimizer)
    centers = instance.centers
    products = instance.products
    plants = instance.plants
    T = 1:instance.time_horizon
    model.ext[:instance] = instance

    # Constants
    # -------------------------------------------------------------------------
    K_cap_min = Dict(p => p.capacities[1].size for p in plants)
    K_cap_max = Dict(p => p.capacities[2].size for p in plants)
    R_open = Dict((p, t) => p.capacities[1].opening_cost[t] for p in plants for t in T)
    R_fix_min =
        Dict((p, t) => p.capacities[1].fix_operating_cost[t] for p in plants for t in T)


    # Transportation edges
    # -------------------------------------------------------------------------

    # Connectivity
    model.ext[:E] = E = []
    model.ext[:E_in] = E_in = Dict(src => [] for src in plants ∪ centers)
    model.ext[:E_out] = E_out = Dict(src => [] for src in plants ∪ centers)

    function push_edge!(src, dst, m)
        push!(E, (src, dst, m))
        push!(E_out[src], (dst, m))
        push!(E_in[dst], (src, m))
    end

    for m in products
        for p1 in plants
            m ∈ keys(p1.output) || continue

            # Plant to plant
            for p2 in plants
                p1 != p2 || continue
                m ∈ keys(p2.input_mix) || continue
                push_edge!(p1, p2, m)
            end

            # Plant to center
            for c in centers
                m == c.input || continue
                push_edge!(p1, c, m)
            end
        end

        for c1 in centers
            m ∈ c1.outputs || continue

            # Center to plant
            for p in plants
                m ∈ keys(p.input_mix) || continue
                push_edge!(c1, p, m)
            end

            # Center to center
            for c2 in centers
                m == c2.input || continue
                push_edge!(c1, c2, m)
            end
        end
    end

    # Distances
    model.ext[:distances] = distances = Dict()
    for (p1, p2, m) in E
        d = _calculate_distance(
            p1.latitude,
            p1.longitude,
            p2.latitude,
            p2.longitude,
            instance.distance_metric,
        )
        distances[p1, p2, m] = d
    end

    # Decision variables
    # -------------------------------------------------------------------------

    # Plant p is operational at time t
    x = _init(model, :x)
    for p in plants
        x[p.name, 0] = p.initial_capacity > 0 ? 1 : 0
    end
    for p in plants, t in T
        x[p.name, t] = @variable(model, binary = true)
    end

    # Amount of product m sent from center/plant u to center/plant v at time T
    y = _init(model, :y)
    for (p1, p2, m) in E, t in T
        y[p1.name, p2.name, m.name, t] = @variable(model, lower_bound = 0)
    end

    # Amount of product m produced by plant/center at time T
    z_prod = _init(model, :z_prod)
    for p in plants, m in keys(p.output), t in T
        z_prod[p.name, m.name, t] = @variable(model, lower_bound = 0)
    end

    # Amount of product m disposed at plant/center p at time T
    z_disp = _init(model, :z_disp)
    for p in plants, m in keys(p.output), t in T
        z_disp[p.name, m.name, t] = @variable(model, lower_bound = 0)
    end
    for c in centers, m in c.outputs, t in T
        z_disp[c.name, m.name, t] = @variable(model, lower_bound = 0)
    end

    # Total plant/center input
    z_input = _init(model, :z_input)
    for p in plants, t in T
        z_input[p.name, t] = @variable(model, lower_bound = 0)
    end
    for c in centers, t in T
        z_input[c.name, t] = @variable(model, lower_bound = 0)
    end

    # Plant expansion
    z_exp = _init(model, :z_exp)
    for p in plants
        z_exp[p.name, 0] = max(0, p.initial_capacity - K_cap_min[p])
    end
    for p in plants, t in T
        z_exp[p.name, t] = @variable(model, lower_bound = 0)
    end

    # Total amount collected by the center
    z_collected = _init(model, :z_collected)
    for c in centers, m in c.outputs, t in T
        z_collected[c.name, m.name, t] = @variable(model, lower_bound = 0)
    end

    # Amount of input material stored at plant at end of time period
    z_storage = _init(model, :z_storage)
    for p in plants
        for m in keys(p.input_mix)
            z_storage[p.name, m.name, 0] = 0  # Initial storage is zero
        end
    end
    for p in plants, m in keys(p.input_mix), t in T
        z_storage[p.name, m.name, t] = @variable(model, lower_bound = 0)
    end

    # Total amount of input material processed by plant
    z_process = _init(model, :z_process)
    for p in plants, t in T
        z_process[p.name, t] = @variable(model, lower_bound = 0)
    end

    # Transportation emissions by greenhouse gas
    z_em_tr = _init(model, :z_em_tr)
    for (p1, p2, m) in E, t in T, g in keys(m.tr_emissions)
        z_em_tr[g, p1.name, p2.name, m.name, t] = @variable(model, lower_bound = 0)
    end

    # Plant emissions by greenhouse gas
    z_em_plant = _init(model, :z_em_plant)
    for p in plants, t in T, g in keys(p.emissions)
        z_em_plant[g, p.name, t] = @variable(model, lower_bound = 0)
    end


    # Objective function
    # -------------------------------------------------------------------------
    obj = AffExpr()

    # Transportation cost
    for (p1, p2, m) in E, t in T
        add_to_expression!(
            obj,
            distances[p1, p2, m] * m.tr_cost[t],
            y[p1.name, p2.name, m.name, t],
        )
    end

    # Center: Revenue
    for c in centers, (p, m) in E_in[c], t in T
        add_to_expression!(obj, -c.revenue[t], y[p.name, c.name, m.name, t])
    end

    # Center: Collection cost
    for c in centers, (p, m) in E_out[c], t in T
        add_to_expression!(obj, c.collection_cost[m][t], y[c.name, p.name, m.name, t])
    end

    # Center: Disposal cost
    for c in centers, m in c.outputs, t in T
        add_to_expression!(obj, c.disposal_cost[m][t], z_disp[c.name, m.name, t])
    end

    # Center: Operating cost
    for c in centers, t in T
        add_to_expression!(obj, c.operating_cost[t])
    end

    # Plants: Disposal cost
    for p in plants, m in keys(p.output), t in T
        add_to_expression!(obj, p.disposal_cost[m][t], z_disp[p.name, m.name, t])
    end

    # Plants: Opening cost
    for p in plants, t in T
        add_to_expression!(obj, R_open[p, t], (x[p.name, t] - x[p.name, t-1]))
    end

    # Plants: Fixed operating cost
    for p in plants, t in T
        add_to_expression!(obj, R_fix_min[p, t], x[p.name, t])
        add_to_expression!(obj, R_fix_exp(p, t), z_exp[p.name, t])
    end

    # Plants: Expansion cost
    for p in plants, t in T
        add_to_expression!(obj, R_expand(p, t), z_exp[p.name, t] - z_exp[p.name, t-1])
    end

    # Plants: Variable operating cost
    for p in plants, (src, m) in E_in[p], t in T
        add_to_expression!(
            obj,
            p.capacities[1].var_operating_cost[t],
            y[src.name, p.name, m.name, t],
        )
    end

    # Plants: Storage cost
    for p in plants, m in keys(p.storage_cost), t in T
        add_to_expression!(obj, p.storage_cost[m][t], z_storage[p.name, m.name, t])
    end

    # Emissions penalty cost
    for emission in instance.emissions, t in T
        # Plant emissions penalty
        for p in plants
            if emission.name in keys(p.emissions)
                add_to_expression!(
                    obj,
                    emission.penalty[t],
                    z_em_plant[emission.name, p.name, t],
                )
            end
        end
        # Transportation emissions penalty
        for (p1, p2, m) in E
            if emission.name in keys(m.tr_emissions)
                add_to_expression!(
                    obj,
                    emission.penalty[t],
                    z_em_tr[emission.name, p1.name, p2.name, m.name, t],
                )
            end
        end
    end

    @objective(model, Min, obj)

    # Constraints
    # -------------------------------------------------------------------------

    # Plants: Definition of total plant input
    eq_z_input = _init(model, :eq_z_input)
    for p in plants, t in T
        eq_z_input[p.name, t] = @constraint(
            model,
            z_input[p.name, t] ==
            sum(y[src.name, p.name, m.name, t] for (src, m) in E_in[p])
        )
    end

    # Plants: Definition of total processing amount
    eq_z_process = _init(model, :eq_z_process)
    for p in plants, t in T
        eq_z_process[p.name, t] = @constraint(
            model,
            z_process[p.name, t] == z_input[p.name, t] +
            sum(
                z_storage[p.name, m.name, t-1] - z_storage[p.name, m.name, t]
                for m in keys(p.input_mix)
            )
        )
    end

    # Plants: Processing mix must have correct proportion
    eq_process_mix = _init(model, :eq_process_mix)
    for p in plants, m in keys(p.input_mix), t in T
        eq_process_mix[p.name, m.name, t] = @constraint(
            model,
            sum(y[src.name, p.name, m.name, t] for (src, m2) in E_in[p] if m == m2) +
            z_storage[p.name, m.name, t-1] - z_storage[p.name, m.name, t] ==
            z_process[p.name, t] * p.input_mix[m][t]
        )
    end

    # Plants: Calculate amount produced
    eq_z_prod = _init(model, :eq_z_prod)
    for p in plants, m in keys(p.output), t in T
        eq_z_prod[p.name, m.name, t] = @constraint(
            model,
            z_prod[p.name, m.name, t] == z_process[p.name, t] * p.output[m][t]
        )
    end

    # Plants: Produced material must be sent or disposed
    eq_balance = _init(model, :eq_balance)
    for p in plants, m in keys(p.output), t in T
        eq_balance[p.name, m.name, t] = @constraint(
            model,
            z_prod[p.name, m.name, t] ==
            sum(y[p.name, dst.name, m.name, t] for (dst, m2) in E_out[p] if m == m2) +
            z_disp[p.name, m.name, t]
        )
    end

    # Plants: Expansion upper bound
    eq_exp_ub = _init(model, :eq_exp_ub)
    for p in plants, t in T
        eq_exp_ub[p.name, t] = @constraint(
            model,
            z_exp[p.name, t] <= (K_cap_max[p] - K_cap_min[p]) * x[p.name, t]
        )
    end

    # Plants: Processing limit
    eq_process_limit = _init(model, :eq_process_limit)
    for p in plants, t in T
        eq_process_limit[p.name, t] = @constraint(
            model,
            z_process[p.name, t] <= K_cap_min[p] * x[p.name, t] + z_exp[p.name, t]
        )
    end

    # Plants: Disposal limit
    eq_disposal_limit = _init(model, :eq_disposal_limit)
    for p in plants, m in keys(p.output), t in T
        isfinite(p.disposal_limit[m][t]) || continue
        eq_disposal_limit[p.name, m.name, t] =
            @constraint(model, z_disp[p.name, m.name, t] <= p.disposal_limit[m][t])
    end

    # Plants: Plant remains open
    eq_keep_open = _init(model, :eq_keep_open)
    for p in plants, t in T
        eq_keep_open[p.name, t] = @constraint(model, x[p.name, t] >= x[p.name, t-1])
    end

    # Plants: Building period
    eq_building_period = _init(model, :eq_building_period)
    for p in plants, t in T
        if t ∉ instance.building_period
            eq_building_period[p.name, t] =
                @constraint(model, x[p.name, t] - x[p.name, t-1] <= 0)
        end
    end

    # Centers: Definition of total center input
    eq_z_input = _init(model, :eq_z_input)
    for c in centers, t in T
        eq_z_input[c.name, t] = @constraint(
            model,
            z_input[c.name, t] ==
            sum(y[src.name, c.name, m.name, t] for (src, m) in E_in[c])
        )
    end

    # Centers: Calculate amount collected
    eq_z_collected = _init(model, :eq_z_collected)
    for c in centers, m in c.outputs, t in T
        M = length(c.var_output[m])
        eq_z_collected[c.name, m.name, t] = @constraint(
            model,
            z_collected[c.name, m.name, t] ==
            sum(
                z_input[c.name, t-offset] * c.var_output[m][offset+1] for
                offset = 0:min(M - 1, t - 1)
            ) + c.fixed_output[m][t]
        )
    end

    # Centers: Collected products must be disposed or sent
    eq_balance = _init(model, :eq_balance)
    for c in centers, m in c.outputs, t in T
        eq_balance[c.name, m.name, t] = @constraint(
            model,
            z_collected[c.name, m.name, t] ==
            sum(y[c.name, dst.name, m.name, t] for (dst, m2) in E_out[c] if m == m2) +
            z_disp[c.name, m.name, t]
        )
    end

    # Centers: Disposal limit
    eq_disposal_limit = _init(model, :eq_disposal_limit)
    for c in centers, m in c.outputs, t in T
        isfinite(c.disposal_limit[m][t]) || continue
        eq_disposal_limit[c.name, m.name, t] =
            @constraint(model, z_disp[c.name, m.name, t] <= c.disposal_limit[m][t])
    end

    # Global disposal limit
    eq_disposal_limit = _init(model, :eq_disposal_limit)
    for m in products, t in T
        isfinite(m.disposal_limit[t]) || continue
        eq_disposal_limit[m.name, t] = @constraint(
            model,
            sum(z_disp[p.name, m.name, t] for p in plants if m in keys(p.output)) +
            sum(z_disp[c.name, m.name, t] for c in centers if m in c.outputs) <=
            m.disposal_limit[t]
        )
    end

    # Transportation emissions
    eq_emission_tr = _init(model, :eq_emission_tr)
    for (p1, p2, m) in E, t in T, g in keys(m.tr_emissions)
        eq_emission_tr[g, p1.name, p2.name, m.name, t] = @constraint(
            model,
            z_em_tr[g, p1.name, p2.name, m.name, t] ==
            distances[p1, p2, m] * m.tr_emissions[g][t] * y[p1.name, p2.name, m.name, t]
        )
    end

    # Plant emissions
    eq_emission_plant = _init(model, :eq_emission_plant)
    for p in plants, t in T, g in keys(p.emissions)
        eq_emission_plant[g, p.name, t] = @constraint(
            model,
            z_em_plant[g, p.name, t] == p.emissions[g][t] * z_process[p.name, t]
        )
    end

    # Storage limit at plants
    eq_storage_limit = _init(model, :eq_storage_limit)
    for p in plants, m in keys(p.storage_limit), t in T
        if isfinite(p.storage_limit[m][t])
            eq_storage_limit[p.name, m.name, t] = @constraint(
                model,
                z_storage[p.name, m.name, t] <= p.storage_limit[m][t]
            )
        end
    end

    # All stored materials must be processed by end of time horizon
    eq_storage_final = _init(model, :eq_storage_final)
    for p in plants, m in keys(p.input_mix)
        eq_storage_final[p.name, m.name] = @constraint(
            model,
            z_storage[p.name, m.name, instance.time_horizon] == 0
        )
    end

    # Global emissions limit
    eq_emission_limit = _init(model, :eq_emission_limit)
    for emission in instance.emissions, t in T
        isfinite(emission.limit[t]) || continue
        eq_emission_limit[emission.name, t] = @constraint(
            model,
            sum(
                z_em_plant[emission.name, p.name, t] for
                p in plants if emission.name in keys(p.emissions)
            ) + sum(
                z_em_tr[emission.name, p1.name, p2.name, m.name, t] for
                (p1, p2, m) in E if emission.name in keys(m.tr_emissions)
            ) <= emission.limit[t]
        )
    end

    if variable_names
        _set_names!(model)
    end
    return model
end

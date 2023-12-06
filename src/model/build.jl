using JuMP

function build_model(instance::Instance; optimizer, variable_names::Bool = false)
    model = JuMP.Model(optimizer)
    centers = instance.centers
    products = instance.products
    plants = instance.plants
    T = 1:instance.time_horizon

    # Transportation edges
    # -------------------------------------------------------------------------

    # Connectivity
    E = []
    E_in = Dict(src => [] for src in plants ∪ centers)
    E_out = Dict(src => [] for src in plants ∪ centers)

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
                m ∉ keys(p2.input_mix) || continue
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
    distances = Dict()
    for (p1, p2, m) in E
        d = _calculate_distance(p1.latitude, p1.longitude, p2.latitude, p2.longitude)
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
    for c in centers, m in c.outputs, t in T
        z_prod[c.name, m.name, t] = @variable(model, lower_bound = 0)
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

    # Total amount collected by the center
    z_collected = _init(model, :z_collected)
    for c in centers, m in c.outputs, t in T
        z_collected[c.name, m.name, t] = @variable(model, lower_bound = 0)
    end


    # Objective function
    # -------------------------------------------------------------------------
    obj = AffExpr()

    # Transportation cost
    for (p1, p2, m) in E, t in T
        add_to_expression!(obj, distances[p1, p2, m], y[p1.name, p2.name, m.name, t])
    end

    # Center: Revenue
    for c in centers, (p, m) in E_in[c], t in T
        add_to_expression!(obj, c.revenue[t], y[p.name, c.name, m.name, t])
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
        add_to_expression!(
            obj,
            p.capacities[1].opening_cost[t],
            (x[p.name, t] - x[p.name, t-1]),
        )
    end

    # Plants: Fixed operating cost
    for p in plants, t in T
        add_to_expression!(obj, p.capacities[1].fix_operating_cost[t], x[p.name, t])
    end

    # Plants: Variable operating cost
    for p in plants, (src, m) in E_in[p], t in T
        add_to_expression!(
            obj,
            p.capacities[1].var_operating_cost[t],
            y[src.name, p.name, m.name, t],
        )
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

    # Plants: Must meet input mix
    eq_input_mix = _init(model, :eq_input_mix)
    for p in plants, m in keys(p.input_mix), t in T
        eq_input_mix[p.name, m.name, t] = @constraint(
            model,
            sum(y[src.name, p.name, m.name, t] for (src, m2) in E_in[p] if m == m2) ==
            z_input[p.name, t] * p.input_mix[m][t]
        )
    end

    # Plants: Calculate amount produced
    eq_z_prod = _init(model, :eq_z_prod)
    for p in plants, m in keys(p.output), t in T
        eq_z_prod[p.name, m.name, t] = @constraint(
            model,
            z_prod[p.name, m.name, t] == z_input[p.name, t] * p.output[m][t]
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

    # Plants: Capacity limit
    eq_capacity = _init(model, :eq_capacity)
    for p in plants, t in T
        eq_capacity[p.name, t] =
            @constraint(model, z_input[p.name, t] <= p.capacities[1].size * x[p.name, t])
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
            eq_building_period[p.name, t] = @constraint(model, x[p.name, t] == 0)
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

    if variable_names
        _set_names!(model)
    end
    return model
end

using JuMP

function build_model(instance::Instance; optimizer, variable_names::Bool = false)
    model = JuMP.Model(optimizer)
    centers = instance.centers
    products = instance.products
    plants = instance.plants
    T = 1:instance.time_horizon

    # Transportation edges
    # -------------------------------------------------------------------------
    E = []
    for m in products
        for p1 in plants
            m ∉ keys(p1.output) || continue

            # Plant to plant
            for p2 in plants
                p1 != p2 || continue
                m ∉ keys(p2.input_mix) || continue
                push!(E, (p1, p2, m))
            end

            # Plant to center
            for c in centers
                m == c.input || continue
                push!(E, (p1, c, m))
            end
        end

        for c1 in centers
            m ∈ c1.outputs || continue

            # Center to plant
            for p in plants
                m ∈ keys(p.input_mix) || continue
                push!(E, (c1, p, m))
            end

            # Center to center
            for c2 in centers
                m == c2.input || continue
                push!(E, (c1, c2, m))
            end
        end
    end


    # Decision variables
    # -------------------------------------------------------------------------

    # Plant p is operational at time t
    x = _init(model, :x)
    for p in plants, t in T
        x[p.name, t] = @variable(model, binary = true)
    end

    # Amount of product m sent from center/plant u to center/plant v at time T
    y = _init(model, :y)
    for (p1, p2, m) in E, t in T
        y[p1.name, p2.name, m.name, t] = @variable(model, lower_bound=0)
    end

    # Amount of product m produced by plant/center at time T
    z_prod = _init(model, :z_prod)
    for p in plants, m in keys(p.output), t in T
        z_prod[p.name, m.name, t] = @variable(model, lower_bound=0)
    end
    for c in centers, m in c.outputs, t in T
        z_prod[c.name, m.name, t] = @variable(model, lower_bound=0)
    end

    # Amount of product m disposed at plant/center p at time T
    z_disp = _init(model, :z_disp)
    for p in plants, m in keys(p.output), t in T
        z_disp[p.name, m.name, t] = @variable(model, lower_bound=0)
    end
    for c in centers, m in c.outputs, t in T
        z_disp[c.name, m.name, t] = @variable(model, lower_bound=0)
    end
    

    # Objective function
    # -------------------------------------------------------------------------


    # Constraints
    # -------------------------------------------------------------------------


    if variable_names
        _set_names!(model)
    end
    return model
end

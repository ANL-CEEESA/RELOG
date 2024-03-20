using JuMP
using OrderedCollections
using Gurobi
using Random
using Printf

dict = OrderedDict

macro pprint(var)
    quote
        println(string($(QuoteNode(var))))
        v = round.($(esc(var)), digits=2)
        display(v)
        println()
    end
end

macro pprint_jump(var)
    quote
        println(string($(QuoteNode(var))))
        v = round.(value.($(esc(var))), digits=2)
        display(v)
        println()
    end
end

function model1()
    Random.seed!(42)

    model = Model(
        optimizer_with_attributes(
            Gurobi.Optimizer,
            "NonConvex" => 2,
        ),
    )

    # Data
    # -------------------------------------------------------------------------
    n_plants = 5
    n_components = 2
    plants = 1:n_plants
    components = 1:n_components
    initial_amount = [rand(1:1000) for _ in plants, _ in components]
    revenue = [rand(1:1000) for _ in plants]
    tr_cost = [
        rand(1:50)
        for _ in plants, _ in plants
    ]

    @show plants
    @show components
    @show initial_amount
    @show revenue

    # Decision variables
    # -------------------------------------------------------------------------
    @variable(model, y_total[plants, plants], lower_bound = 0)
    @variable(model, y[plants, plants, components], lower_bound = 0)
    @variable(model, z_disp_total[plants], lower_bound = 0)
    @variable(model, z_disp[plants, components], lower_bound = 0)
    @variable(model, z_avail_total[plants])
    @variable(model, z_avail[plants, components])
    @variable(model, alpha[plants, components])

    # Objective
    # -------------------------------------------------------------------------
    @objective(
        model,
        Max,
        sum(
            z_disp_total[p] * revenue[p]
            for p in plants
        )
        -
        sum(
            y_total[p, q] * tr_cost[p, q]
            for p in plants, q in plants
        )
    )

    # Constraints
    # -------------------------------------------------------------------------

    # Definition of total sent
    @constraint(
        model,
        eq_y_total_def[p in plants, q in plants],
        y_total[p, q] == sum(y[p, q, c] for c in components)
    )

    # Definition of total disposed
    @constraint(
        model,
        eq_z_disp_total_def[p in plants], z_disp_total[p] == sum(z_disp[p, c] for c in components)
    )

    # Definition of available amount
    @constraint(
        model,
        eq_z_avail_total[p in plants],
        z_avail_total[p] == sum(z_avail[p, c] for c in components)
    )

    # Definition of available component
    @constraint(
        model,
        eq_z_avail[p in plants, c in components],
        z_avail[p, c] == initial_amount[p, c] + sum(y[q, p, c] for q in plants)
    )

    # Mass balance
    @constraint(
        model,
        eq_balance[p in plants],
        z_avail_total[p] == z_disp_total[p] + sum(y_total[p, q] for q in plants)
    )

    # Available proportion
    @constraint(
        model,
        eq_alpha_avail[p in plants, c in components],
        z_avail[p, c] == alpha[p, c] * z_avail_total[p]
    )

    # Sending proportion
    @constraint(
        model,
        eq_alpha_send[p in plants, q in plants, c in components],
        y[p, q, c] == alpha[p, c] * y_total[p, q]
    )

    # Disposal proportion
    @constraint(
        model,
        eq_alpha_disp[p in plants, c in components],
        z_disp[p, c] == alpha[p, c] * z_disp_total[p]
    )

    # Run
    # -------------------------------------------------------------------------
    print(model)
    optimize!(model)

    # Print solution
    # -------------------------------------------------------------------------
    @pprint initial_amount
    @pprint revenue
    @pprint tr_cost

    @pprint_jump y_total
    @pprint_jump y
    @pprint_jump z_disp_total
    @pprint_jump z_disp
    @pprint_jump z_avail_total
    @pprint_jump z_avail
    @pprint_jump alpha
end

model1()
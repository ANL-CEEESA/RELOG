using JuMP
using OrderedCollections
using Gurobi
using Random
using Printf
using DataFrames
using CSV

dict = OrderedDict

function model2()
    Random.seed!(42)

    model = Model(
        optimizer_with_attributes(
            Gurobi.Optimizer,
        ),
    )

    # Data
    # -------------------------------------------------------------------------
    components = ["film", "paper", "cardboard"]
    centers = [
        "Chicago",
        "New York City",
        "Los Angeles",
        "Houston",
        "Phoenix",
        "Philadelphia",
        "San Antonio",
        "San Diego",
        "Dallas",
        "San Jose",
    ]
    plants = [
        "Chicago",
        "Phoenix",
        "Dallas",
    ]
    products = [
        "film bale",
        "cardboard bale"
    ]
    initial_amount = dict(
        (q, c) => rand(1:1000)
        for q in centers, c in components
    )
    cost_tr = dict(
        (q, p) => rand(1:10)
        for q in centers, p in plants
    )
    cost_open = dict(
        p => rand(5000:10000)
        for p in plants
    )
    cost_var = dict(
        p => rand(5:10)
        for p in plants
    )
    revenue = dict(
        (p, m) => rand(10:20)
        for p in plants, m in products
    )
    alpha = dict(
        "film bale" => dict(
            "film" => dict(
                "film" => 0.98,
                "paper" => 0,
                "cardboard" => 0,
            ),
            "paper" => dict(
                "film" => 0,
                "paper" => 0.02,
                "cardboard" => 0,
            ),
            "cardboard" => dict(
                "film" => 0,
                "paper" => 0,
                "cardboard" => 0.02,
            ),
        ),
        "cardboard bale" => dict(
            "film" => dict(
                "film" => 0.0,
                "paper" => 0.0,
                "cardboard" => 0.0,
            ),
            "paper" => dict(
                "film" => 0.0,
                "paper" => 0.02,
                "cardboard" => 0.0,
            ),
            "cardboard" => dict(
                "film" => 0.0,
                "paper" => 0.0,
                "cardboard" => 0.75,
            ),
        ),
    )
    capacity = dict(
        p => rand(10000:50000)
        for p in plants
    )

    # Variables
    # -------------------------------------------------------------------------
    @variable(model, y[centers, plants, components] >= 0)
    @variable(model, y_total[centers, plants])
    @variable(model, x[plants], Bin)
    @variable(model, z_avail[plants, components])
    @variable(model, z_prod[plants, products, components])


    # Objective
    # -------------------------------------------------------------------------
    @objective(
        model,
        Min,

        # Transportation cost
        + sum(
            cost_tr[q, p] * y[q, p, c]
            for p in plants, q in centers, c in components
        )

        # Opening cost
        + sum(
            cost_open[p] * x[p]
            for p in plants
        )

        # Variable operating cost
        + sum(
            cost_var[p] * y[q,p,c]
            for q in centers, p in plants, c in components
        )

        # Revenue
        + sum(
            revenue[p,m] * z_prod[p,m,c]
            for p in plants, m in products, c in components
        )
    )


    # Constraints
    # -------------------------------------------------------------------------

    # Flow balance at centers:
    @constraint(
        model,
        eq_flow_balance[q in centers, c in components],
        sum(y[q,p,c] for p in plants) == initial_amount[q, c]
    )

    # Total flow:
    @constraint(
        model,
        eq_total_flow[q in centers, p in plants],
        y_total[q,p] == sum(y[q,p,c] for c in components)
    )

    # Center balance mix:
    @constraint(
        model,
        eq_mix[q in centers, p in plants, c in components],
        y[q,p,c] == initial_amount[q,c] / sum(initial_amount[q,d] for d in components) * y_total[q,p]
    )

    # Plant capacity
    @constraint(
        model,
        eq_capacity[p in plants],
        sum(y_total[q,p] for q in centers) <= capacity[p] * x[p]
    )

    # Amount available
    @constraint(
        model,
        eq_z_avail[p in plants, c in components],
        z_avail[p,c] == sum(y[q,p,c] for q in centers)
    )

    # Amount produced
    @constraint(
        model,
        eq_z_prod[p in plants, m in products, c in components],
        z_prod[p,m,c] == 
            sum(
                alpha[m][c][d] * 
                z_avail[p,c]
                for d in components
            )
    )


    # Run
    # -------------------------------------------------------------------------
    print(model)
    optimize!(model)

    # Report: Transportation
    # -------------------------------------------------------------------------
    df = DataFrame()
    df."center" = String[]
    df."plant" = String[]
    df."component" = String[]
    df."amount sent (tonne)" = Float64[]
    df."transportation cost (\$)" = Float64[]
    df."variable operating cost (\$)" = Float64[]
    for q in centers, p in plants, c in components
        if value(y[q, p, c]) ≈ 0
            continue
        end
        push!(
            df,
            [
                q,
                p,
                c,
                value(y[q, p, c]),
                cost_tr[q, p] * value(y[q, p, c]),
                cost_var[p] * value(y[q,p,c])
            ]
        )
    end
    CSV.write("output-2/tr.csv", df)


    # Report: Plant
    # -------------------------------------------------------------------------
    df = DataFrame()
    df."plant" = String[]
    df."is open?" = Float64[]
    df."capacity (tonne)" = Float64[]
    df."utilization (tonne)" = Float64[]
    df."opening cost (\$)" = Float64[]
    for p in plants
        if value(x[p]) ≈ 0
            continue
        end
        push!(
            df,
            [
                p,
                value(x[p]),
                capacity[p],
                sum(value(y_total[q,p]) for q in centers),
                cost_open[p] * value(x[p])
            ]
        )
    end
    CSV.write("output-2/plant.csv", df)

    # Report: Plant Outputs
    # -------------------------------------------------------------------------
    df = DataFrame()
    df."plant" = String[]
    df."product" = String[]
    df."component" = String[]
    df."amount produced (tonne)" = Float64[]
    df."revenue (\$)" = Float64[]
    for p in plants, m in products, c in components
        if value(z_prod[p, m, c]) ≈ 0
            continue
        end
        push!(
            df,
            [
                p,
                m,
                c,
                value(z_prod[p, m, c]),
                revenue[p,m] * value(z_prod[p,m,c])
            ]
        )
    end
    CSV.write("output-2/plant-outputs.csv", df)    

end

model2()

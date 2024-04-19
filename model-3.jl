# RELOG: Reverse Logistics Optimization
# Copyright (C) 2020-2024, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using CSV
using DataFrames
using JSON
using JuMP
using OrderedCollections
using Random
using TimerOutputs
using Printf

include("jumpext.jl")
include("dist.jl")

dict = OrderedDict
Time = Int
Random.seed!(42)

# Structs
# =========================================================================

Base.@kwdef struct Component
    name::String
end

Base.@kwdef struct Product
    name::String
    comp::Vector{Component}
end

Base.@kwdef struct Center
    name::String
    latitude::Float64
    longitude::Float64
    prod_out::Vector{Product}
end

Base.@kwdef struct Plant
    name::String
    latitude::Float64
    longitude::Float64
    prod_out::Vector{Product}
    prod_in::Product
end

Base.@kwdef struct Emission
    name::String
end

Base.show(io::IO, p::Union{Component,Product,Center,Plant,Emission}) = print(io, p.name)

Base.@kwdef mutable struct Instance
    T::UnitRange{Int}
    centers::Vector{Center}
    plants::Vector{Plant}
    products::Vector{Product}
    emissions::Vector{Emission}
    alpha_mix::dict{Tuple{Plant,Product,Component,Component},Float64}
    alpha_plant_emission::dict{Tuple{Plant,Emission,Time},Float64}
    alpha_tr_emission::dict{Tuple{Product,Emission,Time},Float64}
    c_acq::dict{Tuple{Center,Product,Time},Float64}
    c_center_disp::dict{Tuple{Center,Product,Time},Float64}
    c_emission::dict{Tuple{Emission,Time},Float64}
    c_fix::dict{Tuple{Plant,Time},Float64}
    c_open::dict{Tuple{Plant,Time},Float64}
    c_plant_disp::dict{Tuple{Plant,Product,Time},Float64}
    c_store::dict{Tuple{Center,Product,Time},Float64}
    c_tr::dict{Tuple{Product,Time},Float64}
    c_var::dict{Tuple{Plant,Time},Float64}
    m_cap::dict{Plant,Float64}
    m_center_disp::dict{Tuple{Product,Time},Float64}
    m_dist::dict{Tuple{Union{Center,Plant},Plant},Float64}
    m_emission::dict{Tuple{Emission,Time},Float64}
    m_init::dict{Tuple{Center,Product,Component,Time},Float64}
    m_plant_disp::dict{Tuple{Plant,Product,Time},Float64}
    m_store::dict{Tuple{Center,Product,Time},Float64}
end


# Generate
# ==============================================================================

function generate_data()
    # Time window
    T = 1:2

    # Cities
    cities_a = dict(
        "Chicago" => [41.881832, -87.623177],
        "New York City" => [40.712776, -74.005974],
        "Los Angeles" => [34.052235, -118.243683],
        "Houston" => [29.760427, -95.369804],
        "Phoenix" => [33.448376, -112.074036],
        "Philadelphia" => [39.952583, -75.165222],
        "San Antonio" => [29.424122, -98.493629],
        "San Diego" => [32.715736, -117.161087],
        "Dallas" => [32.776664, -96.796988],
        "San Jose" => [37.338208, -121.886329],
    )

    cities_b = dict(
        "Chicago" => [41.881832, -87.623177],
        "Phoenix" => [33.448376, -112.074036],
        "Dallas" => [32.776664, -96.796988],
    )

    # Components
    film = Component("Film")
    paper = Component("Paper")
    cardboard = Component("Cardboard")

    # Products
    waste = Product(name = "Waste", comp = [film, paper, cardboard])
    film_bale = Product(name = "Film bale", comp = [film, paper, cardboard])
    cardboard_bale = Product(name = "Cardboard bale", comp = [paper, cardboard])
    cardboard_sheets = Product(name = "Cardboard sheets", comp = [cardboard])
    products = [waste, film_bale, cardboard_bale, cardboard_sheets]

    # Centers
    centers = [
        Center(
            name = "Collection ($city_name)",
            latitude = city_lat,
            longitude = city_lon,
            prod_out = [waste],
        ) for (city_name, (city_lat, city_lon)) in cities_a
    ]

    # Plants
    plants_a = [
        Plant(
            name = "MRF ($city_name)",
            latitude = city_lat,
            longitude = city_lon,
            prod_in = waste,
            prod_out = [film_bale, cardboard_bale],
        ) for (city_name, (city_lat, city_lon)) in cities_b
    ]
    plants_b = [
        Plant(
            name = "Paper Mill ($city_name)",
            latitude = city_lat,
            longitude = city_lon,
            prod_in = cardboard_bale,
            prod_out = [cardboard_sheets],
        ) for (city_name, (city_lat, city_lon)) in cities_b
    ]
    plants = [plants_a; plants_b]

    # Emissions
    emissions = [Emission("CO2")]

    alpha_mix = dict(
        (p, r, cin, cout) => 0.0 for p in plants for cin in p.prod_in.comp for
        r in p.prod_out for cout in r.comp
    )
    for p in plants_a
        alpha_mix[p, film_bale, film, film] = 0.98
        alpha_mix[p, film_bale, paper, paper] = 0.02
        alpha_mix[p, film_bale, cardboard, cardboard] = 0.02
        alpha_mix[p, cardboard_bale, paper, paper] = 0.02
        alpha_mix[p, cardboard_bale, cardboard, cardboard] = 0.75
    end
    for p in plants_b
        alpha_mix[p, cardboard_sheets, cardboard, cardboard] = 0.95
    end
    alpha_plant_emission = dict((p, s, t) => 0.01 for p in plants, s in emissions, t in T)
    alpha_tr_emission = dict((r, s, t) => 0.01 for r in products, s in emissions, t in T)
    c_acq = dict((q, r, t) => 1.0 for q in centers for r in q.prod_out, t in T)
    c_center_disp = dict((q, r, t) => 0 for q in centers for r in q.prod_out for t in T)
    c_emission = dict((s, t) => 0.01 for s in emissions, t in T)
    c_fix = dict((p, t) => 1_000.0 for p in plants, t in T)
    c_open = dict((p, t) => 10_000.0 for p in plants, t in T)
    c_plant_disp = dict(
        (p, r, t) => (r == cardboard_sheets ? -100.0 : -10.0) for p in plants for
        r in p.prod_out, t in T
    )
    c_store = dict((q, r, t) => 1.0 for q in centers for r in q.prod_out, t in T)
    c_tr = dict((r, t) => 0.05 for r in products, t in T)
    c_var = dict((p, t) => 1.0 for p in plants, t in T)
    m_cap = dict(p => 50000.0 for p in plants)
    m_center_disp = dict((r, t) => 0.0 for r in products, t in T)
    metric = KnnDrivingDistance()
    m_dist = dict(
        (p, q) => _calculate_distance(
            p.latitude,
            p.longitude,
            q.latitude,
            q.longitude,
            metric,
        ) for p in [plants; centers], q in plants
    )
    m_emission = dict((s, t) => 1_000_000 for s in emissions, t in T)
    m_init = dict()
    for q in centers, r in q.prod_out
        ratio = dict(c => rand(1:10) for c in r.comp)
        total = dict(t => rand(1:1000) for t in T)
        for c in r.comp, t in T
            m_init[q, r, c, t] = ratio[c] * total[t]
        end
    end
    m_plant_disp =
        dict((p, r, t) => 1_000_000 for p in plants for r in p.prod_out for t in T)
    m_store = dict((q, r, t) => 1_000 for q in centers for r in q.prod_out, t in T)

    return Instance(;
        T,
        centers,
        plants,
        products,
        emissions,
        alpha_mix,
        alpha_plant_emission,
        alpha_tr_emission,
        c_acq,
        c_center_disp,
        c_emission,
        c_fix,
        c_open,
        c_plant_disp,
        c_store,
        c_tr,
        c_var,
        m_cap,
        m_center_disp,
        m_dist,
        m_emission,
        m_init,
        m_plant_disp,
        m_store,
    )
end

# Write
# ==============================================================================

function write_json(data, filename)
    json = dict()
    json["parameters"] = dict("time horizon (years)" => data.T.stop)
    json["products"] = dict(
        r.name => dict(
            "components" => [c.name for c in r.comp],
            "disposal limit (tonne)" => [data.m_center_disp[r, t] for t in data.T],
            "transportation cost (\$/km/tonne)" => [data.c_tr[r, t] for t in data.T],
            "transportation emissions (tonne/km/tonne)" => dict(
                s => [data.alpha_tr_emission[r, s, t] for t in data.T] for
                s in data.emissions
            ),
        ) for r in data.products
    )
    json["centers"] = dict(
        q.name => dict(
            "latitude" => q.latitude,
            "longitude" => q.longitude,
            "output" => dict(
                r.name => dict(
                    "initial amount (tonne)" => [
                        data.m_init[q, r, c, t] for c in r.comp, t in data.T
                    ],
                    "disposal cost (\$/tonne)" =>
                        [data.c_center_disp[q, r, t] for t in data.T],
                    "storage cost (\$/tonne)" =>
                        [data.c_store[q, r, t] for t in data.T],
                    "storage limit (tonne)" => [data.m_store[q, r, t] for t in data.T],
                    "acquisition cost (\$/tonne)" =>
                        [data.c_acq[q, r, t] for t in data.T],
                ) for r in q.prod_out
            ),
        ) for q in data.centers
    )
    json["plants"] = dict(
        p.name => dict(
            "latitude" => p.latitude,
            "longitude" => p.longitude,
            "input" => p.prod_in.name,
            "output" => dict(
                r.name => dict(
                    "output matrix" => [
                        data.alpha_mix[p, r, c_in, c_out] for
                        c_in in p.prod_in.comp, c_out in r.comp
                    ],
                    "disposal limit (tonne)" =>
                        [data.m_plant_disp[p, r, t] for t in data.T],
                    "disposal cost (\$/tonne)" =>
                        [data.c_plant_disp[p, r, t] for t in data.T],
                ) for r in p.prod_out
            ),
            "fixed operating cost (\$)" => [data.c_fix[p, t] for t in data.T],
            "variable operating cost (\$/tonne)" => [data.c_var[p, t] for t in data.T],
            "opening cost (\$)" => [data.c_open[p, t] for t in data.T],
            "capacity (tonne)" => data.m_cap[p],
            "emissions (tonne/tonne)" => dict(
                s => [data.alpha_plant_emission[p, s, t] for t in data.T] for
                s in data.emissions
            ),
        ) for p in data.plants
    )
    json["emissions"] = dict(
        s.name => dict(
            "penalty (\$/tonne)" => [data.c_emission[s, t] for t in data.T],
            "limit (tonne)" => [data.m_emission[s, t] for t in data.T],
        ) for s in data.emissions
    )
    open(filename, "w") do io
        JSON.print(io, json, 2)
    end
end

# Read
# ==============================================================================
function read_json(filename, max_centers = 10, max_plants = 10)
    json = JSON.parsefile(filename)
    T = 1:json["parameters"]["time horizon (years)"]
    centers = []
    components_by_name = dict()
    emissions = []
    emissions_by_name = dict()
    plants = []
    products = []
    products_by_name = dict()
    alpha_mix = dict()
    alpha_plant_emission = dict()
    alpha_tr_emission = dict()
    c_acq = dict()
    c_center_disp = dict()
    c_emission = dict()
    c_fix = dict()
    c_open = dict()
    c_plant_disp = dict()
    c_store = dict()
    c_tr = dict()
    c_var = dict()
    m_cap = dict()
    m_center_disp = dict()
    m_emission = dict()
    m_init = dict()
    m_plant_disp = dict()
    m_store = dict()

    @timeit "Read: Emissions" begin
        for (emission_name, emission_data) in json["emissions"]
            s = Emission(emission_name)
            emissions_by_name[emission_name] = s
            push!(emissions, s)
            for t in T
                c_emission[s, t] = emission_data["penalty (\$/tonne)"][t]
                m_emission[s, t] = emission_data["limit (tonne)"][t]
            end
        end
    end

    @timeit "Read: Products" begin
        for (name, prod_data) in json["products"]
            comp = []
            for (comp_name) in prod_data["components"]
                if comp_name ∉ keys(components_by_name)
                    components_by_name[comp_name] = Component(comp_name)
                end
                push!(comp, components_by_name[comp_name])
            end
            r = Product(name, comp)
            products_by_name[name] = r
            push!(products, r)
            for t in T
                m_center_disp[r, t] = prod_data["disposal limit (tonne)"][t]
                c_tr[r, t] = prod_data["transportation cost (\$/km/tonne)"][t]
            end
            for (s_name, s_data) in prod_data["transportation emissions (tonne/km/tonne)"]
                s = emissions_by_name[s_name]
                for t in T
                    alpha_tr_emission[r, s, t] = s_data[t]
                end
            end
        end
    end

    @timeit "Read: Centers" begin
        for (name, center_data) in json["centers"]
            if length(centers) >= max_centers
                @warn "Maximum number of centers reached. Skipping remaining ones."
                break
            end
            latitude = center_data["latitude"]
            longitude = center_data["longitude"]
            prod_out = [products_by_name[r] for r in keys(center_data["output"])]
            q = Center(; name, latitude, longitude, prod_out)
            push!(centers, q)
            for r in prod_out, t in T
                c_acq[q, r, t] =
                    center_data["output"][r.name]["acquisition cost (\$/tonne)"][t]
                c_center_disp[q, r, t] =
                    center_data["output"][r.name]["disposal cost (\$/tonne)"][t]
                c_store[q, r, t] =
                    center_data["output"][r.name]["storage cost (\$/tonne)"][t]
                m_store[q, r, t] = center_data["output"][r.name]["storage limit (tonne)"][t]
                for (c_idx, c) in enumerate(r.comp)
                    m_init[q, r, c, t] =
                        center_data["output"][r.name]["initial amount (tonne)"][t][c_idx]
                end
            end
        end
    end

    @timeit "Read: Plants" begin
        for (plant_name, plant_data) in json["plants"]
            if length(plants) >= max_plants
                @warn "Maximum number of plants reached. Skipping remaining ones."
                break
            end
            latitude = plant_data["latitude"]
            longitude = plant_data["longitude"]
            prod_in = products_by_name[plant_data["input"]]
            prod_out = [products_by_name[r] for r in keys(plant_data["output"])]
            p = Plant(plant_name, latitude, longitude, prod_out, prod_in)
            push!(plants, p)
            m_cap[p] = plant_data["capacity (tonne)"]
            for t in T
                c_fix[p, t] = plant_data["fixed operating cost (\$)"][t]
                c_var[p, t] = plant_data["variable operating cost (\$/tonne)"][t]
                c_open[p, t] = plant_data["opening cost (\$)"][t]
            end
            for r in prod_out,
                (cin_idx, c_in) in enumerate(prod_in.comp),
                (cout_idx, c_out) in enumerate(r.comp)

                alpha_mix[p, r, c_in, c_out] =
                    plant_data["output"][r.name]["output matrix"][cout_idx][cin_idx]
            end
            for r in prod_out, t in T
                c_plant_disp[p, r, t] =
                    plant_data["output"][r.name]["disposal cost (\$/tonne)"][t]
                m_plant_disp[p, r, t] =
                    plant_data["output"][r.name]["disposal limit (tonne)"][t]
            end
            for (s_name, s_data) in plant_data["emissions (tonne/tonne)"]
                s = emissions_by_name[s_name]
                for t in T
                    alpha_plant_emission[p, s, t] = s_data[t]
                end
            end
        end
    end

    @timeit "Calculate distances" begin
        metric = KnnDrivingDistance()
        m_dist = dict(
            (p, q) => _calculate_distance(
                p.latitude,
                p.longitude,
                q.latitude,
                q.longitude,
                metric,
            ) for p in [plants; centers], q in plants
        )
    end

    return Instance(;
        T,
        centers,
        plants,
        products,
        emissions,
        alpha_mix,
        alpha_plant_emission,
        alpha_tr_emission,
        c_acq,
        c_center_disp,
        c_emission,
        c_fix,
        c_open,
        c_plant_disp,
        c_store,
        c_tr,
        c_var,
        m_cap,
        m_center_disp,
        m_dist,
        m_emission,
        m_init,
        m_plant_disp,
        m_store,
    )
end


# Run
# ==============================================================================

function generate_json()
    @info "Generating data"
    data = generate_data()

    @info "Writing JSON file"
    write_json(data, "output-3/case.json")
end

function solve(filename, optimizer)
    reset_timer!()

    @timeit "Read JSON" begin
        data = read_json(filename)
    end

    T = data.T
    centers = data.centers
    plants = data.plants
    products = data.products
    emissions = data.emissions

    model = Model(optimizer)

    # Graph
    # -------------------------------------------------------------------------
    @timeit "Build graph" begin
        E = []
        E_in = dict(src => [] for src in plants)
        E_out = dict(src => [] for src in plants ∪ centers)
        function push_edge!(src, dst, r)
            push!(E, (src, dst, r))
            push!(E_out[src], (dst, r))
            push!(E_in[dst], (src, r))
        end
        for r in products
            # Plant to plant
            for p1 in plants
                r ∈ p1.prod_out || continue
                for p2 in plants
                    p1 != p2 || continue
                    r == p2.prod_in || continue
                    push_edge!(p1, p2, r)
                end
            end
            # Center to plant
            for q in centers
                r ∈ q.prod_out || continue
                for p in plants
                    r == p.prod_in || continue
                    push_edge!(q, p, r)
                end
            end
        end
    end

    @printf("Building optimization problem with:\n")
    @printf("    %8d plants\n", length(plants))
    @printf("    %8d centers\n", length(centers))
    @printf("    %8d products\n", length(products))
    @printf("    %8d time periods\n", length(T))
    @printf("    %8d transportation edges\n", length(E))

    # Decision variables
    # -------------------------------------------------------------------------
    @timeit "Model: Add variables" begin
        @timeit "y" begin
            y = _init(model, :y)
            for (q, p, r) in E
                y[q, p, r] = @variable(model, [r.comp, T], lower_bound = 0)
            end
        end
        @timeit "y_total" begin
            y_total = _init(model, :y_total)
            for (q, p, r) in E
                y_total[q, p, r] = @variable(model, [T], lower_bound = 0)
            end
        end
        @timeit "z_center_disp" begin
            z_center_disp = _init(model, :z_center_disp)
            for q in centers, r in q.prod_out, c in r.comp, t in T
                z_center_disp[q, r, c, t] = @variable(model, lower_bound = 0)
            end
        end
        @timeit "z_center_disp_total" begin
            z_center_disp_total = _init(model, :z_center_disp_total)
            for q in centers, r in q.prod_out, t in T
                z_center_disp_total[q, r, t] = @variable(model, lower_bound = 0)
            end
        end
        @timeit "z_store" begin
            z_store = _init(model, :z_store)
            for q in centers, r in q.prod_out, c in r.comp, t in T
                if t == T.stop
                    z_store[q, r, c, t] = 0.0
                else
                    z_store[q, r, c, t] = @variable(model, lower_bound = 0)
                end
            end
        end
        @timeit "z_store_total" begin
            z_store_total = _init(model, :z_store_total)
            for q in centers, r in q.prod_out
                z_store_total[q, r, 0] = 0.0
                for t in T
                    if t == T.stop
                        z_store_total[q, r, t] = 0.0
                    else
                        z_store_total[q, r, t] = @variable(model, lower_bound = 0)
                    end
                end
            end
        end
        @timeit "x_open" begin
            x_open = _init(model, :x_open)
            for p in plants
                x_open[p, 0] = 0
                for t in T
                    x_open[p, t] = @variable(model, binary = true)
                end
            end
        end
        @timeit "x_send" begin
            x_send = _init(model, :x_send)
            for p in plants, (q, r) in E_out[p], t in T
                x_send[p, q, r, t] = @variable(model, binary = true)
            end
        end
        @timeit "x_disp" begin
            x_disp = _init(model, :x_disp)
            for p in plants, r in p.prod_out, t in T
                x_disp[p, r, t] = @variable(model, binary = true)
            end
        end
        @timeit "z_prod" begin
            z_prod = _init(model, :z_prod)
            for p in plants, r in p.prod_out, c in r.comp, t in T
                z_prod[p, r, c, t] = @variable(model, lower_bound = 0)
            end
        end
        @timeit "z_plant_disp" begin
            z_plant_disp = _init(model, :z_plant_disp)
            for p in plants, r in p.prod_out, c in r.comp, t in T
                z_plant_disp[p, r, c, t] = @variable(model, lower_bound = 0)
            end
        end
        @timeit "z_tr_emissions" begin
            z_tr_emissions = _init(model, :z_tr_emissions)
            for (q, p, r) in E, s in emissions, t in T
                z_tr_emissions[q, p, r, s, t] = @variable(model, lower_bound = 0)
            end
        end
        @timeit "z_plant_emissions" begin
            z_plant_emissions = _init(model, :z_plant_emissions)
            for p in plants, s in emissions, t in T
                z_plant_emissions[p, s, t] = @variable(model, lower_bound = 0)
            end
        end
    end


    # Objective function
    # -------------------------------------------------------------------------
    @timeit "Model: Objective function" begin
        obj = AffExpr()

        # Center disposal
        @timeit "c_center_disp" begin
            for q in centers, r in q.prod_out, t in T
                add_to_expression!(
                    obj,
                    data.c_center_disp[q, r, t],
                    z_center_disp_total[q, r, t],
                )
            end
        end

        # Center acquisition
        @timeit "c_acq" begin
            for q in centers, r in q.prod_out, c in r.comp, t in T
                add_to_expression!(obj, data.m_init[q, r, c, t] * data.c_acq[q, r, t])
            end
        end

        # Center storage
        @timeit "c_store" begin
            for q in centers, r in q.prod_out, t in T
                add_to_expression!(obj, data.c_store[q, r, t], z_store_total[q, r, t])
            end
        end

        # Transportation, variable operating cost
        @timeit "c_tr, c_var" begin
            for (q, p, r) in E
                dist = data.m_dist[q, p]
                y_qpr = y[q, p, r]
                for c in r.comp, t in T
                    add_to_expression!(obj, dist * data.c_tr[r, t], y_qpr[c, t])
                    add_to_expression!(obj, data.c_var[p, t], y_qpr[c, t])
                end
            end
        end

        # Transportation emissions
        @timeit "c_emission" begin
            for (q, p, r) in E, s in emissions, t in T
                add_to_expression!(
                    obj,
                    data.c_emission[s, t],
                    z_tr_emissions[q, p, r, s, t],
                )
            end
        end

        # Fixed cost
        @timeit "c_fix" begin
            for p in plants, t in T
                add_to_expression!(obj, data.c_fix[p, t], x_open[p, t])
            end
        end

        # Opening cost
        @timeit "c_open" begin
            for p in plants, t in T
                add_to_expression!(obj, data.c_open[p, t], x_open[p, t] - x_open[p, t-1])
            end
        end

        # Plant disposal
        @timeit "c_plant_disp" begin
            for p in plants, r in p.prod_out, c in r.comp, t in T
                add_to_expression!(
                    obj,
                    data.c_plant_disp[p, r, t],
                    z_plant_disp[p, r, c, t],
                )
            end
        end

        # Plant emissions
        @timeit "c_emission" begin
            for p in plants, s in emissions, t in T
                add_to_expression!(obj, data.c_emission[s, t], z_plant_emissions[p, s, t])
            end
        end

        @objective(model, Min, obj)
    end

    # Constraints
    # -------------------------------------------------------------------------
    @timeit "Model: Constraints" begin
        @timeit "eq_balance" begin
            eq_balance = _init(model, :eq_balance)
            for q in centers, r in q.prod_out, t in T
                eq_balance[q, r, t] = @constraint(
                    model,
                    sum(y_total[q, p, r2][t] for (p, r2) in E_out[q] if r == r2) +
                    z_store_total[q, r, t] ==
                    sum(data.m_init[q, r, c, t] for c in r.comp) + z_store_total[q, r, t-1]
                )
            end
        end
        ratio(q, r, c, t) =
            (data.m_init[q, r, c, t] / sum(data.m_init[q, r, d, t] for d in r.comp))

        @timeit "eq_y_total" begin
            eq_y_total = _init(model, :eq_y_total)
            for (q, p, r) in E, t in T
                eq_y_total[q, p, r, t] = @constraint(
                    model,
                    y_total[q, p, r][t] == sum(y[q, p, r][c, t] for c in r.comp)
                )
            end
        end
        @timeit "eq_split_y" begin
            eq_split_y = _init(model, :eq_split_y)
            for (q, p, r) in E, c in r.comp, t in T
                if q ∉ centers
                    continue
                end
                eq_split_y[q, p, r, c, t] = @constraint(
                    model,
                    y[q, p, r][c, t] == ratio(q, r, c, t) * y_total[q, p, r][t]
                )
            end
        end
        @timeit "eq_split_center_disp" begin
            eq_split_center_disp = _init(model, :eq_split_center_disp)
            for q in centers, r in q.prod_out, c in r.comp, t in T
                eq_split_center_disp[q, r, c, t] = @constraint(
                    model,
                    z_center_disp[q, r, c, t] ==
                    ratio(q, r, c, t) * z_center_disp_total[q, r, t]
                )
            end
        end
        @timeit "eq_split_store" begin
            eq_split_store = _init(model, :eq_split_store)
            for q in centers, r in q.prod_out, c in r.comp, t in T
                eq_split_store[q, r, c, t] = @constraint(
                    model,
                    z_store[q, r, c, t] == ratio(q, r, c, t) * z_store_total[q, r, t]
                )
            end
        end
        @timeit "eq_center_disposal" begin
            eq_center_disposal = _init(model, :eq_center_disposal)
            for r in products, t in T
                centers_r = [q for q in centers if r ∈ q.prod_out]
                if isempty(centers_r)
                    continue
                end
                eq_center_disposal[r, t] = @constraint(
                    model,
                    sum(z_center_disp_total[q, r, t] for q in centers_r) <=
                    data.m_center_disp[r, t]
                )
            end
        end
        @timeit "eq_center_storage" begin
            eq_center_storage = _init(model, :eq_center_storage)
            for q in centers, r in q.prod_out, t in T
                eq_center_storage[q, r, t] =
                    @constraint(model, z_store_total[q, r, t] <= data.m_store[q, r, t])
            end
        end
        @timeit "eq_tr_emissions" begin
            eq_tr_emissions = _init(model, :eq_tr_emissions)
            for (q, p, r) in E, s in emissions, t in T
                eq_tr_emissions[q, p, r, s, t] = @constraint(
                    model,
                    z_tr_emissions[q, p, r, s, t] ==
                    data.m_dist[q, p] *
                    data.alpha_tr_emission[r, s, t] *
                    y_total[q, p, r][t]
                )
            end
        end
        @timeit "eq_plant_capacity" begin
            eq_plant_capacity = _init(model, :eq_plant_capacity)
            for p in plants, t in T
                eq_plant_capacity[p, t] = @constraint(
                    model,
                    sum(y_total[q, p, r][t] for (q, r) in E_in[p]) <=
                    data.m_cap[p] * x_open[p, t]
                )
            end
        end
        @timeit "eq_plant_prod" begin
            eq_plant_prod = _init(model, :eq_plant_prod)
            for p in plants, r_out in p.prod_out, c_out in r_out.comp, t in T
                eq_plant_prod[p, r_out, c_out, t] = @constraint(
                    model,
                    z_prod[p, r_out, c_out, t] == sum(
                        data.alpha_mix[p, r_out, c_in, c_out] * y[q, p, r_in][c_in, t]
                        for (q, r_in) in E_in[p] for
                        c_in in r_in.comp if data.alpha_mix[p, r_out, c_in, c_out] > 0
                    )
                )
            end
        end
        @timeit "eq_plant_disp" begin
            eq_plant_disp = _init(model, :eq_plant_disp)
            for p in plants, r in p.prod_out, t in T
                eq_plant_disp[p, r, t] = @constraint(
                    model,
                    sum(z_plant_disp[p, r, c, t] for c in r.comp) <=
                    data.m_plant_disp[p, r, t] * x_disp[p, r, t]
                )
            end
        end
        @timeit "eq_plant_emissions" begin
            eq_plant_emissions = _init(model, :eq_plant_emissions)
            for p in plants, s in emissions, t in T
                eq_plant_emissions[p, s, t] = @constraint(
                    model,
                    z_plant_emissions[p, s, t] ==
                    sum(y_total[q, p, r][t] for (q, r) in E_in[p]) *
                    data.alpha_plant_emission[p, s, t]
                )
            end
        end
        @timeit "eq_emissions_limit" begin
            eq_emissions_limit = _init(model, :eq_emissions_limit)
            for s in emissions, t in T
                eq_emissions_limit[s, t] = @constraint(
                    model,
                    sum(z_plant_emissions[p, s, t] for p in plants) +
                    sum(z_tr_emissions[q, p, r, s, t] for (q, p, r) in E) <=
                    data.m_emission[s, t]
                )
            end
        end
        @timeit "eq_plant_remains_open" begin
            eq_plant_remains_open = _init(model, :eq_plant_remains_open)
            for p in plants, t in T
                eq_plant_remains_open[p, t] =
                    @constraint(model, x_open[p, t] >= x_open[p, t-1])
            end
        end
        @timeit "eq_plant_single_dest" begin
            eq_plant_single_dest = _init(model, :eq_plant_single_dest)
            for p in plants, r in p.prod_out, t in T
                eq_plant_single_dest[p, r, t] = @constraint(
                    model,
                    sum(x_send[p, q, r, t] for (q, r2) in E_out[p] if r == r2) +
                    x_disp[p, r, t] <= 1
                )
            end
        end
        @timeit "eq_plant_send_limit" begin
            eq_plant_send_limit = _init(model, :eq_plant_send_limit)
            for p in plants, (q, r) in E_out[p], t in T
                eq_plant_send_limit[p, q, r, t] = @constraint(
                    model,
                    y_total[p, q, r][t] <= data.m_cap[q] * x_send[p, q, r, t]
                )
            end
        end
        @timeit "eq_plant_balance" begin
            eq_plant_balance = _init(model, :eq_plant_balance)
            for p in plants, r in p.prod_out, c in r.comp, t in T
                eq_plant_balance[p, r, c, t] = @constraint(
                    model,
                    z_prod[p, r, c, t] ==
                    z_plant_disp[p, r, c, t] +
                    sum(y[p, q, r][c, t] for (q, r2) in E_out[p] if r == r2)
                )
            end
        end
    end

    # Optimize
    # -------------------------------------------------------------------------
    optimize!(model)

    # Report: Transportation
    # -------------------------------------------------------------------------
    output_dir = dirname(filename)
    df = DataFrame()
    df."source" = String[]
    df."destination" = String[]
    df."product" = String[]
    df."component" = String[]
    df."time" = Int[]
    df."distance (km)" = Float64[]
    df."amount sent (tonne)" = Float64[]
    df."transportation cost (\$)" = Float64[]
    df."variable operating cost (\$)" = Float64[]
    for (q, p, r) in E, c in r.comp, t in T
        if value(y[q, p, r][c, t]) ≈ 0
            continue
        end
        push!(
            df,
            [
                q.name,
                p.name,
                r.name,
                c.name,
                t,
                round(data.m_dist[q, p], digits=2),
                round(value(y[q, p, r][c, t]), digits=2),
                round(data.m_dist[q, p] * data.c_tr[r, t] * value(y[q, p, r][c, t]), digits=2),
                round(data.c_var[p, t] * value(y[q, p, r][c, t]), digits=2),
            ],
        )
    end
    CSV.write("$output_dir/transp.csv", df)

    # Report: Centers
    # -------------------------------------------------------------------------
    df = DataFrame()
    df."center" = String[]
    df."product" = String[]
    df."component" = String[]
    df."time" = Int[]
    df."amount available (tonne)" = Float64[]
    df."amount sent (tonne)" = Float64[]
    df."amount stored (tonne)" = Float64[]
    df."amount disposed (tonne)" = Float64[]
    df."acquisition cost (\$)" = Float64[]
    df."storage cost (\$)" = Float64[]
    df."disposal cost (\$)" = Float64[]
    for q in centers, r in q.prod_out, c in r.comp, t in T
        push!(
            df,
            [
                q.name,
                r.name,
                c.name,
                t,
                round(data.m_init[q, r, c, t], digits=2),
                round(sum(value(y[q, p, r][c, t]) for (p, r2) in E_out[q] if r == r2), digits=2),
                round(value(z_store[q, r, c, t]), digits=2),
                round(value(z_center_disp[q, r, c, t]), digits=2),
                round(data.m_init[q, r, c, t] * data.c_acq[q, r, t], digits=2),
                round(data.c_store[q, r, t] * value(z_store[q, r, c, t]), digits=2),
                round(data.c_center_disp[q, r, t] * value(z_center_disp[q, r, c, t]), digits=2),
            ],
        )
    end
    CSV.write("$output_dir/centers.csv", df)

    # Report: Plants
    # -------------------------------------------------------------------------
    df = DataFrame()
    df."plant" = String[]
    df."time" = Int[]
    df."is open?" = Float64[]
    df."opening cost (\$)" = Float64[]
    df."fixed operating cost (\$)" = Float64[]
    for p in plants, t in T
        push!(
            df,
            [
                p.name,
                t,
                round(value(x_open[p, t]), digits=2),
                round(data.c_open[p, t] * (value(x_open[p, t]) - value(x_open[p, t-1])), digits=2),
                round(data.c_fix[p, t] * value(x_open[p, t]), digits=2),
            ],
        )
    end
    CSV.write("$output_dir/plants.csv", df)

    # Report: Plant Outputs
    # -------------------------------------------------------------------------
    df = DataFrame()
    df."plant" = String[]
    df."product" = String[]
    df."component" = String[]
    df."time" = Int[]
    df."amount produced (tonne)" = Float64[]
    df."amount disposed (tonne)" = Float64[]
    df."amount sent (tonne)" = Float64[]
    df."disposal cost (\$)" = Float64[]
    for p in plants, r in p.prod_out, c in r.comp, t in T
        if value(z_prod[p, r, c, t]) ≈ 0
            continue
        end
        push!(
            df,
            [
                p.name,
                r.name,
                c.name,
                t,
                round(value(z_prod[p, r, c, t]), digits=2),
                round(value(z_plant_disp[p, r, c, t]), digits=2),
                round(sum(value(y[p, q, r][c, t]) for (q, r2) in E_out[p] if r == r2; init = 0.0), digits=2),
                round(data.c_plant_disp[p, r, t] * value(z_plant_disp[p, r, c, t]), digits=2),
            ],
        )
    end
    CSV.write("$output_dir/plant-outputs.csv", df)

    # Report: Plant Emissions
    # -------------------------------------------------------------------------
    df = DataFrame()
    df."plant" = String[]
    df."emission" = String[]
    df."time" = Int[]
    df."amount emitted (tonne)" = Float64[]
    df."emission cost (\$)" = Float64[]
    for p in plants, s in emissions, t in T
        push!(
            df,
            [
                p.name,
                s.name,
                t,
                round(value(z_plant_emissions[p, s, t]), digits=2),
                round(data.c_emission[s, t] * value(z_plant_emissions[p, s, t]), digits=2),
            ],
        )
    end
    CSV.write("$output_dir/plant-emissions.csv", df)

    # Report: Transportation Emissions
    # -------------------------------------------------------------------------
    df = DataFrame()
    df."source" = String[]
    df."destination" = String[]
    df."product" = String[]
    df."emission" = String[]
    df."time" = Int[]
    df."distance (km)" = Float64[]
    df."amount sent (tonne)" = Float64[]
    df."amount emitted (tonne)" = Float64[]
    df."emission cost (\$)" = Float64[]
    for (q, p, r) in E, s in emissions, t in T
        if value(y_total[q, p, r][t]) ≈ 0
            continue
        end
        push!(
            df,
            [
                q.name,
                p.name,
                r.name,
                s.name,
                t,
                round(data.m_dist[q, p], digits=2),
                round(value(y_total[q, p, r][t]), digits=2),
                round(value(z_tr_emissions[q, p, r, s, t]), digits=2),
                round(data.c_emission[s, t] * value(z_tr_emissions[q, p, r, s, t]), digits=2),
            ],
        )
    end
    CSV.write("$output_dir/transp-emissions.csv", df)

    print_timer()

    return
end
